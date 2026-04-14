import SwiftUI
import AVFoundation

/// Camera-based QR code scanner for verification.
/// The child must scan a QR code placed in another room (e.g., kitchen, bathroom).
/// The QR payload rotates daily so screenshots of the code won't work.
struct QRVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var scannedValue: String?
    @State private var isValid: Bool?
    @State private var showCamera = true

    var body: some View {
        VStack(spacing: 24) {
            if let isValid {
                resultView(success: isValid)
            } else {
                instructionsView
                cameraPreview
            }
        }
        .padding()
    }

    private var instructionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Scan the QR Code")
                .font(.title2.bold())
            Text("Scan the QR code your guardian placed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
        }
    }

    /// Camera preview placeholder. In a real implementation, this would use
    /// AVCaptureSession with a CIDetector or Vision framework for QR detection.
    private var cameraPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.8))
                .frame(height: 300)

            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Camera Preview")
                    .foregroundStyle(.white.opacity(0.5))

                // TODO: Replace with real AVCaptureSession integration
                // Use DataScannerViewController (iOS 16+) for built-in scanning:
                //   DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])])
                Button("Simulate Scan") {
                    simulateScan()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
    }

    private func resultView(success: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(success ? .green : .red)

            Text(success ? "Verified!" : "Invalid QR Code")
                .font(.title.bold())

            Text(success ? "Great job getting up!" : "Make sure you're scanning the right code.")
                .foregroundStyle(.secondary)

            if !success {
                Button("Try Again") {
                    isValid = nil
                    scannedValue = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func simulateScan() {
        guard let childID = vm.profile?.id else { return }
        Task {
            let expected = await VerificationService.shared.generateQRPayload(childID: childID)
            scannedValue = expected
            let valid = await VerificationService.shared.validateQRCode(expected, childID: childID)
            isValid = valid
            if valid {
                let result = VerificationResult(
                    method: .qr,
                    completedAt: Date(),
                    tier: vm.effectiveVerificationTier,
                    passed: true,
                    qrHash: String(expected.suffix(16)),
                    deviceTimestamp: Date()
                )
                await vm.completeVerification(method: .qr, result: result)
            }
        }
    }
}
