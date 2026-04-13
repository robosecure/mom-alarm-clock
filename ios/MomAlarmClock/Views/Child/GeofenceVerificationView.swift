import SwiftUI
import MapKit

/// Map-based geofence verification. The child must physically move to a
/// designated location (e.g., kitchen) to dismiss the alarm.
struct GeofenceVerificationView: View {
    @Environment(ChildViewModel.self) private var vm
    @State private var isChecking = false
    @State private var result: VerificationService.GeofenceResult?

    // In production, these come from the alarm configuration (set by parent during setup).
    // The parent drops a pin on a map to set the target location.
    var targetLatitude: Double = 0.0
    var targetLongitude: Double = 0.0
    var targetName: String = "Designated Spot"

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
        let radius = vm.effectiveVerificationTier.geofenceRadiusMeters
        Task {
            let geofenceResult = await VerificationService.shared.checkGeofence(
                targetLatitude: targetLatitude,
                targetLongitude: targetLongitude,
                radiusMeters: radius
            )
            result = geofenceResult
            isChecking = false

            if geofenceResult.isWithinFence {
                let verificationResult = VerificationResult(
                    method: .geofence,
                    completedAt: Date(),
                    tier: vm.effectiveVerificationTier,
                    passed: true,
                    gpsDistanceMeters: geofenceResult.distanceMeters,
                    deviceTimestamp: Date()
                )
                await vm.completeVerification(method: .geofence, result: verificationResult)
            }
        }
    }
}
