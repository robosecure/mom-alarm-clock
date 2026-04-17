import Foundation

/// The method a child must use to prove they are awake.
/// Multiple methods can be required in sequence for higher escalation levels.
enum VerificationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case qr          // Scan a QR code placed outside the bedroom
    case photo       // Take a photo (e.g., breakfast, brushed teeth)
    case motion      // Walk a minimum number of steps / shake phone
    case quiz        // Answer math or trivia questions
    case geofence    // Reach a specific location (e.g., kitchen)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qr:       "QR Code Scan"
        case .photo:    "Photo Verification"
        case .motion:   "Motion / Steps"
        case .quiz:     "Wake-Up Quiz"
        case .geofence: "Location Check"
        }
    }

    var systemImage: String {
        switch self {
        case .qr:       "qrcode.viewfinder"
        case .photo:    "camera.fill"
        case .motion:   "figure.walk"
        case .quiz:     "brain.head.profile"
        case .geofence: "location.fill"
        }
    }

    var description: String {
        switch self {
        case .qr:       "Scan a QR code placed in another room to prove you got out of bed."
        case .photo:    "Take a photo of a specific item or activity to verify you are awake."
        case .motion:   "Walk a minimum number of steps to verify motion."
        case .quiz:     "Answer math or trivia questions correctly — harder at higher escalation."
        case .geofence: "Arrive at a designated location (e.g., kitchen) to dismiss the alarm."
        }
    }

    /// Whether this method is fully implemented for launch.
    /// QR: placeholder scanner, no real camera. Geofence: no map picker for target location.
    var isAvailableForLaunch: Bool {
        switch self {
        case .qr, .geofence: false
        default: true
        }
    }

    /// Whether this method always requires parent review regardless of confirmation policy.
    /// Photo verification is never auto-approved — the parent must confirm.
    var alwaysRequiresParentReview: Bool {
        switch self {
        case .photo: true
        default: false
        }
    }

    /// Methods available at each tier. Higher tiers unlock all lower-tier methods.
    /// Filters out methods not ready for launch (e.g., QR code placeholder).
    static func available(at tier: VerificationTier) -> [VerificationMethod] {
        let all: [VerificationMethod] = switch tier {
        case .easy:   [.motion, .quiz]
        case .medium: [.motion, .quiz, .photo]
        case .hard:   [.motion, .quiz, .photo, .geofence]
        }
        return all.filter(\.isAvailableForLaunch)
    }
}
