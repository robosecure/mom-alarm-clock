import SwiftUI

/// Displays streak rewards and the child's earned points.
/// Parents can define custom rewards; children can see what they're working toward.
struct RewardStoreView: View {
    @Environment(ParentViewModel.self) private var vm
    @State private var redeemedRewardName: String?
    @State private var showRedeemConfirmation = false

    /// Sample reward tiers — in production these would be parent-configurable.
    private let rewards: [Reward] = [
        Reward(name: "Extra 30 min Screen Time", points: 50, icon: "iphone"),
        Reward(name: "Pick Dinner Tonight", points: 100, icon: "fork.knife"),
        Reward(name: "Stay Up 30 min Later", points: 150, icon: "moon.stars"),
        Reward(name: "Movie Night Pick", points: 200, icon: "film"),
        Reward(name: "Weekend Outing Choice", points: 500, icon: "car"),
    ]

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

                Section("Available Rewards") {
                    ForEach(rewards) { reward in
                        HStack {
                            Image(systemName: reward.icon)
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 40)

                            VStack(alignment: .leading) {
                                Text(reward.name)
                                    .font(.subheadline)
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
        .alert("Redeem Reward?", isPresented: $showRedeemConfirmation) {
            Button("Cancel", role: .cancel) { }
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
}

// MARK: - Reward Model

private struct Reward: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let icon: String
}
