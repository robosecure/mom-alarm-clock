import SwiftUI

/// Dynamic verification router that presents the correct verification UI
/// based on the currently required method. Optionally shows a brief
/// calming interstitial if the guardian enabled calm mode.
struct VerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var showCalmMode = false
    @State private var calmDone = false

    var body: some View {
        Group {
            if showCalmMode && !calmDone {
                calmInterstitial
            } else {
                verificationContent
            }
        }
        .navigationTitle("Verify You're Awake")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm.effectiveConfig?.calmMode == true {
                showCalmMode = true
            }
            await vm.beginVerification()
        }
    }

    @ViewBuilder
    private var verificationContent: some View {
        switch vm.currentVerificationMethod ?? .motion {
        case .qr:
            QRVerificationView()
        case .photo:
            PhotoVerificationView()
        case .motion:
            MotionVerificationView()
        case .quiz:
            QuizVerificationView()
        case .geofence:
            GeofenceVerificationView()
        }
    }

    private var calmInterstitial: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.opacity(0.7))
            Text("Take a breath.")
                .font(.title.bold())
            Text("You've got this.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.5)) {
                    calmDone = true
                }
            }
        }
    }
}
