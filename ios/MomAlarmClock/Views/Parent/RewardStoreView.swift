import SwiftUI

/// Displays streak rewards and the child's earned points.
/// Parents can define custom rewards; children can see what they're working toward.
struct RewardStoreView: View {
    @Environment(ParentViewModel.self) private var vm

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
            if let child = vm.selectedChild {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(child.stats.rewardPoints)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.purple)
                            Text("Reward Points")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Label("\(child.stats.currentStreak) days", systemImage: "flame.fill")
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

                            if child.stats.rewardPoints >= reward.points {
                                Button("Redeem") {
                                    // TODO: Deduct points, record redemption
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            } else {
                                Text("\(reward.points - child.stats.rewardPoints) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("How Points Work") {
                    Label("On-time wake-up: +10 points", systemImage: "plus.circle")
                    Label("3-day streak bonus: +25 points", systemImage: "plus.circle")
                    Label("7-day streak bonus: +75 points", systemImage: "plus.circle")
                    Label("No snooze bonus: +5 points", systemImage: "plus.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rewards")
    }
}

// MARK: - Reward Model

private struct Reward: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let icon: String
}
