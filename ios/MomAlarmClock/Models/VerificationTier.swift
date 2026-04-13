import Foundation

/// Difficulty tier for verification methods. Parents choose per-alarm;
/// tamper consequences can auto-escalate the tier for the next morning.
enum VerificationTier: String, Codable, Sendable, CaseIterable, Identifiable, Comparable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy:   "Easy"
        case .medium: "Medium"
        case .hard:   "Hard"
        }
    }

    var description: String {
        switch self {
        case .easy:   "Gentle — fewer steps, simpler math, larger geofence."
        case .medium: "Standard — balanced difficulty for school days."
        case .hard:   "Strict — more steps, harder math, tighter geofence. Used after tamper events."
        }
    }

    // MARK: - Concrete Parameters

    /// Minimum steps required for motion verification.
    var requiredSteps: Int {
        switch self {
        case .easy:   30
        case .medium: 50
        case .hard:   100
        }
    }

    /// Number of quiz questions.
    var quizQuestionCount: Int {
        switch self {
        case .easy:   2
        case .medium: 3
        case .hard:   5
        }
    }

    /// Quiz difficulty level.
    var quizDifficulty: String {
        switch self {
        case .easy:   "easy"
        case .medium: "medium"
        case .hard:   "hard"
        }
    }

    /// Seconds allowed per quiz question.
    var quizTimeLimitSeconds: Int {
        switch self {
        case .easy:   60
        case .medium: 45
        case .hard:   30
        }
    }

    /// Geofence radius in meters.
    var geofenceRadiusMeters: Double {
        switch self {
        case .easy:   20
        case .medium: 10
        case .hard:   5
        }
    }

    // MARK: - Comparable

    private var sortOrder: Int {
        switch self {
        case .easy:   0
        case .medium: 1
        case .hard:   2
        }
    }

    static func < (lhs: VerificationTier, rhs: VerificationTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// Returns the next tier up, or self if already at max.
    var escalated: VerificationTier {
        switch self {
        case .easy:   .medium
        case .medium: .hard
        case .hard:   .hard
        }
    }
}
