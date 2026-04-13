import SwiftUI

/// Child device pairing flow. The child enters the family code from the parent's device.
/// After pairing, requests necessary permissions (notifications, location, motion).
struct ChildPairingView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var familyCode = ""
    @State private var childName = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var isPaired = false
    @State private var permissionStep = 0

    var body: some View {
        if isPaired {
            permissionFlow
        } else {
            pairingForm
        }
    }

    // MARK: - Pairing Form

    private var pairingForm: some View {
        Form {
            Section {
                TextField("Your Name", text: $childName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            } header: {
                Text("What's your name?")
            }

            Section {
                TextField("Family Code", text: $familyCode)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
            } header: {
                Text("Enter the code from your guardian's device")
            } footer: {
                Text("Ask your parent or guardian for the 10-character family code shown on their phone.")
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await pair() }
                } label: {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Join Family")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(familyCode.count < 10 || childName.isEmpty || isLoading)
            }
        }
        .navigationTitle("Pair Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Permission Flow

    private var permissionFlow: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: permissionStep < 2 ? "bell.badge.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(permissionStep < 2 ? .blue : .green)

            switch permissionStep {
            case 0:
                permissionCard(
                    title: "Allow Notifications",
                    description: "Notifications are required for your alarm to sound. This is the most important permission.",
                    action: "Enable Notifications"
                ) {
                    // Request notification permission
                    let center = UNUserNotificationCenter.current()
                    let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
                    permissionStep = 1
                }
            case 1:
                permissionCard(
                    title: "Allow Motion & Location",
                    description: "Some verification methods use step counting or location. You can skip this if your guardian chose a different method.",
                    action: "Continue"
                ) {
                    permissionStep = 2
                }
            default:
                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.title.bold())
                    Text("Your guardian will configure your alarm. You'll see it on the next screen.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Setup")
    }

    private func permissionCard(
        title: String,
        description: String,
        action: String,
        onAction: @escaping () async -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2.bold())
            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action) {
                Task { await onAction() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Actions

    private func pair() async {
        isLoading = true
        error = nil

        do {
            try await auth.pairAsChild(familyCode: familyCode, displayName: childName)
            isPaired = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
