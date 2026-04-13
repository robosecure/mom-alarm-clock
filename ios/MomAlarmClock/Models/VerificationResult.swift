import Foundation

/// Proof metadata captured when a child completes (or attempts) verification.
/// Sent to the parent as part of the two-way confirmation protocol.
struct VerificationResult: Codable, Sendable, Equatable {
    /// Which method was used.
    var method: VerificationMethod

    /// When verification was completed on the child's device.
    var completedAt: Date

    /// The tier the verification was performed at.
    var tier: VerificationTier

    /// Whether the verification passed all requirements.
    var passed: Bool

    // MARK: - Method-Specific Proof Metadata

    /// Motion: number of steps recorded.
    var stepCount: Int?

    /// Quiz: number of questions answered correctly out of total.
    var quizCorrect: Int?
    var quizTotal: Int?

    /// Quiz: average seconds per question.
    var quizAverageSeconds: Double?

    /// QR: SHA256 hash of scanned payload (proves physical scan, not the raw code).
    var qrHash: String?

    /// Photo: local file path or cloud storage reference for the submitted photo.
    var photoReference: String?

    /// Geofence: distance in meters from the target when verified.
    var gpsDistanceMeters: Double?

    /// Device timestamp (for detecting clock manipulation — compare against server time).
    var deviceTimestamp: Date

    // MARK: - Computed

    /// Human-readable summary for the parent.
    var proofSummary: String {
        switch method {
        case .motion:
            let steps = stepCount ?? 0
            return "\(steps) steps recorded"
        case .quiz:
            let correct = quizCorrect ?? 0
            let total = quizTotal ?? 0
            let avg = quizAverageSeconds.map { String(format: "%.1fs avg", $0) } ?? ""
            return "\(correct)/\(total) correct \(avg)"
        case .qr:
            return "QR code scanned and validated"
        case .photo:
            return photoReference != nil ? "Photo submitted for review" : "No photo captured"
        case .geofence:
            let dist = gpsDistanceMeters.map { String(format: "%.0fm from target", $0) } ?? ""
            return "Location verified \(dist)"
        }
    }
}
