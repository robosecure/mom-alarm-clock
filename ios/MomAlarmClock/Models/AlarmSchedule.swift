import Foundation

/// Represents a configured alarm schedule for a child.
/// Stored locally and synced to CloudKit so both parent and child devices share the same config.
struct AlarmSchedule: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()

    /// The target wake-up time (hour + minute, no date component).
    var alarmTime: AlarmTime

    /// Which days of the week the alarm is active (1 = Sunday ... 7 = Saturday).
    var activeDays: Set<Int>

    /// Primary verification method the child must complete.
    var primaryVerification: VerificationMethod

    /// Optional fallback verification if primary cannot be completed.
    var fallbackVerification: VerificationMethod?

    /// How the alarm escalates over time.
    var escalation: EscalationProfile

    /// Snooze configuration.
    var snoozeRules: SnoozeRules

    /// Whether the alarm is currently enabled.
    var isEnabled: Bool = true

    /// Human-readable label (e.g., "School Days", "Weekend").
    var label: String = "Alarm"

    /// The child profile ID this alarm belongs to.
    var childProfileID: UUID

    /// When this schedule was last modified (for sync conflict resolution).
    var lastModified: Date = Date()
}

// MARK: - AlarmTime

extension AlarmSchedule {
    /// Simple hour + minute representation, independent of calendar date.
    struct AlarmTime: Codable, Sendable, Equatable {
        var hour: Int    // 0–23
        var minute: Int  // 0–59

        /// Returns the next `Date` at this time on or after the given reference date.
        func nextOccurrence(after reference: Date = .now, on weekday: Int? = nil) -> Date? {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.second = 0
            if let weekday {
                components.weekday = weekday
            }
            return Calendar.current.nextDate(
                after: reference,
                matching: components,
                matchingPolicy: .nextTime
            )
        }

        var formatted: String {
            let h = hour % 12 == 0 ? 12 : hour % 12
            let period = hour < 12 ? "AM" : "PM"
            return String(format: "%d:%02d %@", h, minute, period)
        }
    }
}

// MARK: - SnoozeRules

extension AlarmSchedule {
    /// Controls whether and how many times the child can snooze.
    struct SnoozeRules: Codable, Sendable, Equatable {
        /// Whether snooze is allowed at all.
        var allowed: Bool = true
        /// Maximum number of snoozes per morning.
        var maxCount: Int = 2
        /// Duration of each snooze in minutes.
        var durationMinutes: Int = 5
        /// Whether snooze duration decreases with each use.
        var decreasingDuration: Bool = true

        /// Returns the snooze duration for the Nth snooze (0-indexed).
        func duration(forSnooze index: Int) -> Int {
            guard allowed, index < maxCount else { return 0 }
            if decreasingDuration {
                return max(1, durationMinutes - (index * 2))
            }
            return durationMinutes
        }
    }
}
