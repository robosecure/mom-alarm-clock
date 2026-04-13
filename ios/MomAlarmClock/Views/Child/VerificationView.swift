import SwiftUI

/// Dynamic verification router that presents the correct verification UI
/// based on the currently required method.
struct VerificationView: View {
    @Environment(ChildViewModel.self) private var vm

    var body: some View {
        Group {
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
        .navigationTitle("Verify You're Awake")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.beginVerification()
        }
    }
}
