import Foundation

/// Represents a child managed by a parent.
/// Synced via CloudKit so both devices share the same data.
struct ChildProfile: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()

    /// Display name for the child.
    var name: String

    /// Age — used to adjust quiz difficulty and reward thresholds.
    var age: Int

    /// URL to the child's avatar image (stored in CloudKit assets).
    var avatarURL: URL?

    /// Pairing code used during initial device linking. Expires after first use.
    var pairingCode: String?

    /// Whether this child's device has been successfully paired.
    var isPaired: Bool = false

    /// The CKRecord.ID name for the child's CloudKit record.
    var cloudKitRecordName: String?

    /// Current alarm schedules for this child.
    var alarmScheduleIDs: [UUID] = []

    /// Cumulative stats.
    var stats: Stats = Stats()

    /// Last time the child device sent a heartbeat.
    var lastHeartbeat: Date?

    /// When this profile was created.
    var createdAt: Date = Date()
}

// MARK: - Stats

extension ChildProfile {
    /// Aggregated statistics for the child, displayed on the parent dashboard.
    struct Stats: Codable, Sendable, Equatable {
        /// Current consecutive days of on-time wake-ups.
        var currentStreak: Int = 0
        /// Best-ever streak.
        var bestStreak: Int = 0
        /// Total mornings where alarm was verified on time.
        var onTimeCount: Int = 0
        /// Total mornings where alarm was snoozed or escalated.
        var lateCount: Int = 0
        /// Total tamper events detected.
        var tamperEventCount: Int = 0
        /// Average minutes from alarm to verification.
        var averageWakeMinutes: Double = 0
        /// Reward points earned (for the reward store).
        var rewardPoints: Int = 0
    }
}

// MARK: - Pairing

extension ChildProfile {
    /// Generates a 6-character alphanumeric pairing code.
    static func generatePairingCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Omit confusing chars: I, O, 0, 1
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
