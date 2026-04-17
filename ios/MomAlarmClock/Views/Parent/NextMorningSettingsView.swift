import SwiftUI

/// Guardian-only panel to adjust next morning's verification settings for a child.
/// Overrides apply once and auto-clear after the next completed session.
struct NextMorningSettingsView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var method: VerificationMethod = .quiz
    @State private var tier: VerificationTier = .medium
    @State private var maxAttempts: Int = 3
    @State private var timerSeconds: Int = 45
    @State private var calmMode: Bool = false
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Verification Method") {
                Picker("Method", selection: $method) {
                    Text("Wake-Up Quiz").tag(VerificationMethod.quiz)
                    Text("Motion / Steps").tag(VerificationMethod.motion)
                }
            }

            Section("Difficulty") {
                Picker("Tier", selection: $tier) {
                    Text("Easy").tag(VerificationTier.easy)
                    Text("Medium").tag(VerificationTier.medium)
                    Text("Hard").tag(VerificationTier.hard)
                }
                .pickerStyle(.segmented)
            }

            Section("Quiz Settings") {
                Picker("Max Attempts", selection: $maxAttempts) {
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)

                Picker("Timer", selection: $timerSeconds) {
                    Text("30s").tag(30)
                    Text("45s").tag(45)
                    Text("60s").tag(60)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Calm Mode", isOn: $calmMode)
            } footer: {
                Text("Shows a brief calming message before verification starts.")
            }

            Section {
                Text("These settings apply to tomorrow's alarm only. They auto-clear after the session completes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save for Tomorrow")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(isSaving)

                if vm.selectedChild?.nextMorningOverrides != nil {
                    Button("Clear Overrides", role: .destructive) {
                        Task { await clearOverrides() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Next Morning")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        if let overrides = vm.selectedChild?.nextMorningOverrides {
            method = overrides.verificationMethod ?? .quiz
            tier = overrides.tier ?? .medium
            maxAttempts = overrides.maxAttempts ?? 3
            timerSeconds = overrides.timerSeconds ?? 45
            calmMode = overrides.calmMode ?? false
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let overrides = ChildProfile.NextMorningOverrides(
            verificationMethod: method,
            tier: tier,
            maxAttempts: maxAttempts,
            timerSeconds: timerSeconds,
            calmMode: calmMode,
            setAt: Date(),
            setBy: await LocalStore.shared.authState()?.userID
        )

        await vm.setNextMorningOverrides(overrides)
        dismiss()
    }

    private func clearOverrides() async {
        await vm.setNextMorningOverrides(nil)
        dismiss()
    }
}
