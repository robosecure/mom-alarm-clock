import Foundation

/// Represents a single morning's alarm session — from when the alarm fires
/// until the child successfully verifies (or fails and the session expires).
/// Stored for history and synced to the parent device.
struct MorningSession: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()

    /// The child this session belongs to.
    var childProfileID: UUID

    /// The alarm schedule that triggered this session.
    var alarmScheduleID: UUID

    /// When the alarm originally fired.
    var alarmFiredAt: Date

    /// Current state of the session.
    var state: State = .ringing

    /// Current escalation step index (into the escalation profile).
    var currentEscalationStep: Int = 0

    /// Number of snoozes used this session.
    var snoozeCount: Int = 0

    /// When the child completed verification (nil if not yet verified).
    var verifiedAt: Date?

    /// The verification method that was used to complete.
    var verifiedWith: VerificationMethod?

    /// Whether the device is currently in lock mode (entertainment apps blocked).
    var isDeviceLocked: Bool = false

    /// Tamper events detected during this session.
    var tamperEvents: [TamperEvent] = []

    /// Optional parent message sent during this session.
    var parentMessage: String?

    /// When this session was last updated.
    var lastUpdated: Date = Date()
}

// MARK: - State

extension MorningSession {
    enum State: String, Codable, Sendable {
        case ringing       // Alarm is actively sounding
        case snoozed       // Child hit snooze, waiting for next ring
        case escalating    // Alarm has escalated past gentle phase
        case verifying     // Child is in the verification flow
        case verified      // Child completed verification — session success
        case failed        // Session timed out or parent manually dismissed
        case cancelled     // Parent cancelled the alarm remotely
    }

    /// Minutes elapsed since the alarm originally fired.
    var minutesSinceAlarm: Int {
        Int(Date.now.timeIntervalSince(alarmFiredAt) / 60)
    }

    /// Whether the session is still active (not in a terminal state).
    var isActive: Bool {
        switch state {
        case .ringing, .snoozed, .escalating, .verifying:
            return true
        case .verified, .failed, .cancelled:
            return false
        }
    }

    /// Duration from alarm to verification, if completed.
    var wakeUpDuration: TimeInterval? {
        guard let verifiedAt else { return nil }
        return verifiedAt.timeIntervalSince(alarmFiredAt)
    }

    /// Whether the child woke up within the gentle reminder window (first 5 minutes).
    var wasOnTime: Bool {
        guard let duration = wakeUpDuration else { return false }
        return duration < 5 * 60
    }
}
