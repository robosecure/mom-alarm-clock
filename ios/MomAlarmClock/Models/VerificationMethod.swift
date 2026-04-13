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
        case .motion:   "Walk a minimum number of steps or shake the phone to verify motion."
        case .quiz:     "Answer math or trivia questions correctly — harder at higher escalation."
        case .geofence: "Arrive at a designated location (e.g., kitchen) to dismiss the alarm."
        }
    }
}
