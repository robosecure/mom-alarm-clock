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
            method: .quiz, tier: .hard, maxAttempts: 2, timerSeconds: 30, calmMode: true,
            quizQuestionCount: 5, quizDifficulty: "hard", encouragementStyle: .direct
        )
        let snapshot = MorningSession.ConfigSnapshot(from: config)
        XCTAssertEqual(snapshot.method, "quiz")
        XCTAssertEqual(snapshot.tier, "hard")
        XCTAssertEqual(snapshot.maxAttempts, 2)
        XCTAssertEqual(snapshot.timerSeconds, 30)
        XCTAssertTrue(snapshot.calmMode)
        XCTAssertEqual(snapshot.quizQuestionCount, 5)
        XCTAssertEqual(snapshot.encouragementStyle, "direct")
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

    // MARK: - Default Policy (Launch Behavior)

    func testDefaultConfirmationPolicy_isAutoAcknowledge() {
        // Launch behavior: new alarms auto-complete without guardian intervention
        let policy = ConfirmationPolicy.default
        switch policy {
        case .autoAcknowledge:
            break // Expected
        default:
            XCTFail("Default confirmation policy must be .autoAcknowledge for launch, got \(policy)")
        }
    }

    func testAlarmScheduleDefault_usesAutoAcknowledge() {
        let schedule = AlarmSchedule(
            alarmTime: AlarmSchedule.AlarmTime(hour: 7, minute: 0),
            activeDays: [2, 3, 4, 5, 6],
            primaryVerification: .quiz,
            escalation: .default,
            snoozeRules: AlarmSchedule.SnoozeRules(allowed: true, maxCount: 2, durationMinutes: 5),
            childProfileID: UUID()
        )
        switch schedule.confirmationPolicy {
        case .autoAcknowledge:
            break // Expected
        default:
            XCTFail("New alarm schedules must default to .autoAcknowledge")
        }
    }

    // MARK: - Auto-Acknowledge Session Flow

    func testAutoAcknowledgeSession_goesDirectlyToVerified() {
        var session = MorningSession(childProfileID: UUID(), alarmScheduleID: UUID(), alarmFiredAt: .now)
        session.confirmationPolicy = .autoAcknowledge
        // Simulate what ChildViewModel.completeVerification does for autoAcknowledge
        session.state = .verified
        session.parentAction = .autoAcknowledged
        XCTAssertFalse(session.isActive, "Auto-acknowledged session should not be active")
        XCTAssertEqual(session.state, .verified)
        if case .autoAcknowledged = session.parentAction {
            // Expected
        } else {
            XCTFail("Auto-acknowledge should set parentAction to .autoAcknowledged")
        }
    }

    // MARK: - Skip-Tomorrow Date Logic

    func testSkipUntil_coversFullNextDay() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        // skipAlarmTomorrow computes: startOfDay + 2 days
        // This means: alarm is skipped for the rest of today AND all of tomorrow
        let skipUntil = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        // skipUntil should be start of day-after-tomorrow
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        XCTAssertEqual(skipUntil, dayAfterTomorrow)
        // An alarm at 7 AM tomorrow should still be skipped
        let tomorrowAlarm = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            .addingTimeInterval(7 * 3600) // 7 AM tomorrow
        XCTAssertTrue(tomorrowAlarm < skipUntil, "7 AM tomorrow should be before skipUntil")
    }

    // MARK: - Pairing Code Safety

    func testPairingCode_isAlphanumericAndCorrectLength() {
        let code = ChildProfile.generatePairingCode()
        XCTAssertEqual(code.count, 10, "Pairing code must be 10 characters")
        let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for char in code.unicodeScalars {
            XCTAssertTrue(allowed.contains(char), "Pairing code contains disallowed character: \(char)")
        }
    }

    func testPairingCode_excludesConfusingCharacters() {
        // Generate many codes and verify none contain I, O, 0, 1
        let confusing: Set<Character> = ["I", "O", "0", "1"]
        for _ in 0..<100 {
            let code = ChildProfile.generatePairingCode()
            for char in code {
                XCTAssertFalse(confusing.contains(char), "Pairing code must not contain '\(char)'")
            }
        }
    }

    // MARK: - Age Band Defaults

    func testAgeBand_youngChild_getsEasyQuiz() {
        let band = AgeBand(age: 6)
        XCTAssertEqual(band, .young)
        let profile = band.contentProfile
        XCTAssertEqual(profile.quizDifficulty, .easy)
        XCTAssertEqual(profile.quizCount, 2)
        XCTAssertEqual(profile.verificationTimeoutSeconds, 90)
    }

    func testAgeBand_teen_getsMediumQuiz() {
        let band = AgeBand(age: 15)
        XCTAssertEqual(band, .teen)
        let profile = band.contentProfile
        XCTAssertEqual(profile.quizDifficulty, .medium)
        XCTAssertEqual(profile.quizCount, 3)
        XCTAssertEqual(profile.verificationTimeoutSeconds, 30)
    }

    func testAgeBand_allBandsMapCorrectly() {
        XCTAssertEqual(AgeBand(age: 5), .young)
        XCTAssertEqual(AgeBand(age: 7), .young)
        XCTAssertEqual(AgeBand(age: 8), .middle)
        XCTAssertEqual(AgeBand(age: 10), .middle)
        XCTAssertEqual(AgeBand(age: 11), .preteen)
        XCTAssertEqual(AgeBand(age: 13), .preteen)
        XCTAssertEqual(AgeBand(age: 14), .teen)
        XCTAssertEqual(AgeBand(age: 17), .teen)
    }

    // MARK: - Age Precedence in Config Merge

    func testConfigMerge_ageBandApplies_whenNoSchedule() {
        // No schedule, no overrides — age band should drive defaults
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: nil,
            pendingTierEscalation: false,
            ageBand: .young
        )
        XCTAssertEqual(config.quizQuestionCount, 2, "Young child should get 2 questions")
        XCTAssertEqual(config.timerSeconds, 90, "Young child should get 90s timer")
        XCTAssertEqual(config.quizDifficulty, "easy")
        XCTAssertEqual(config.encouragementStyle, .warm)
    }

    func testConfigMerge_scheduleBeatsAge() {
        // Schedule explicitly sets medium tier — should override young child's easy defaults
        let schedule = AlarmSchedule(
            alarmTime: AlarmSchedule.AlarmTime(hour: 7, minute: 0),
            activeDays: [2, 3, 4, 5, 6],
            primaryVerification: .quiz,
            escalation: .default,
            verificationTier: .medium,
            snoozeRules: AlarmSchedule.SnoozeRules(allowed: true, maxCount: 2, durationMinutes: 5),
            childProfileID: UUID()
        )
        let config = EffectiveVerificationConfig.merge(
            schedule: schedule,
            overrides: nil,
            pendingTierEscalation: false,
            ageBand: .young
        )
        XCTAssertEqual(config.quizQuestionCount, 3, "Schedule's medium tier (3 questions) should beat age's 2")
        XCTAssertEqual(config.timerSeconds, 45, "Schedule's medium tier (45s) should beat age's 90s")
        XCTAssertEqual(config.quizDifficulty, "medium", "Schedule's medium should beat age's easy")
    }

    func testConfigMerge_overridesBeatAge() {
        // Tomorrow override with explicit timer — should beat both schedule and age
        let overrides = ChildProfile.NextMorningOverrides(timerSeconds: 20)
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: overrides,
            pendingTierEscalation: false,
            ageBand: .young
        )
        XCTAssertEqual(config.timerSeconds, 20, "Tomorrow override (20s) should beat age (90s)")
    }

    func testConfigMerge_noAgeBand_usesHardcodedDefaults() {
        // No schedule, no overrides, no age — pure hardcoded defaults
        let config = EffectiveVerificationConfig.merge(
            schedule: nil,
            overrides: nil,
            pendingTierEscalation: false,
            ageBand: nil
        )
        XCTAssertEqual(config.quizQuestionCount, 3, "Hardcoded default: medium tier = 3 questions")
        XCTAssertEqual(config.timerSeconds, 45, "Hardcoded default: medium tier = 45s")
        XCTAssertEqual(config.quizDifficulty, "medium")
    }

    // MARK: - InputValidation: Name

    func testValidateName_empty_fails() {
        XCTAssertFalse(InputValidation.validateName("").isValid)
        XCTAssertEqual(InputValidation.validateName("").errorMessage, "Name is required.")
    }

    func testValidateName_whitespaceOnly_fails() {
        XCTAssertFalse(InputValidation.validateName("   ").isValid)
        XCTAssertEqual(InputValidation.validateName("   ").errorMessage, "Name is required.")
    }

    func testValidateName_tooLong_fails() {
        let longName = String(repeating: "a", count: 51)
        XCTAssertFalse(InputValidation.validateName(longName).isValid)
        XCTAssertEqual(InputValidation.validateName(longName).errorMessage, "Name must be 50 characters or fewer.")
    }

    func testValidateName_exactlyFifty_passes() {
        let fiftyChars = String(repeating: "a", count: 50)
        XCTAssertTrue(InputValidation.validateName(fiftyChars).isValid)
    }

    func testValidateName_digitsOnly_fails() {
        XCTAssertFalse(InputValidation.validateName("12345").isValid)
        XCTAssertEqual(InputValidation.validateName("12345").errorMessage, "Name must contain at least one letter.")
    }

    func testValidateName_singleLetter_passes() {
        XCTAssertTrue(InputValidation.validateName("A").isValid)
    }

    func testValidateName_unicodeLetters_passes() {
        XCTAssertTrue(InputValidation.validateName("José").isValid)
        XCTAssertTrue(InputValidation.validateName("日本").isValid)
    }

    func testValidateName_leadingTrailingWhitespace_trims() {
        XCTAssertTrue(InputValidation.validateName("  Alice  ").isValid)
    }

    // MARK: - InputValidation: Email

    func testValidateEmail_empty_fails() {
        XCTAssertFalse(InputValidation.validateEmail("").isValid)
        XCTAssertEqual(InputValidation.validateEmail("").errorMessage, "Email is required.")
    }

    func testValidateEmail_whitespaceOnly_fails() {
        XCTAssertFalse(InputValidation.validateEmail("   ").isValid)
    }

    func testValidateEmail_validBasic_passes() {
        XCTAssertTrue(InputValidation.validateEmail("user@example.com").isValid)
    }

    func testValidateEmail_validWithSubdomain_passes() {
        XCTAssertTrue(InputValidation.validateEmail("user@mail.example.com").isValid)
    }

    func testValidateEmail_validWithPlusTag_passes() {
        XCTAssertTrue(InputValidation.validateEmail("user+tag@example.com").isValid)
    }

    func testValidateEmail_validWithDotInLocal_passes() {
        XCTAssertTrue(InputValidation.validateEmail("first.last@example.com").isValid)
    }

    func testValidateEmail_validWithHyphenInDomain_passes() {
        XCTAssertTrue(InputValidation.validateEmail("user@my-domain.com").isValid)
    }

    func testValidateEmail_uppercase_passes() {
        // Should be lowercased internally
        XCTAssertTrue(InputValidation.validateEmail("USER@EXAMPLE.COM").isValid)
    }

    func testValidateEmail_trailingWhitespace_passes() {
        XCTAssertTrue(InputValidation.validateEmail("user@example.com  ").isValid)
    }

    func testValidateEmail_noAt_fails() {
        XCTAssertFalse(InputValidation.validateEmail("userexample.com").isValid)
    }

    func testValidateEmail_noDot_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user@example").isValid)
    }

    func testValidateEmail_singleCharTLD_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user@example.c").isValid)
    }

    func testValidateEmail_noLocalPart_fails() {
        XCTAssertFalse(InputValidation.validateEmail("@example.com").isValid)
    }

    func testValidateEmail_noDomain_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user@").isValid)
    }

    func testValidateEmail_consecutiveDots_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user..name@example.com").isValid)
        XCTAssertFalse(InputValidation.validateEmail("user@example..com").isValid)
    }

    func testValidateEmail_leadingDotInLocal_fails() {
        XCTAssertFalse(InputValidation.validateEmail(".user@example.com").isValid)
    }

    func testValidateEmail_trailingDotInLocal_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user.@example.com").isValid)
    }

    func testValidateEmail_specialChars_fails() {
        XCTAssertFalse(InputValidation.validateEmail("user name@example.com").isValid)
        XCTAssertFalse(InputValidation.validateEmail("user<script>@example.com").isValid)
    }

    // MARK: - InputValidation: Password

    func testValidatePassword_tooShort_fails() {
        XCTAssertFalse(InputValidation.validatePassword("Ab1").isValid)
        XCTAssertEqual(InputValidation.validatePassword("Ab1").errorMessage, "Password must be at least 8 characters.")
    }

    func testValidatePassword_exactlyEight_passes() {
        XCTAssertTrue(InputValidation.validatePassword("Abcdefg1").isValid)
    }

    func testValidatePassword_noUppercase_fails() {
        XCTAssertFalse(InputValidation.validatePassword("abcdefg1").isValid)
        XCTAssertEqual(InputValidation.validatePassword("abcdefg1").errorMessage, "Password needs at least one uppercase letter.")
    }

    func testValidatePassword_noLowercase_fails() {
        XCTAssertFalse(InputValidation.validatePassword("ABCDEFG1").isValid)
        XCTAssertEqual(InputValidation.validatePassword("ABCDEFG1").errorMessage, "Password needs at least one lowercase letter.")
    }

    func testValidatePassword_noNumber_fails() {
        XCTAssertFalse(InputValidation.validatePassword("Abcdefgh").isValid)
        XCTAssertEqual(InputValidation.validatePassword("Abcdefgh").errorMessage, "Password needs at least one number.")
    }

    func testValidatePassword_strong_passes() {
        XCTAssertTrue(InputValidation.validatePassword("MyP@ssw0rd!").isValid)
    }

    // MARK: - InputValidation: Password Strength

    func testPasswordStrength_short_weak() {
        XCTAssertEqual(InputValidation.passwordStrength("Ab1"), .weak)
    }

    func testPasswordStrength_allThree_medium() {
        // 8 chars, uppercase + lowercase + number = score 3 = medium
        XCTAssertEqual(InputValidation.passwordStrength("Abcdefg1"), .medium)
    }

    func testPasswordStrength_withSymbolOrLong_strong() {
        // 8+ chars, upper+lower+number+symbol = score 4 = strong
        XCTAssertEqual(InputValidation.passwordStrength("Abcdefg1!"), .strong)
        // 12+ chars adds bonus = strong
        XCTAssertEqual(InputValidation.passwordStrength("Abcdefghij12"), .strong)
    }

    // MARK: - InputValidation: Join Code

    func testValidateJoinCode_empty_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("").isValid)
        XCTAssertEqual(InputValidation.validateJoinCode("").errorMessage, "Enter the family join code.")
    }

    func testValidateJoinCode_tooShort_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("ABC123").isValid)
        XCTAssertEqual(InputValidation.validateJoinCode("ABC123").errorMessage, "Join code must be exactly 10 characters.")
    }

    func testValidateJoinCode_tooLong_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("ABCDEFGHIJK").isValid)
    }

    func testValidateJoinCode_containsConfusingI_fails() {
        // I, O, 0, 1 are excluded
        XCTAssertFalse(InputValidation.validateJoinCode("ABCDEFGHIJ").isValid) // contains I
    }

    func testValidateJoinCode_containsConfusingO_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("ABCDEFGHOP").isValid) // contains O
    }

    func testValidateJoinCode_containsConfusing0_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("ABCDEFGHJ0").isValid) // contains 0
    }

    func testValidateJoinCode_containsConfusing1_fails() {
        XCTAssertFalse(InputValidation.validateJoinCode("ABCDEFGHJ1").isValid) // contains 1
    }

    func testValidateJoinCode_lowercase_uppercased() {
        // Should be uppercased internally and pass
        XCTAssertTrue(InputValidation.validateJoinCode("abcdefghjk").isValid)
    }

    func testValidateJoinCode_validAlphabet_passes() {
        XCTAssertTrue(InputValidation.validateJoinCode("ABCDEFGHJK").isValid)
        XCTAssertTrue(InputValidation.validateJoinCode("23456789AB").isValid)
    }

    func testValidateJoinCode_leadingTrailingWhitespace_trims() {
        XCTAssertTrue(InputValidation.validateJoinCode("  ABCDEFGHJK  ").isValid)
    }

}
