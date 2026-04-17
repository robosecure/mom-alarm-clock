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
                if let code = vm.children.last?.pairingCode ?? joinCode ?? auth.lastJoinCode {
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
                        ShareLink(item: "Join our family alarm on Mom Alarm Clock! Code: \(code)") {
                            Image(systemName: "square.and.arrow.up")
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

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Guardian creates the family and sets alarms.", systemImage: "1.circle.fill")
                    Label("Child's device fires the alarm and asks them to verify they're up.", systemImage: "2.circle.fill")
                    Label("By default, the alarm clears once verified. You're only notified when something needs attention.", systemImage: "3.circle.fill")
                    Label("Some features (app lock, critical alerts) depend on iOS permissions and may not be available on all devices.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } header: {
                Text("How It Works")
            }

            Section("Privacy & Data") {
                Label {
                    Text("Mom Alarm Clock collects only the data needed to run alarms and verify wake-ups. No tracking, no ads. Age is used only to tailor quiz difficulty.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.blue)
                }

                LabeledContent("Data Stored") {
                    Text("Name, age, alarms, sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Tracking") {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                LabeledContent("Ads") {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if let url = Self.privacyPolicyURL {
                    Link(destination: url) {
                        Label("Privacy Policy", systemImage: "doc.text")
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                #if DEBUG
                if FirebaseApp.app() != nil {
                    LabeledContent("Backend", value: "Firebase")
                } else {
                    LabeledContent("Backend", value: "Local (dev)")
                }
                #endif
                if let supportEmail = Self.supportEmail,
                   let url = URL(string: "mailto:\(supportEmail.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? supportEmail)") {
                    Link(destination: url) {
                        Label("Contact Support", systemImage: "envelope")
                    }
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to access your family.")
        }
        .confirmationDialog("Delete Account?", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    do {
                        try await auth.deleteAccount()
                    } catch {
                        // If delete fails (e.g., re-auth required), fall back to sign out
                        await auth.signOut()
                    }
                    dismiss()
                }
            }
        } message: {
            Text("This permanently deletes your guardian account, your family, all child profiles, alarm history, and voice recordings. Paired child devices will be signed out. This cannot be undone.")
        }
    }

    /// Set this to a real URL once the privacy policy is hosted.
    /// The link row only appears when this is non-nil.
    private static let privacyPolicyURL: URL? = URL(string: "https://robosecure.github.io/mom-alarm-clock-legal/privacy.html")

    /// Set this to a real email once support is configured.
    /// The contact row only appears when this is non-nil.
    private static let supportEmail: String? = "rmathews0707@gmail.com"
    // TODO: Migrate to dedicated support@momclock.com before public launch

    private func childColor(for child: ChildProfile) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange]
        let index = vm.children.firstIndex(where: { $0.id == child.id }) ?? 0
        return colors[index % colors.count]
    }
}
