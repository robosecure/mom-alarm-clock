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

    /// Generates a deterministic session ID for a given alarm + child + date.
    /// This prevents duplicate sessions when the alarm fires multiple times
    /// (foreground + tap + backup reminder all call alarmDidFire).
    static func deterministicID(childID: UUID, alarmID: UUID, date: Date = .now) -> UUID {
        let cal = Calendar.current
        let dateStr = String(format: "%04d%02d%02d",
                             cal.component(.year, from: date),
                             cal.component(.month, from: date),
                             cal.component(.day, from: date))
        let seed = "\(childID.uuidString)_\(alarmID.uuidString)_\(dateStr)"
        return UUID(uuidString: deterministicUUID(from: seed)) ?? UUID()
    }

    /// Creates a UUID v5-style deterministic UUID from a string seed.
    private static func deterministicUUID(from seed: String) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let data = Data(seed.utf8)
        // Simple hash: XOR fold SHA-like pattern into 16 bytes
        for (i, byte) in data.enumerated() {
            bytes[i % 16] ^= byte
            bytes[(i + 7) % 16] &+= byte
        }
        // Set version 5 and variant bits
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let idx = hex.startIndex
        return "\(hex[idx..<hex.index(idx, offsetBy: 8)])-\(hex[hex.index(idx, offsetBy: 8)..<hex.index(idx, offsetBy: 12)])-\(hex[hex.index(idx, offsetBy: 12)..<hex.index(idx, offsetBy: 16)])-\(hex[hex.index(idx, offsetBy: 16)..<hex.index(idx, offsetBy: 20)])-\(hex[hex.index(idx, offsetBy: 20)..<hex.index(idx, offsetBy: 32)])"
    }

    /// When the alarm originally fired.
    var alarmFiredAt: Date

    /// Current state of the session.
    var state: State = .ringing

    /// Current escalation step index (into the escalation profile).
    var currentEscalationStep: Int = 0

    /// Number of snoozes used this session.
    var snoozeCount: Int = 0

    /// Number of times the guardian has denied this session's verification.
    var denialCount: Int = 0

    /// When the child completed verification (nil if not yet verified).
    var verifiedAt: Date?

    /// The verification method that was used to complete.
    var verifiedWith: VerificationMethod?

    /// Whether the device is currently in lock mode (entertainment apps blocked).
    var isDeviceLocked: Bool = false

    /// Count of tamper events detected during this session (single source of truth is the tamperEvents collection).
    var tamperCount: Int = 0

    /// Most recent tamper type detected (for quick display without querying the collection).
    var lastTamperType: String?

    /// Optional parent message sent during this session.
    var parentMessage: String?

    /// Child's message to the parent (separate from parentMessage to avoid overwrites).
    var childMessage: String?

    /// The confirmation policy in effect for this session (copied from alarm at fire time).
    var confirmationPolicy: ConfirmationPolicy = .default

    /// Proof metadata from the child's verification attempt.
    var verificationResult: VerificationResult?

    /// Parent's action on this session (approve/deny/escalate/auto-acknowledged).
    var parentAction: ParentAction?

    /// When the parent took action (nil until parent acts or window expires).
    var parentActionAt: Date?

    /// When the hybrid review window closes. Set once at verification time.
    /// Firestore rules enforce: deny/escalate only allowed if request.time <= reviewWindowEndsAt.
    var reviewWindowEndsAt: Date?

    /// Snapshot of the effective verification config used for this session.
    var effectiveConfigSnapshot: ConfigSnapshot?

    // MARK: - Verification Attempt Tracking

    /// Number of verification submissions (1 = first try, >1 = retries after denial or failure).
    var verificationAttempts: Int = 0

    /// When the child started the current verification attempt.
    var verificationStartedAt: Date?

    /// Seconds spent on the successful verification attempt.
    var verificationDurationSeconds: Int?

    // MARK: - Reward Fields

    /// Client-side optimistic reward preview (may differ slightly from server).
    var rewardOptimistic: Bool = false

    /// Server-authoritative reward applied flag. Only written by Cloud Function.
    /// Client must NEVER set this — it controls idempotency on the server.
    var rewardServerApplied: Bool = false

    /// Points delta applied by server (authoritative). Written by Cloud Function.
    var rewardPointsDelta: Int?

    /// Reason codes for the reward (e.g., ["on_time_first_try", "no_snooze_bonus"]).
    /// Written by Cloud Function for audit trail.
    var rewardReasonCodes: [String]?

    /// Server timestamp when reward was applied. Written by Cloud Function.
    var rewardAppliedAt: Date?

    /// Rubric version used for this reward calculation.
    var rewardRubricVersion: Int = 1

    /// When this session was last updated.
    var lastUpdated: Date = Date()

    /// Monotonically increasing version for state regression prevention.
    var version: Int = 0
}

// MARK: - Config Snapshot

extension MorningSession {
    /// Lightweight snapshot of the verification config used for this session.
    /// Stored on the session doc so Cloud Functions can calculate rewards
    /// and so overrides don't retroactively change an in-progress session.
    struct ConfigSnapshot: Codable, Sendable, Equatable {
        var method: String
        var tier: String
        var maxAttempts: Int
        var timerSeconds: Int
        var calmMode: Bool

        init(from config: EffectiveVerificationConfig) {
            self.method = config.method.rawValue
            self.tier = config.tier.rawValue
            self.maxAttempts = config.maxAttempts
            self.timerSeconds = config.timerSeconds
            self.calmMode = config.calmMode
        }
    }
}

// MARK: - State

extension MorningSession {
    enum State: String, Codable, Sendable {
        case ringing              // Alarm is actively sounding
        case snoozed              // Child hit snooze, waiting for next ring
        case escalating           // Alarm has escalated past gentle phase
        case verifying            // Child is in the verification flow
        case pendingParentReview  // Child completed verification, waiting for parent action
        case verified             // Verification approved — session success
        case failed               // Session timed out or parent denied
        case cancelled            // Parent cancelled the alarm remotely
    }

    /// Minutes elapsed since the alarm originally fired.
    var minutesSinceAlarm: Int {
        Int(Date.now.timeIntervalSince(alarmFiredAt) / 60)
    }

    /// Whether the session is still active (not in a terminal state).
    var isActive: Bool {
        switch state {
        case .ringing, .snoozed, .escalating, .verifying, .pendingParentReview:
            return true
        case .verified, .failed, .cancelled:
            return false
        }
    }

    /// Whether the session is waiting for the parent to act.
    var isAwaitingParent: Bool {
        state == .pendingParentReview
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

    /// Whether the parent's hybrid review window is still open.
    /// Returns false if the policy isn't hybrid, or if the window has expired.
    var isReviewWindowOpen: Bool {
        guard case .hybrid(let windowMinutes) = confirmationPolicy,
              let verifiedAt,
              state == .verified,
              parentAction == nil else {
            return false
        }
        let windowEnd = verifiedAt.addingTimeInterval(TimeInterval(windowMinutes * 60))
        return Date() < windowEnd
    }

    /// Minutes remaining in the hybrid review window (nil if not applicable).
    var reviewWindowMinutesRemaining: Int? {
        guard case .hybrid(let windowMinutes) = confirmationPolicy,
              let verifiedAt,
              state == .verified,
              parentAction == nil else {
            return nil
        }
        let windowEnd = verifiedAt.addingTimeInterval(TimeInterval(windowMinutes * 60))
        let remaining = windowEnd.timeIntervalSince(Date())
        return remaining > 0 ? Int(ceil(remaining / 60)) : 0
    }
}
