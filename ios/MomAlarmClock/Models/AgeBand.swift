import Foundation

/// Age band for privacy-safe age grouping. Stored as a string in Firestore.
/// Prefer age band over exact DOB — used only to tailor verification difficulty and wording.
enum AgeBand: String, Codable, Sendable, CaseIterable, Identifiable {
    case young   = "5-7"
    case middle  = "8-10"
    case preteen = "11-13"
    case teen    = "14+"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Creates an AgeBand from a numeric age.
    init(age: Int) {
        switch age {
        case ...7:   self = .young
        case 8...10: self = .middle
        case 11...13: self = .preteen
        default:     self = .teen
        }
    }

    /// Content profile that maps this age band to default content settings.
    var contentProfile: AgeContentProfile {
        switch self {
        case .young:
            AgeContentProfile(
                quizDifficulty: .easy,
                quizCount: 2,
                mathRange: 1...10,
                encouragementStyle: .warm,
                verificationTimeoutSeconds: 90,
                sampleEncouragement: "You're doing great! Almost there."
            )
        case .middle:
            AgeContentProfile(
                quizDifficulty: .easy,
                quizCount: 3,
                mathRange: 1...20,
                encouragementStyle: .supportive,
                verificationTimeoutSeconds: 60,
                sampleEncouragement: "Nice work, keep it up!"
            )
        case .preteen:
            AgeContentProfile(
                quizDifficulty: .medium,
                quizCount: 3,
                mathRange: 10...50,
                encouragementStyle: .direct,
                verificationTimeoutSeconds: 45,
                sampleEncouragement: "Good job."
            )
        case .teen:
            AgeContentProfile(
                quizDifficulty: .medium,
                quizCount: 3,
                mathRange: 10...100,
                encouragementStyle: .minimal,
                verificationTimeoutSeconds: 30,
                sampleEncouragement: "Done."
            )
        }
    }
}

/// Content settings derived from a child's age band.
/// Guardian overrides and tomorrow overrides always take priority over these defaults.
struct AgeContentProfile: Sendable {
    let quizDifficulty: VerificationService.QuizDifficulty
    let quizCount: Int
    let mathRange: ClosedRange<Int>
    let encouragementStyle: EncouragementStyle
    let verificationTimeoutSeconds: Int
    let sampleEncouragement: String

    enum EncouragementStyle: String, Sendable {
        case warm       // Younger: "You're doing amazing!"
        case supportive // Middle: "Nice work, keep going!"
        case direct     // Preteen: "Good job."
        case minimal    // Teen: "Done."
    }
}
