import SwiftUI

/// Displays child's points + redeemable rewards.
/// Guardians can add, edit, and remove rewards per child.
struct RewardStoreView: View {
    @Environment(ParentViewModel.self) private var vm
    @State private var redeemedRewardName: String?
    @State private var showRedeemConfirmation = false
    @State private var showEditor = false
    @State private var editingReward: Reward?

    private var rewards: [Reward] {
        let existing = vm.selectedChild?.rewards ?? []
        return existing.isEmpty ? Reward.defaults : existing
    }

    private var isUsingDefaults: Bool {
        vm.selectedChild?.rewards.isEmpty ?? true
    }

    var body: some View {
        List {
            if let stats = vm.selectedChildStats {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(stats.rewardPoints)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.purple)
                            Text("Reward Points")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Label("\(stats.currentStreak) days", systemImage: "flame.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text("Current Streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    ForEach(rewards) { reward in
                        rewardRow(reward, stats: stats)
                    }
                    .onDelete { indexSet in
                        Task { await deleteRewards(at: indexSet) }
                    }

                    Button {
                        editingReward = nil
                        showEditor = true
                    } label: {
                        Label("Add Reward", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    HStack {
                        Text("Available Rewards")
                        Spacer()
                        if isUsingDefaults {
                            Text("Using defaults")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("Tap a reward to edit, swipe to delete. You give the reward to your child when they redeem.")
                        .font(.caption)
                }

                Section("How Points Work") {
                    Label("On-time, first try: +15", systemImage: "star.fill")
                    Label("On-time, after retries: +10", systemImage: "star")
                    Label("No snooze bonus: +5", systemImage: "zzz")
                    Label("3-day streak: +25 bonus", systemImage: "flame.fill")
                    Label("7-day streak: +75 bonus", systemImage: "flame.fill")
                    Label("14-day streak: +150 bonus", systemImage: "trophy.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rewards")
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                RewardEditorView(existing: editingReward) { reward in
                    Task { await saveReward(reward) }
                }
            }
        }
        .alert("Redeem Reward?", isPresented: $showRedeemConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Redeem") {
                if let name = redeemedRewardName,
                   let reward = rewards.first(where: { $0.name == name }) {
                    Task {
                        await vm.redeemPoints(reward.points)
                        BetaDiagnostics.log(.rewardRedeemed(points: reward.points))
                    }
                }
            }
        } message: {
            if let name = redeemedRewardName {
                Text("Redeem \"\(name)\" for your child?")
            }
        }
    }

    private func rewardRow(_ reward: Reward, stats: ChildProfile.Stats) -> some View {
        Button {
            editingReward = reward
            showEditor = true
        } label: {
            HStack {
                Image(systemName: reward.icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(reward.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("\(reward.points) points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if stats.rewardPoints >= reward.points {
                    Button("Redeem") {
                        redeemedRewardName = reward.name
                        showRedeemConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Text("\(reward.points - stats.rewardPoints) more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func saveReward(_ reward: Reward) async {
        guard var child = vm.selectedChild else { return }
        if child.rewards.isEmpty {
            child.rewards = Reward.defaults
        }
        if let idx = child.rewards.firstIndex(where: { $0.id == reward.id }) {
            child.rewards[idx] = reward
        } else {
            child.rewards.append(reward)
        }
        await vm.updateChildRewards(childID: child.id, rewards: child.rewards)
    }

    private func deleteRewards(at offsets: IndexSet) async {
        guard var child = vm.selectedChild else { return }
        if child.rewards.isEmpty {
            child.rewards = Reward.defaults
        }
        child.rewards.remove(atOffsets: offsets)
        await vm.updateChildRewards(childID: child.id, rewards: child.rewards)
    }
}

private struct RewardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: Reward?
    let onSave: (Reward) -> Void

    @State private var name: String = ""
    @State private var points: Int = 50
    @State private var icon: String = "star.fill"

    var body: some View {
        Form {
            Section("Reward") {
                TextField("Name (e.g., Movie Night)", text: $name)
                Stepper("\(points) points", value: $points, in: 10...1000, step: 10)
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(Reward.availableIcons, id: \.name) { item in
                        Button {
                            icon = item.name
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.name)
                                    .font(.title2)
                                    .foregroundStyle(icon == item.name ? .white : .primary)
                                    .frame(width: 40, height: 40)
                                    .background(icon == item.name ? Color.purple : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                                Text(item.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(existing == nil ? "Add Reward" : "Edit Reward")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let reward = Reward(
                        id: existing?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        points: points,
                        icon: icon
                    )
                    onSave(reward)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let existing {
                name = existing.name
                points = existing.points
                icon = existing.icon
            }
        }
    }
}
