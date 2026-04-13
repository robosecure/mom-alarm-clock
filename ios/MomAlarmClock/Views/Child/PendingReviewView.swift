import SwiftUI

/// Shown to the child after verification when the confirmation policy requires parent approval.
/// Displays a waiting state and updates in real-time when the parent acts.
struct PendingReviewView: View {
    @Environment(ChildViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let action = vm.activeSession?.parentAction {
                resultView(action)
            } else {
                waitingView
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Verification Submitted")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Waiting

    private var waitingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 8)

            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)

            Text("Waiting for Guardian")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Your verification has been submitted. Your guardian will review it shortly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let result = vm.activeSession?.verificationResult {
                VStack(spacing: 4) {
                    Label(result.method.displayName, systemImage: result.method.systemImage)
                        .font(.subheadline)
                    Text(result.proofSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            if let parentMessage = vm.activeSession?.parentMessage {
                HStack {
                    Image(systemName: "message.fill")
                    Text(parentMessage)
                }
                .font(.subheadline)
                .padding()
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Result

    private func resultView(_ action: ParentAction) -> some View {
        VStack(spacing: 20) {
            Image(systemName: action.isApproval ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(action.isApproval ? .green : .red)

            Text(action.isApproval ? "Approved!" : "Verification Denied")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            switch action {
            case .approved, .autoAcknowledged:
                Text("Great job getting up! Your device is unlocked.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

            case .denied(let reason):
                VStack(spacing: 8) {
                    Text("Your guardian wants you to verify again.")
                        .foregroundStyle(.secondary)
                    if !reason.isEmpty {
                        Text("Reason: \(reason)")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    NavigationLink {
                        VerificationView()
                    } label: {
                        Label("Verify Again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top)
                }

            case .escalated(let reason):
                VStack(spacing: 8) {
                    Text("Your guardian needs to talk to you about this morning.")
                        .foregroundStyle(.red)
                    if !reason.isEmpty {
                        Text("Reason: \(reason)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
