import SwiftUI
import MapKit

/// Map-based geofence verification. The child must physically move to a
/// designated location (e.g., kitchen) to dismiss the alarm.
struct GeofenceVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var isChecking = false
    @State private var result: VerificationService.GeofenceResult?

    // TODO: These coordinates should come from the alarm configuration (set by parent).
    // For now, use placeholder values.
    private let targetLatitude = 37.7749
    private let targetLongitude = -122.4194
    private let targetName = "Kitchen"

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 20) {
            Text("Go to the \(targetName)")
                .font(.title2.bold())

            Text("Walk to the designated location to verify you're awake.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Map showing the target location
            Map(position: $cameraPosition) {
                Annotation(targetName, coordinate: CLLocationCoordinate2D(
                    latitude: targetLatitude,
                    longitude: targetLongitude
                )) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let result {
                resultView(result)
            } else {
                Button {
                    checkLocation()
                } label: {
                    if isChecking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Check My Location", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isChecking)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func resultView(_ result: VerificationService.GeofenceResult) -> some View {
        if result.isWithinFence {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("You're here!")
                    .font(.title.bold())
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                if let distance = result.distanceMeters {
                    Text(String(format: "%.0f meters away", distance))
                        .font(.title3)
                }

                Text("Keep walking toward the \(targetName).")
                    .foregroundStyle(.secondary)

                Button("Check Again") {
                    self.result = nil
                    checkLocation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func checkLocation() {
        isChecking = true
        Task {
            let geofenceResult = await VerificationService.shared.checkGeofence(
                targetLatitude: targetLatitude,
                targetLongitude: targetLongitude
            )
            result = geofenceResult
            isChecking = false

            if geofenceResult.isWithinFence {
                await vm.completeVerification(method: .geofence)
            }
        }
    }
}
