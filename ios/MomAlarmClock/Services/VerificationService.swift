import Foundation
import CoreMotion
import CoreLocation
import CryptoKit

/// Handles all verification methods that the child must complete to dismiss the alarm.
/// Each method has a generate (setup) phase and a validate (check) phase.
actor VerificationService {
    static let shared = VerificationService()

    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()

    // MARK: - QR Code

    /// Generates a QR code payload that the parent prints and places in another room.
    /// The payload includes a rotating daily component so screenshots won't work.
    func generateQRPayload(childID: UUID) -> String {
        let dateString = Date().formatted(date: .numeric, time: .omitted)
        let raw = "\(childID.uuidString)-\(dateString)"
        let hash = SHA256.hash(data: Data(raw.utf8))
        return "momclock://verify/qr/\(hash.compactMap { String(format: "%02x", $0) }.joined())"
    }

    /// Validates a scanned QR code against the expected payload for today.
    func validateQRCode(_ scannedValue: String, childID: UUID) -> Bool {
        let expected = generateQRPayload(childID: childID)
        return scannedValue == expected
    }

    // MARK: - Motion / Steps

    /// Begins monitoring motion to verify the child has moved a minimum distance.
    /// Returns true once the step threshold is reached.
    func startMotionTracking(requiredSteps: Int = 50) -> AsyncStream<MotionProgress> {
        AsyncStream { continuation in
            guard motionManager.isAccelerometerAvailable else {
                continuation.yield(MotionProgress(
                    currentSteps: 0, requiredSteps: requiredSteps,
                    isComplete: false, unavailable: true
                ))
                continuation.finish()
                return
            }

            let pedometer = CMPedometer()
            guard CMPedometer.isStepCountingAvailable() else {
                continuation.yield(MotionProgress(
                    currentSteps: 0, requiredSteps: requiredSteps,
                    isComplete: false, unavailable: true
                ))
                continuation.finish()
                return
            }

            let startDate = Date()
            pedometer.startUpdates(from: startDate) { data, error in
                guard let data, error == nil else {
                    continuation.finish()
                    return
                }
                let steps = data.numberOfSteps.intValue
                let progress = MotionProgress(
                    currentSteps: steps,
                    requiredSteps: requiredSteps,
                    isComplete: steps >= requiredSteps,
                    unavailable: false
                )
                continuation.yield(progress)
                if progress.isComplete {
                    pedometer.stopUpdates()
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                pedometer.stopUpdates()
            }
        }
    }

    struct MotionProgress: Sendable {
        let currentSteps: Int
        let requiredSteps: Int
        let isComplete: Bool
        let unavailable: Bool
        var percentage: Double { Double(currentSteps) / Double(requiredSteps) }
    }

    // MARK: - Quiz

    /// Generates a set of math quiz questions appropriate for the given difficulty.
    func generateQuiz(difficulty: QuizDifficulty = .medium, count: Int = 3) -> [QuizQuestion] {
        (0..<count).map { _ in
            switch difficulty {
            case .easy:
                let a = Int.random(in: 1...20)
                let b = Int.random(in: 1...20)
                return QuizQuestion(text: "\(a) + \(b) = ?", answer: a + b)
            case .medium:
                let a = Int.random(in: 10...50)
                let b = Int.random(in: 10...50)
                let multiply = Bool.random()
                if multiply {
                    let m1 = Int.random(in: 2...12)
                    let m2 = Int.random(in: 2...12)
                    return QuizQuestion(text: "\(m1) \u{00d7} \(m2) = ?", answer: m1 * m2)
                }
                return QuizQuestion(text: "\(a) + \(b) = ?", answer: a + b)
            case .hard:
                let a = Int.random(in: 2...15)
                let b = Int.random(in: 2...15)
                let c = Int.random(in: 1...20)
                return QuizQuestion(text: "\(a) \u{00d7} \(b) + \(c) = ?", answer: a * b + c)
            }
        }
    }

    enum QuizDifficulty: String, Sendable {
        case easy, medium, hard
    }

    struct QuizQuestion: Identifiable, Sendable {
        let id = UUID()
        let text: String
        let answer: Int

        var correctAnswer: Int { answer }

        func isCorrect(_ userAnswer: Int) -> Bool {
            userAnswer == answer
        }
    }

    // MARK: - Geofence

    /// Checks if the child's current location is within the required geofence radius.
    /// Returns `.denied` if the user hasn't granted When-In-Use authorization.
    func checkGeofence(
        targetLatitude: Double,
        targetLongitude: Double,
        radiusMeters: Double = 10
    ) async -> GeofenceResult {
        let target = CLLocation(latitude: targetLatitude, longitude: targetLongitude)

        return await withCheckedContinuation { continuation in
            let delegate = LocationDelegate { [weak self] outcome in
                switch outcome {
                case .denied:
                    continuation.resume(returning: GeofenceResult(
                        isWithinFence: false, distanceMeters: nil, authorizationDenied: true
                    ))
                case .failed:
                    continuation.resume(returning: GeofenceResult(
                        isWithinFence: false, distanceMeters: nil, authorizationDenied: false
                    ))
                case .located(let location):
                    let distance = location.distance(from: target)
                    continuation.resume(returning: GeofenceResult(
                        isWithinFence: distance <= radiusMeters,
                        distanceMeters: distance,
                        authorizationDenied: false
                    ))
                }
                // Clean up on the actor — can't mutate actor-isolated state from this nonisolated closure.
                Task { [weak self] in
                    await self?.clearLocationDelegate()
                }
            }
            locationManager.delegate = delegate
            _locationDelegate = delegate

            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                // Delegate will receive didChangeAuthorization and call requestLocation once granted.
            case .restricted, .denied:
                delegate.resolve(.denied)
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            @unknown default:
                delegate.resolve(.failed)
            }
        }
    }

    // Stored property to keep the delegate alive
    private var _locationDelegate: LocationDelegate?

    /// Actor-hop helper so non-isolated delegate callbacks can clear the strong reference.
    private func clearLocationDelegate() {
        _locationDelegate = nil
    }

    struct GeofenceResult: Sendable {
        let isWithinFence: Bool
        let distanceMeters: Double?
        let authorizationDenied: Bool
    }
}

// MARK: - CLLocationManagerDelegate Helper

enum LocationOutcome {
    case located(CLLocation)
    case denied
    case failed
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let completion: (LocationOutcome) -> Void
    private var hasCompleted = false

    init(completion: @escaping (LocationOutcome) -> Void) {
        self.completion = completion
    }

    func resolve(_ outcome: LocationOutcome) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(outcome)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return resolve(.failed) }
        resolve(.located(last))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resolve(.failed)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            resolve(.denied)
        case .notDetermined:
            break
        @unknown default:
            resolve(.failed)
        }
    }
}
