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
                continuation.yield(MotionProgress(currentSteps: 0, requiredSteps: requiredSteps, isComplete: false))
                continuation.finish()
                return
            }

            let pedometer = CMPedometer()
            guard CMPedometer.isStepCountingAvailable() else {
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
                    isComplete: steps >= requiredSteps
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
    func checkGeofence(
        targetLatitude: Double,
        targetLongitude: Double,
        radiusMeters: Double = 10
    ) async -> GeofenceResult {
        let target = CLLocation(latitude: targetLatitude, longitude: targetLongitude)

        return await withCheckedContinuation { continuation in
            // CLLocationManager needs a delegate — simplified here for the scaffold.
            // In production, use a proper CLLocationManagerDelegate wrapper.
            let delegate = LocationDelegate { location in
                guard let location else {
                    continuation.resume(returning: GeofenceResult(isWithinFence: false, distanceMeters: nil))
                    return
                }
                let distance = location.distance(from: target)
                continuation.resume(returning: GeofenceResult(
                    isWithinFence: distance <= radiusMeters,
                    distanceMeters: distance
                ))
            }
            locationManager.delegate = delegate
            locationManager.requestLocation()
            // Hold a strong reference so the delegate isn't deallocated
            _locationDelegate = delegate
        }
    }

    // Stored property to keep the delegate alive
    private var _locationDelegate: LocationDelegate?

    struct GeofenceResult: Sendable {
        let isWithinFence: Bool
        let distanceMeters: Double?
    }
}

// MARK: - CLLocationManagerDelegate Helper

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let completion: (CLLocation?) -> Void
    private var hasCompleted = false

    init(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(nil)
    }
}
