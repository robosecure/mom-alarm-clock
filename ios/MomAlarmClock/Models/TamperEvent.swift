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

    /// Consequence applied for this tamper event (computed from type if nil).
    var consequence: TamperConsequence?

    /// Returns the effective consequence, using the default for this type if none was set.
    var effectiveConsequence: TamperConsequence {
        consequence ?? TamperConsequence.defaultConsequence(for: type)
    }
}

// MARK: - TamperType

extension TamperEvent {
    /// Each type has real detection code in TamperDetectionService.
    /// Device offline / app force-quit are NOT formal TamperEvents — they are
    /// detected parent-side via HeartbeatService.isDeviceOffline() and shown as
    /// a UX indicator, not recorded as tamper history.
    enum TamperType: String, Codable, Sendable, CaseIterable {
        case volumeLowered        // KVO on AVAudioSession.outputVolume
        case notificationsDisabled // UNUserNotificationCenter polling
        case networkLost          // NWPathMonitor detects connectivity loss
        case timeZoneChanged      // NSSystemTimeZoneDidChange notification

        var displayName: String {
            switch self {
            case .volumeLowered:         "Volume Lowered"
            case .notificationsDisabled: "Notifications Disabled"
            case .networkLost:           "Network Lost"
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
