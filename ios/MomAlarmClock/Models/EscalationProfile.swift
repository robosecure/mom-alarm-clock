import Foundation

/// Defines how the alarm escalates over time when the child does not verify.
/// Each level specifies the minutes after alarm time when it activates,
/// and the consequences that apply at that level.
struct EscalationProfile: Codable, Sendable, Equatable {
    var levels: [Level]

    /// A single escalation step.
    struct Level: Codable, Sendable, Equatable, Identifiable {
        var id: UUID = UUID()
        /// Minutes after alarm time when this level kicks in.
        var minutesAfterAlarm: Int
        /// What happens at this level.
        var action: Action
        /// Optional verification methods required at this level (overrides default).
        var requiredVerification: [VerificationMethod]?
    }

    /// Actions that can be applied at each escalation level.
    enum Action: String, Codable, Sendable, CaseIterable {
        case gentleReminder      // Soft chime, no consequences
        case increasedVolume     // Louder alarm sound
        case parentNotified      // Push notification to parent device
        case appLockPartial      // Block entertainment apps (games, social)
        case appLockFull         // Block everything except phone & emergency
        case parentCallTriggered // Auto-dial parent's phone

        var displayName: String {
            switch self {
            case .gentleReminder:      "Gentle Reminder"
            case .increasedVolume:     "Increased Volume"
            case .parentNotified:      "Parent Notified"
            case .appLockPartial:      "Block Entertainment Apps"
            case .appLockFull:         "Full App Lock"
            case .parentCallTriggered: "Call Parent"
            }
        }

        var systemImage: String {
            switch self {
            case .gentleReminder:      "bell"
            case .increasedVolume:     "speaker.wave.3"
            case .parentNotified:      "bell.badge"
            case .appLockPartial:      "lock.app.dashed"
            case .appLockFull:         "lock.shield"
            case .parentCallTriggered: "phone.arrow.up.right"
            }
        }
    }

    /// Default escalation profile: gentle -> loud -> notify parent -> lock apps -> full lock.
    static let `default` = EscalationProfile(levels: [
        Level(minutesAfterAlarm: 0,  action: .gentleReminder),
        Level(minutesAfterAlarm: 5,  action: .increasedVolume),
        Level(minutesAfterAlarm: 10, action: .parentNotified),
        Level(minutesAfterAlarm: 15, action: .appLockPartial),
        Level(minutesAfterAlarm: 25, action: .appLockFull),
        Level(minutesAfterAlarm: 30, action: .parentCallTriggered),
    ])

    /// Returns the current escalation level for a given number of minutes since the alarm fired.
    func currentLevel(minutesSinceAlarm: Int) -> Level? {
        levels
            .filter { $0.minutesAfterAlarm <= minutesSinceAlarm }
            .max(by: { $0.minutesAfterAlarm < $1.minutesAfterAlarm })
    }

    /// Returns the next escalation level after the current time.
    func nextLevel(minutesSinceAlarm: Int) -> Level? {
        levels
            .filter { $0.minutesAfterAlarm > minutesSinceAlarm }
            .min(by: { $0.minutesAfterAlarm < $1.minutesAfterAlarm })
    }
}
