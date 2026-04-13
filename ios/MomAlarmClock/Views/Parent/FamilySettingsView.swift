import SwiftUI
import FirebaseAuth
import FirebaseCore

/// Family management screen: join code, paired children, account settings.
struct FamilySettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var joinCode: String?

    var body: some View {
        List {
            Section("Family") {
                LabeledContent("Family ID", value: String(auth.currentUser?.familyID.prefix(8) ?? "—") + "...")
                LabeledContent("Your Role", value: auth.currentUser?.role.rawValue.capitalized ?? "—")
                LabeledContent("Children", value: "\(vm.children.count) / 4")
            }

            Section("Join Code") {
                if let code = joinCode ?? auth._lastJoinCode {
                    HStack {
                        Text(code)
                            .font(.system(.title2, design: .monospaced))
                            .tracking(2)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Text("Share this code with your child to pair their device. Codes expire after 24 hours and can only be used once.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Join code was shown during signup. Create a new one below if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Children") {
                ForEach(vm.children) { child in
                    HStack {
                        Circle()
                            .fill(childColor(for: child).opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(child.name.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(childColor(for: child))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name)
                                .font(.body.bold())
                            Text("Age \(child.age) · \(child.stats.currentStreak) day streak · \(child.stats.rewardPoints) pts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if child.isPaired {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Not paired")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Account") {
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirmation = true
                }
                Button("Delete Account", role: .destructive) {
                    showDeleteAccountConfirmation = true
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                if FirebaseApp.app() != nil {
                    LabeledContent("Backend", value: "Firebase")
                } else {
                    LabeledContent("Backend", value: "Local (dev)")
                }
                NavigationLink("Diagnostics") {
                    DiagnosticsView()
                }
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
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    await auth.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete your account, family, all children's data, and alarm history. This cannot be undone.")
        }
    }

    private func childColor(for child: ChildProfile) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange]
        let index = vm.children.firstIndex(where: { $0.id == child.id }) ?? 0
        return colors[index % colors.count]
    }
}
