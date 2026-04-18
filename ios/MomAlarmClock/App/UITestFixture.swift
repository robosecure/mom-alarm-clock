import Foundation

#if DEBUG

/// DEBUG-only launch-argument driven LocalStore seeder.
///
/// Usage (from bash / xcrun):
///   xcrun simctl launch <UDID> com.momclock.MomAlarmClock -ui-fixture dashboard
///
/// Or in Xcode scheme launch args:
///   -ui-fixture dashboard
///
/// Drives screenshot automation and XCUITest setup. Writes directly to the same
/// Documents/MomAlarmClockStore/*.json files LocalStore reads from, synchronously
/// (no actor hop) so the app launches into the pre-seeded state.
///
/// NOT compiled in Release builds.
enum UITestFixture {

    /// Reads `-ui-fixture <name>` from launch arguments and seeds LocalStore accordingly.
    /// Call from `MomAlarmClockApp.init()` BEFORE creating services that read LocalStore.
    static func seedIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-ui-fixture"),
              idx + 1 < args.count else {
            return
        }
        let fixture = args[idx + 1]

        // Always wipe first — deterministic starting state.
        clearStore()

        switch fixture {
        case "clean":
            // Nothing to seed — used to verify first-launch state.
            break
        case "dashboard":
            seedDashboard()
        case "activeAlarm":
            seedActiveAlarm()
        case "activeQuiz":
            seedActiveQuiz()
        case "trustResult":
            seedTrustResult()
        case "voiceAlarm":
            seedVoiceAlarm()
        case "alarmSettings":
            seedAlarmSettings()
        case "pendingReview":
            seedPendingReview()
        case "rewardStore":
            seedRewardStore()
        default:
            DebugLog.log("[UITestFixture] Unknown fixture: \(fixture)")
        }

        DebugLog.log("[UITestFixture] Seeded fixture: \(fixture)")
    }

    // MARK: - Store Access

    private static var storeDirectory: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = docs.appendingPathComponent("MomAlarmClockStore", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func clearStore() {
        let dir = storeDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func write<T: Codable>(_ value: T, forKey key: String) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .deferredToDate
            let data = try encoder.encode(value)
            let url = storeDirectory.appendingPathComponent("\(key).json")
            try data.write(to: url, options: [.atomic])
        } catch {
            DebugLog.log("[UITestFixture] Failed to write \(key): \(error)")
        }
    }

    // MARK: - Fixture Values

    /// Deterministic IDs so screenshots are reproducible across runs.
    private static let familyID = "fixture-family-001"
    private static let parentUserID = "parent-fixture"
    private static let childUserID = "child-fixture"
    private static let childProfileID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private static func demoChild(
        name: String = "Emma",
        age: Int = 8,
        streak: Int = 7,
        points: Int = 125,
        voiceEnabled: Bool = false
    ) -> ChildProfile {
        var child = ChildProfile(
            id: childProfileID,
            name: name,
            age: age,
            avatarURL: nil,
            pairingCode: nil,
            isPaired: true,
            alarmScheduleIDs: [alarmID]
        )
        child.stats = ChildProfile.Stats(
            currentStreak: streak,
            bestStreak: max(streak, 12),
            onTimeCount: 34,
            lateCount: 4,
            tamperEventCount: 0,
            averageWakeMinutes: 2.4,
            rewardPoints: points
        )
        if voiceEnabled {
            child.voiceAlarm = ChildProfile.VoiceAlarmMetadata(
                enabled: true,
                storagePath: "families/\(familyID)/voice/emma.m4a",
                updatedAt: Date().addingTimeInterval(-86400 * 2),
                fileSize: 184_320
            )
        }
        return child
    }

    private static func demoAlarm(
        hour: Int = 7,
        minute: Int = 0,
        method: VerificationMethod = .quiz,
        tier: VerificationTier = .medium,
        policy: ConfirmationPolicy = .autoAcknowledge,
        label: String = "School Days"
    ) -> AlarmSchedule {
        AlarmSchedule(
            id: alarmID,
            alarmTime: AlarmSchedule.AlarmTime(hour: hour, minute: minute),
            activeDays: [2, 3, 4, 5, 6], // Mon–Fri
            primaryVerification: method,
            fallbackVerification: nil,
            escalation: .default,
            verificationTier: tier,
            confirmationPolicy: policy,
            snoozeRules: AlarmSchedule.SnoozeRules(
                allowed: true,
                maxCount: 2,
                durationMinutes: 5,
                decreasingDuration: true
            ),
            isEnabled: true,
            skipUntil: nil,
            label: label,
            childProfileID: childProfileID,
            lastModified: Date()
        )
    }

    private static func parentAuthState() -> AuthState {
        AuthState(
            userID: parentUserID,
            familyID: familyID,
            role: .parent,
            displayName: "Sarah"
        )
    }

    private static func childAuthState() -> AuthState {
        AuthState(
            userID: childUserID,
            familyID: familyID,
            role: .child,
            displayName: "Emma"
        )
    }

    // MARK: - Fixtures

    /// Parent dashboard with one child, healthy stats, one alarm.
    private static func seedDashboard() {
        write(parentAuthState(), forKey: "authState")
        let child = demoChild()
        write([child], forKey: "childProfiles")
        write([demoAlarm()], forKey: "alarmSchedules")
        // Recent sessions for history graph
        write(recentHistory(childID: child.id), forKey: "recentSessions")
    }

    /// Child device with an actively-ringing alarm.
    private static func seedActiveAlarm() {
        write(childAuthState(), forKey: "authState")
        let child = demoChild()
        write(child, forKey: "childProfile")
        let alarm = demoAlarm()
        write([alarm], forKey: "alarmSchedules")

        var session = MorningSession(
            id: sessionID,
            childProfileID: child.id,
            alarmScheduleID: alarm.id,
            alarmFiredAt: Date().addingTimeInterval(-45),
            state: .ringing
        )
        session.confirmationPolicy = .autoAcknowledge
        write(session, forKey: "activeSession")
    }

    /// Child is mid-quiz verification.
    private static func seedActiveQuiz() {
        write(childAuthState(), forKey: "authState")
        let child = demoChild()
        write(child, forKey: "childProfile")
        let alarm = demoAlarm(method: .quiz, tier: .medium)
        write([alarm], forKey: "alarmSchedules")

        var session = MorningSession(
            id: sessionID,
            childProfileID: child.id,
            alarmScheduleID: alarm.id,
            alarmFiredAt: Date().addingTimeInterval(-90),
            state: .verifying
        )
        session.verificationStartedAt = Date().addingTimeInterval(-30)
        session.verificationAttempts = 1
        session.confirmationPolicy = .autoAcknowledge
        write(session, forKey: "activeSession")
    }

    /// Trust Mode result screen — child has verified successfully.
    private static func seedTrustResult() {
        write(childAuthState(), forKey: "authState")
        let child = demoChild()
        write(child, forKey: "childProfile")
        let alarm = demoAlarm(policy: .autoAcknowledge)
        write([alarm], forKey: "alarmSchedules")

        let firedAt = Date().addingTimeInterval(-180)
        let verifiedAt = Date().addingTimeInterval(-30)
        var session = MorningSession(
            id: sessionID,
            childProfileID: child.id,
            alarmScheduleID: alarm.id,
            alarmFiredAt: firedAt,
            state: .verified
        )
        session.verifiedAt = verifiedAt
        session.verifiedWith = .quiz
        session.confirmationPolicy = .autoAcknowledge
        session.verificationAttempts = 1
        session.verificationDurationSeconds = 24
        session.rewardOptimistic = true
        write(session, forKey: "activeSession")
    }

    /// Parent dashboard with voice alarm configured.
    private static func seedVoiceAlarm() {
        write(parentAuthState(), forKey: "authState")
        let child = demoChild(voiceEnabled: true)
        write([child], forKey: "childProfiles")
        write([demoAlarm()], forKey: "alarmSchedules")
    }

    /// Parent-side alarm edit / settings screen context.
    private static func seedAlarmSettings() {
        write(parentAuthState(), forKey: "authState")
        let child = demoChild()
        write([child], forKey: "childProfiles")
        let alarms = [
            demoAlarm(hour: 7, minute: 0, label: "School Days"),
            AlarmSchedule(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222223")!,
                alarmTime: AlarmSchedule.AlarmTime(hour: 8, minute: 30),
                activeDays: [1, 7],
                primaryVerification: .photo,
                fallbackVerification: nil,
                escalation: .default,
                verificationTier: .easy,
                confirmationPolicy: .autoAcknowledge,
                snoozeRules: AlarmSchedule.SnoozeRules(),
                isEnabled: true,
                skipUntil: nil,
                label: "Weekend",
                childProfileID: child.id,
                lastModified: Date()
            ),
        ]
        write(alarms, forKey: "alarmSchedules")
    }

    /// Parent dashboard with a session pending review.
    private static func seedPendingReview() {
        write(parentAuthState(), forKey: "authState")
        let child = demoChild()
        write([child], forKey: "childProfiles")
        let alarm = demoAlarm(policy: .requireParentApproval)
        write([alarm], forKey: "alarmSchedules")

        let firedAt = Date().addingTimeInterval(-600)
        var session = MorningSession(
            id: sessionID,
            childProfileID: child.id,
            alarmScheduleID: alarm.id,
            alarmFiredAt: firedAt,
            state: .pendingParentReview
        )
        session.verifiedAt = Date().addingTimeInterval(-120)
        session.verifiedWith = .photo
        session.confirmationPolicy = .requireParentApproval
        session.reviewWindowEndsAt = Date().addingTimeInterval(300)
        write(session, forKey: "activeSession")
        write([session] + recentHistory(childID: child.id), forKey: "recentSessions")
    }

    /// Reward store screen — child, with points to spend.
    private static func seedRewardStore() {
        write(childAuthState(), forKey: "authState")
        let child = demoChild(points: 340)
        write(child, forKey: "childProfile")
        write([demoAlarm()], forKey: "alarmSchedules")
    }

    // MARK: - History Seed

    private static func recentHistory(childID: UUID) -> [MorningSession] {
        let cal = Calendar.current
        return (1...7).compactMap { daysAgo -> MorningSession? in
            guard let fireDate = cal.date(
                byAdding: .day,
                value: -daysAgo,
                to: Date()
            ) else { return nil }
            var session = MorningSession(
                id: UUID(),
                childProfileID: childID,
                alarmScheduleID: alarmID,
                alarmFiredAt: fireDate,
                state: .verified
            )
            session.verifiedAt = fireDate.addingTimeInterval(Double.random(in: 30...240))
            session.verifiedWith = .quiz
            session.verificationAttempts = 1
            session.verificationDurationSeconds = Int.random(in: 15...60)
            session.confirmationPolicy = .autoAcknowledge
            return session
        }
    }
}

#endif
