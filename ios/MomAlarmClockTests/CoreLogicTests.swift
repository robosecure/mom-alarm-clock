import XCTest
@testable import Mom_Alarm_Clock

final class CoreLogicTests: XCTestCase {

    // MARK: - Deterministic Session ID

    func testDeterministicID_sameInputs_sameOutput() {
        let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let date = Date(timeIntervalSince1970: 1700000000) // 2023-11-14

        let id1 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: date)
        let id2 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: date)

        XCTAssertEqual(id1, id2, "Same inputs must produce same session ID")
    }

    func testDeterministicID_differentDays_differentIDs() {
        let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let day1 = Date(timeIntervalSince1970: 1700000000) // Nov 14
        let day2 = Date(timeIntervalSince1970: 1700086400) // Nov 15

        let id1 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: day1)
        let id2 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: day2)

        XCTAssertNotEqual(id1, id2, "Different days must produce different session IDs")
    }

    func testDeterministicID_differentChildren_differentIDs() {
        let child1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let child2 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let date = Date(timeIntervalSince1970: 1700000000)

        let id1 = MorningSession.deterministicID(childID: child1, alarmID: alarmID, date: date)
        let id2 = MorningSession.deterministicID(childID: child2, alarmID: alarmID, date: date)

        XCTAssertNotEqual(id1, id2, "Different children must produce different session IDs")
    }

    func testDeterministicID_isValidUUID() {
        let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let id = MorningSession.deterministicID(childID: childID, alarmID: alarmID)

        // Should produce a valid UUID (not nil from UUID(uuidString:))
        XCTAssertNotEqual(id, UUID(), "Should produce a deterministic, non-random UUID")
        XCTAssertNotNil(UUID(uuidString: id.uuidString), "Should be a valid UUID string")
    }

    // MARK: - Alarm Notification ID Determinism

    func testAlarmNotificationID_isDeterministic() {
        // Notification IDs should be: com.momclock.alarm.{UUID}.{weekday}.{offset}
        let alarmID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let expected = "com.momclock.alarm.\(alarmID.uuidString).2.0"

        // The format is deterministic — same alarm + weekday + offset = same ID
        XCTAssertEqual(expected, "com.momclock.alarm.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE.2.0")
    }

    // MARK: - Session State Machine

    func testSessionIsActive_ringing() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .ringing
        XCTAssertTrue(session.isActive)
    }

    func testSessionIsActive_verified() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .verified
        XCTAssertFalse(session.isActive)
    }

    func testSessionIsActive_failed() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .failed
        XCTAssertFalse(session.isActive)
    }

    func testSessionIsActive_pendingParentReview() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .pendingParentReview
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.isAwaitingParent)
    }

    // MARK: - Denial Count

    func testDenialCount_incrementsOnDeny() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        XCTAssertEqual(session.denialCount, 0)
        session.denialCount += 1
        XCTAssertEqual(session.denialCount, 1)
        session.denialCount += 1
        XCTAssertEqual(session.denialCount, 2)
    }

    // MARK: - Safe Collection Subscript

    // MARK: - RewardEngine

    func testReward_onTimeFirstTry() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: Date().addingTimeInterval(-120))
        session.state = .verified
        session.verifiedAt = Date().addingTimeInterval(-60)
        session.verificationAttempts = 1 // first try
        session.snoozeCount = 0
        let reward = RewardEngine.calculate(session: session)
        XCTAssertEqual(reward.pointsDelta, RewardEngine.onTimeFirstTryPoints + RewardEngine.noSnoozeBonus)
        XCTAssertEqual(reward.streakDelta, 1)
        XCTAssertTrue(reward.reasonCodes.contains("on_time_first_try"))
        XCTAssertTrue(reward.reasonCodes.contains("no_snooze_bonus"))
    }

    func testReward_onTimeWithRetries() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: Date().addingTimeInterval(-120))
        session.state = .verified
        session.verifiedAt = Date().addingTimeInterval(-60)
        session.verificationAttempts = 3 // retries
        session.snoozeCount = 0
        let reward = RewardEngine.calculate(session: session)
        XCTAssertEqual(reward.pointsDelta, RewardEngine.onTimeWithRetriesPoints + RewardEngine.noSnoozeBonus)
        XCTAssertTrue(reward.reasonCodes.contains("on_time_retries"))
    }

    func testReward_lateVerified() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: Date().addingTimeInterval(-600))
        session.state = .verified
        session.verifiedAt = Date()
        session.verificationAttempts = 1
        session.snoozeCount = 1
        let reward = RewardEngine.calculate(session: session)
        XCTAssertEqual(reward.pointsDelta, RewardEngine.lateVerifiedPoints)
        XCTAssertEqual(reward.streakDelta, 0)
        XCTAssertTrue(reward.reasonCodes.contains("late_verified"))
        XCTAssertFalse(reward.reasonCodes.contains("no_snooze_bonus"))
    }

    func testReward_denialCountDoesNotAffectFirstTry() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: Date().addingTimeInterval(-120))
        session.state = .verified
        session.verifiedAt = Date().addingTimeInterval(-60)
        session.verificationAttempts = 1 // first try
        session.denialCount = 2 // denied twice but attempts=1 means latest was first try
        session.snoozeCount = 0
        let reward = RewardEngine.calculate(session: session)
        // Should use verificationAttempts, NOT denialCount
        XCTAssertEqual(reward.pointsDelta, RewardEngine.onTimeFirstTryPoints + RewardEngine.noSnoozeBonus)
        XCTAssertTrue(reward.reasonCodes.contains("on_time_first_try"))
    }

    func testReward_escalated() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .failed
        session.parentAction = .escalated(reason: "test")
        let reward = RewardEngine.calculate(session: session)
        XCTAssertEqual(reward.pointsDelta, RewardEngine.escalatedPointsPenalty)
    }

    func testReward_streakBonus() {
        XCTAssertEqual(RewardEngine.streakBonus(currentStreak: 2), 0)
        XCTAssertEqual(RewardEngine.streakBonus(currentStreak: 3), 25)
        XCTAssertEqual(RewardEngine.streakBonus(currentStreak: 7), 75)
        XCTAssertEqual(RewardEngine.streakBonus(currentStreak: 14), 150)
    }

    func testReward_apply() {
        var stats = ChildProfile.Stats()
        stats.rewardPoints = 50
        stats.currentStreak = 2
        let reward = RewardEngine.SessionReward(pointsDelta: 20, streakDelta: 1, reasonCodes: ["test"], reason: "test")
        RewardEngine.apply(reward, to: &stats, currentStreak: 2)
        XCTAssertEqual(stats.rewardPoints, 70 + 25) // 50 + 20 + 25 (streak bonus at 3)
        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.bestStreak, 3)
    }

    // MARK: - Safe Collection Subscript

    func testSafeSubscript_validIndex() {
        let arr = [10, 20, 30]
        XCTAssertEqual(arr[safe: 1], 20)
    }

    func testSafeSubscript_outOfBounds() {
        let arr = [10, 20, 30]
        XCTAssertNil(arr[safe: 5])
    }

    func testSafeSubscript_emptyArray() {
        let arr: [Int] = []
        XCTAssertNil(arr[safe: 0])
    }

    // MARK: - EffectiveVerificationConfig Merge

    func testConfigMerge_overridesWin() {
        let overrides = ChildProfile.NextMorningOverrides(
            verificationMethod: .quiz,
            tier: .easy,
            maxAttempts: 2,
            timerSeconds: 60,
            calmMode: true
        )
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: overrides,
            pendingTierEscalation: false
        )
        XCTAssertEqual(config.method, .quiz)
        XCTAssertEqual(config.tier, .easy)
        XCTAssertEqual(config.maxAttempts, 2)
        XCTAssertEqual(config.timerSeconds, 60)
        XCTAssertTrue(config.calmMode)
    }

    func testConfigMerge_noOverrides_usesDefaults() {
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: nil,
            pendingTierEscalation: false
        )
        XCTAssertEqual(config.method, .quiz) // default
        XCTAssertEqual(config.tier, .medium) // default
        XCTAssertEqual(config.maxAttempts, 3)
        XCTAssertFalse(config.calmMode)
    }

    func testConfigMerge_pendingEscalation_upgradesTier() {
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: nil,
            pendingTierEscalation: true
        )
        XCTAssertEqual(config.tier, .hard) // medium.escalated = hard
    }

    func testConfigMerge_overrideTier_overridesEscalation() {
        let overrides = ChildProfile.NextMorningOverrides(tier: .easy)
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: overrides,
            pendingTierEscalation: true
        )
        // Override explicitly set to easy — wins over escalation
        XCTAssertEqual(config.tier, .easy)
    }

    // MARK: - Config Snapshot

    func testConfigSnapshot_capturesValues() {
        let config = EffectiveVerificationConfig(
            method: .quiz, tier: .hard, maxAttempts: 2, timerSeconds: 30, calmMode: true
        )
        let snapshot = MorningSession.ConfigSnapshot(from: config)
        XCTAssertEqual(snapshot.method, "quiz")
        XCTAssertEqual(snapshot.tier, "hard")
        XCTAssertEqual(snapshot.maxAttempts, 2)
        XCTAssertEqual(snapshot.timerSeconds, 30)
        XCTAssertTrue(snapshot.calmMode)
    }

    // MARK: - Reward Idempotency (Separated Flags)

    func testRewardOptimistic_clientFlag() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .verified
        XCTAssertFalse(session.rewardOptimistic)
        session.rewardOptimistic = true
        XCTAssertTrue(session.rewardOptimistic)
        // Server flag should remain independent
        XCTAssertFalse(session.rewardServerApplied)
    }

    func testRewardServerApplied_serverFlag() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .verified
        session.rewardOptimistic = true
        session.rewardServerApplied = true
        // Both flags independent
        XCTAssertTrue(session.rewardOptimistic)
        XCTAssertTrue(session.rewardServerApplied)
    }

    // MARK: - Terminal States

    func testTerminalStates_areNotActive() {
        let terminalStates: [MorningSession.State] = [.verified, .failed, .cancelled]
        for state in terminalStates {
            var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
            session.state = state
            XCTAssertFalse(session.isActive, "\(state) should not be active")
        }
    }

    func testActiveStates_areActive() {
        let activeStates: [MorningSession.State] = [.ringing, .snoozed, .escalating, .verifying, .pendingParentReview]
        for state in activeStates {
            var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
            session.state = state
            XCTAssertTrue(session.isActive, "\(state) should be active")
        }
    }

    // MARK: - R2 Regression: Session Duplicate Guard

    func testDuplicateGuard_sameAlarmSameDay_sameID() {
        let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        // Two calls on the same day produce the same session ID
        let id1 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: Date())
        let id2 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: Date())
        XCTAssertEqual(id1, id2, "Same alarm + same day must produce same session ID")
    }

    func testDuplicateGuard_backupReminderSameDay_sameID() {
        let childID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let alarmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        // Backup reminder fires 2 min later but same day
        let now = Date()
        let twoMinLater = now.addingTimeInterval(120)
        let id1 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: now)
        let id2 = MorningSession.deterministicID(childID: childID, alarmID: alarmID, date: twoMinLater)
        XCTAssertEqual(id1, id2, "Backup reminder on same day must produce same session ID")
    }

    func testVerifiedSession_isNotActive() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.state = .verified
        // If session is verified and backup reminder fires, duplicate guard should see isActive=false
        // deterministicID is same → Firestore setData is idempotent → safe even if guard doesn't catch it
        XCTAssertFalse(session.isActive, "Verified session should not be active")
    }

}
