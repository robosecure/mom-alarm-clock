import SwiftUI
import PhotosUI

/// Camera capture view for photo-based verification.
/// The child takes a photo of a required item (e.g., breakfast, toothbrush, pet)
/// and uploads it for parent review (or automatic ML verification in future versions).
struct PhotoVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: Image?
    @State private var isSubmitting = false
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 24) {
            if isComplete {
                completionView
            } else if let capturedImage {
                reviewView(capturedImage)
            } else {
                captureView
            }
        }
        .padding()
    }

    private var captureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Take a Photo")
                .font(.title2.bold())

            Text("Take a photo to prove you're up and moving. Your guardian may review this.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Camera capture button
            // In production, use UIImagePickerController with .camera source type
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Open Camera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        capturedImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    private func reviewView(_ image: Image) -> some View {
        VStack(spacing: 16) {
            Text("Review Your Photo")
                .font(.title2.bold())

            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 16) {
                Button("Retake") {
                    capturedImage = nil
                    selectedPhoto = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Submit") {
                    submitPhoto()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSubmitting)
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            Text("Photo Submitted")
                .font(.title.bold())
            Text("Your photo has been sent to your guardian for review. Please wait for their approval.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func submitPhoto() {
        isSubmitting = true
        // Photo verification always requires parent review — no auto-approve.
        // The photo reference is saved as proof metadata for the parent to review.
        Task {
            let photoRef = "local://photo-\(UUID().uuidString)" // In production: upload to Firebase Storage
            let result = VerificationResult(
                method: .photo,
                completedAt: Date(),
                tier: vm.effectiveVerificationTier,
                passed: true, // Provisionally passed — parent makes final call
                photoReference: photoRef,
                deviceTimestamp: Date()
            )
            isComplete = true
            isSubmitting = false
            await vm.completeVerification(method: .photo, result: result)
        }
    }
}
