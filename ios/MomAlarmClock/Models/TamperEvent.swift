import Foundation

/// Records a detected tamper attempt — any action the child takes to circumvent the alarm system.
/// These are reported to the parent in real time and stored in session history.
struct TamperEvent: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()

    /// When the tamper event was detected.
    var timestamp: Date = Date()

    /// The type of tampering detected.
    var type: TamperType

    /// Human-readable description of what happened.
    var detail: String

    /// Severity level for parent notification prioritization.
    var severity: Severity

    /// The child profile this event belongs to.
    var childProfileID: UUID

    /// The morning session this event occurred during (nil if outside a session).
    var morningSessionID: UUID?
}

// MARK: - TamperType

extension TamperEvent {
    enum TamperType: String, Codable, Sendable, CaseIterable {
        case volumeLowered        // Device volume was reduced during alarm
        case notificationsDisabled // Notification permissions were revoked
        case appForceQuit         // App was force-quit during an active session
        case airplaneModeEnabled  // Network connectivity lost during session
        case doNotDisturbEnabled  // Focus/DND mode was enabled
        case devicePoweredOff     // Heartbeat lost — device may have been turned off
        case locationSpoofing     // GPS location appears inconsistent
        case timeZoneChanged      // System time was manually altered

        var displayName: String {
            switch self {
            case .volumeLowered:         "Volume Lowered"
            case .notificationsDisabled: "Notifications Disabled"
            case .appForceQuit:          "App Force Quit"
            case .airplaneModeEnabled:   "Airplane Mode"
            case .doNotDisturbEnabled:   "Do Not Disturb"
            case .devicePoweredOff:      "Device Powered Off"
            case .locationSpoofing:      "Location Spoofing"
            case .timeZoneChanged:       "Time Zone Changed"
            }
        }
    }
}

// MARK: - Severity

extension TamperEvent {
    enum Severity: String, Codable, Sendable, Comparable {
        case low
        case medium
        case high
        case critical

        private var sortOrder: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .high: 2
            case .critical: 3
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}
