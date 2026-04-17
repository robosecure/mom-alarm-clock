import SwiftUI

/// Minimal settings screen for the child device.
/// Provides sign-out, basic stats, and device info.
struct ChildSettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ChildViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            if let profile = vm.profile {
                Section("My Profile") {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Age", value: "\(profile.age)")
                    LabeledContent("Age Group", value: profile.ageBand.displayName)
                }

                Section("My Stats") {
                    LabeledContent("Current Streak") {
                        Label("\(profile.stats.currentStreak) days", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                    LabeledContent("Best Streak") {
                        Text("\(profile.stats.bestStreak) days")
                    }
                    LabeledContent("Points") {
                        Label("\(profile.stats.rewardPoints)", systemImage: "star.fill")
                            .foregroundStyle(.purple)
                    }
                    LabeledContent("On-Time Count") {
                        Text("\(profile.stats.onTimeCount)")
                    }
                }
            }

            Section("How Points Work") {
                VStack(alignment: .leading, spacing: 6) {
                    pointRow("+15", "On time, first try")
                    pointRow("+10", "On time, with retries")
                    pointRow("+5", "Late but verified")
                    pointRow("+5", "No snooze bonus")
                    Divider()
                    pointRow("+25", "3-day streak milestone")
                    pointRow("+75", "7-day streak milestone")
                    pointRow("+150", "14-day streak milestone")
                }
                .font(.caption)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirmation = true
                }
            } footer: {
                Text("Signing out will unpair this device. You'll need a new join code from your guardian to pair again.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await auth.signOut()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need a new join code from your guardian to pair this device again.")
        }
    }

    private func pointRow(_ points: String, _ label: String) -> some View {
        HStack {
            Text(points)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.purple)
                .frame(width: 40, alignment: .leading)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
