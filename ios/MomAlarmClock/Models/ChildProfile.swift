import Foundation

/// Represents a child managed by a parent.
/// Synced via CloudKit so both devices share the same data.
struct ChildProfile: Codable, Identifiable, Sendable, Equatable {
    var id: UUID = UUID()

    /// Display name for the child.
    var name: String

    /// Age — used to adjust quiz difficulty and reward thresholds.
    var age: Int

    /// URL to the child's avatar image.
    var avatarURL: URL?

    /// Pairing code used during initial device linking. Expires after first use.
    var pairingCode: String?

    /// Whether this child's device has been successfully paired.
    var isPaired: Bool = false

    /// Current alarm schedules for this child.
    var alarmScheduleIDs: [UUID] = []

    /// Cumulative stats.
    var stats: Stats = Stats()

    /// Last time the child device sent a heartbeat.
    var lastHeartbeat: Date?

    /// Pending verification tier escalation from tamper consequences.
    /// Applied on the next alarm session, then cleared.
    var pendingTierEscalation: Bool = false

    /// Guardian-set overrides for the next morning only. Auto-clears after one completed session.
    var nextMorningOverrides: NextMorningOverrides?

    /// Voice alarm metadata. Guardian records a clip that plays when the child's alarm fires.
    var voiceAlarm: VoiceAlarmMetadata?

    /// When this profile was created.
    var createdAt: Date = Date()

    /// Returns the effective verification tier for the next alarm,
    /// considering tamper-based escalation.
    func effectiveVerificationTier(base: VerificationTier) -> VerificationTier {
        pendingTierEscalation ? base.escalated : base
    }
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

// MARK: - Voice Alarm

extension ChildProfile {
    /// Metadata for a guardian-recorded voice alarm clip.
    struct VoiceAlarmMetadata: Codable, Sendable, Equatable {
        /// Whether the voice alarm is active.
        var enabled: Bool = true
        /// Firebase Storage path to the audio file.
        var storagePath: String
        /// When the clip was last updated (for cache invalidation).
        var updatedAt: Date
        /// File size in bytes (for cache validation).
        var fileSize: Int?
    }
}

// MARK: - Next Morning Overrides

extension ChildProfile {
    /// One-shot guardian overrides for the next morning session.
    /// Applied once when the alarm fires, then auto-cleared when the session completes.
    struct NextMorningOverrides: Codable, Sendable, Equatable {
        /// Override verification method (nil = use alarm schedule default).
        var verificationMethod: VerificationMethod?
        /// Override difficulty tier.
        var tier: VerificationTier?
        /// Override max quiz attempts per question (2 or 3).
        var maxAttempts: Int?
        /// Override quiz timer seconds (30, 45, or 60).
        var timerSeconds: Int?
        /// Enable calm mode interstitial before verification.
        var calmMode: Bool?
        /// When this override was set.
        var setAt: Date = Date()
        /// Who set it (guardian userID for audit).
        var setBy: String?
    }
}

// MARK: - Pairing

extension ChildProfile {
    /// Generates a 10-character alphanumeric pairing code.
    static func generatePairingCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Omit confusing chars: I, O, 0, 1
        return String((0..<10).map { _ in chars.randomElement()! })
    }
}
