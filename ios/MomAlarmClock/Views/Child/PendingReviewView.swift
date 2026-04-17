import SwiftUI

/// Shown to the child after verification when the confirmation policy requires parent approval.
/// Displays a waiting state and updates in real-time when the parent acts.
struct PendingReviewView: View {
    @Environment(ChildViewModel.self) private var vm
    @AppStorage("hasSeenFirstCelebration") private var hasSeenFirstCelebration = false
    @State private var showCelebration = false

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
        .overlay {
            if showCelebration {
                CelebrationOverlay()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onChange(of: vm.activeSession?.parentAction) { _, action in
            guard let action, action.isApproval else { return }
            // Celebrate on: first-ever verification OR streak milestone (3/7/14/30 days)
            let streak = vm.profile?.stats.currentStreak ?? 0
            let isMilestone = streak == 3 || streak == 7 || streak == 14 || streak == 30
            let shouldCelebrate = !hasSeenFirstCelebration || isMilestone
            guard shouldCelebrate else { return }
            hasSeenFirstCelebration = true
            withAnimation { showCelebration = true }
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation { showCelebration = false }
            }
        }
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

            Text("Your verification has been submitted. Waiting for your guardian to review.")
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
                .sensoryFeedback(action.isApproval ? .success : .warning, trigger: action.displayName)

            Text(action.isApproval ? "You did it!" : "Try again")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            switch action {
            case .approved, .autoAcknowledged:
                Text("Great job getting up!")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let stats = vm.profile?.stats {
                    HStack(spacing: 16) {
                        if stats.currentStreak > 0 {
                            Label("\(stats.currentStreak)-day streak!", systemImage: "flame.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                        }
                        if stats.rewardPoints > 0 {
                            Label("\(stats.rewardPoints) pts", systemImage: "star.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.top, 4)
                }

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
