import Foundation
import SwiftUI

/// Primary view model for the child-mode UI.
/// Manages alarm state, verification flow, two-way confirmation, and escalation.
@Observable
final class ChildViewModel {
    // MARK: - Dependencies

    private let syncService: any SyncService
    private let localStore = LocalStore.shared

    init(syncService: any SyncService) {
        self.syncService = syncService
    }

    // MARK: - State

    var profile: ChildProfile?
    var alarmSchedules: [AlarmSchedule] = []
    var activeSession: MorningSession?
    var currentVerificationMethod: VerificationMethod?
    var isDeviceLocked: Bool = false
    var errorMessage: String?
    var familyID: String?

    // Verification state
    var motionProgress: VerificationService.MotionProgress?
    var quizQuestions: [VerificationService.QuizQuestion] = []
    var quizCurrentIndex: Int = 0
    var quizCorrectCount: Int = 0
    var quizStartTime: Date?
    var geofenceResult: VerificationService.GeofenceResult?

    // Two-way confirmation state
    var isAwaitingParentReview: Bool = false

    /// Set when an offline write was rejected and the session was refreshed from server.
    var syncConflictMessage: String?

    /// Persistent connectivity status banner (nil = all good).
    var connectivityBanner: String?

    /// Merged verification config for the current session (overrides + schedule defaults).
    var effectiveConfig: EffectiveVerificationConfig?

    // MARK: - Computed

    var nextAlarm: AlarmSchedule? {
        alarmSchedules
            .filter(\.isEffectivelyEnabled)
            .sorted { a, b in
                let aNext = a.alarmTime.nextOccurrence() ?? .distantFuture
                let bNext = b.alarmTime.nextOccurrence() ?? .distantFuture
                return aNext < bNext
            }
            .first
    }

    /// The effective verification tier, considering tamper escalation.
    var effectiveVerificationTier: VerificationTier {
        guard let schedule = activeSession.flatMap({ s in alarmSchedules.first { $0.id == s.alarmScheduleID } }) else {
            return .medium
        }
        return profile?.effectiveVerificationTier(base: schedule.verificationTier) ?? schedule.verificationTier
    }

    var currentEscalationLevel: EscalationProfile.Level? {
        guard let session = activeSession else { return nil }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }
        return schedule?.escalation.currentLevel(minutesSinceAlarm: session.minutesSinceAlarm)
    }

    var nextEscalationLevel: EscalationProfile.Level? {
        guard let session = activeSession else { return nil }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }
        return schedule?.escalation.nextLevel(minutesSinceAlarm: session.minutesSinceAlarm)
    }

    var timeUntilNextEscalation: TimeInterval? {
        guard let session = activeSession, let next = nextEscalationLevel else { return nil }
        let escalationDate = session.alarmFiredAt.addingTimeInterval(Double(next.minutesAfterAlarm) * 60)
        let remaining = escalationDate.timeIntervalSince(.now)
        return remaining > 0 ? remaining : nil
    }

    // MARK: - Setup

    func loadData() async {
        guard let authState = await localStore.authState() else {
            errorMessage = "No child profile configured. Please pair with a guardian's device."
            return
        }
        familyID = authState.familyID

        do {
            let profiles = try await syncService.fetchChildProfiles(familyID: authState.familyID)
            // Find this child's profile (matched by userID stored in auth)
            profile = profiles.first

            if let childID = profile?.id {
                alarmSchedules = try await syncService.fetchAlarmSchedules(familyID: authState.familyID, childID: childID)

                // Persist locally for offline alarm firing
                try await localStore.saveAlarmSchedules(alarmSchedules)

                // Schedule local notifications for all active alarms
                for schedule in alarmSchedules where schedule.isEffectivelyEnabled {
                    try await AlarmService.shared.scheduleAlarm(schedule)
                }

                // Sync voice alarm cache
                await VoiceAlarmCacheService.shared.syncIfNeeded(
                    childID: childID,
                    metadata: profile?.voiceAlarm
                )
            }
        } catch {
            // Fall back to locally cached schedules
            alarmSchedules = await localStore.alarmSchedules()
            if alarmSchedules.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Observes real-time alarm schedule changes from the parent.
    func observeAlarmChanges() async {
        guard let familyID, let childID = profile?.id else { return }
        for await schedules in syncService.observeAlarmSchedules(familyID: familyID, childID: childID) {
            alarmSchedules = schedules
            try? await localStore.saveAlarmSchedules(schedules)
            // Reschedule local notifications
            for schedule in schedules where schedule.isEffectivelyEnabled {
                try? await AlarmService.shared.scheduleAlarm(schedule)
            }
        }
    }

    // MARK: - Alarm Actions

    func alarmDidFire(scheduleID: UUID) async {
        guard let profile, let familyID else { return }

        // Deterministic session ID prevents duplicates from foreground + tap + backup
        let sessionID = MorningSession.deterministicID(childID: profile.id, alarmID: scheduleID)

        // Guard: if we already have an active session for this alarm today, don't create another
        if let existing = activeSession, existing.id == sessionID, existing.isActive {
            print("[Child] Session \(sessionID) already active — skipping duplicate alarmDidFire")
            return
        }

        let schedule = alarmSchedules.first { $0.id == scheduleID }

        var session = MorningSession(
            childProfileID: profile.id,
            alarmScheduleID: scheduleID,
            alarmFiredAt: Date(),
            confirmationPolicy: schedule?.confirmationPolicy ?? .default
        )
        session.id = sessionID
        activeSession = session
        try? await localStore.saveActiveSession(session)

        // Start tamper detection
        TamperDetectionService.shared.startMonitoring(childProfileID: profile.id)

        // Sync to backend
        do {
            try await syncService.saveSession(session, familyID: familyID)
        } catch {
            try? await localStore.appendToQueue(QueuedAction(
                actionType: .saveSession,
                payload: try JSONEncoder().encode(session)
            ))
        }

        await MainActor.run { BetaDiagnostics.shared.recordAlarmFired(source: "notification") }
        BetaDiagnostics.log(.sessionCreated)
        BetaDiagnostics.log(.alarmFired(
            method: schedule?.primaryVerification.rawValue ?? "unknown",
            tier: schedule?.verificationTier.rawValue ?? "medium"
        ))

        // Play voice alarm if cached (session creation happens first, then playback)
        await VoiceAlarmPlayerService.shared.playIfCached(childID: profile.id)

        startEscalationTimer()
    }

    func snooze() async {
        guard var session = activeSession, let familyID else { return }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }
        let rules = schedule?.snoozeRules ?? AlarmSchedule.SnoozeRules()

        guard rules.allowed, session.snoozeCount < rules.maxCount else { return }

        session.snoozeCount += 1
        session.state = .snoozed
        session.lastUpdated = Date()
        session.version += 1
        activeSession = session

        let duration = rules.duration(forSnooze: session.snoozeCount - 1)
        print("[Child] Snoozed for \(duration) minutes (snooze \(session.snoozeCount)/\(rules.maxCount))")

        try? await syncService.saveSession(session, familyID: familyID)
    }

    // MARK: - Verification

    func beginVerification() async {
        guard var session = activeSession else { return }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }

        // Merge schedule defaults + guardian overrides into effective config
        let config = EffectiveVerificationConfig.merge(
            schedule: schedule,
            overrides: profile?.nextMorningOverrides,
            pendingTierEscalation: profile?.pendingTierEscalation ?? false
        )
        effectiveConfig = config

        // Escalation level can override the method
        let method = currentEscalationLevel?.requiredVerification?.first ?? config.method

        session.state = .verifying
        session.effectiveConfigSnapshot = MorningSession.ConfigSnapshot(from: config)
        session.verificationAttempts += 1
        session.verificationStartedAt = Date()
        session.lastUpdated = Date()
        session.version += 1
        activeSession = session
        currentVerificationMethod = method

        switch method {
        case .motion:
            let steps = config.requiredSteps
            for await progress in await VerificationService.shared.startMotionTracking(requiredSteps: steps) {
                motionProgress = progress
                if progress.isComplete {
                    let result = VerificationResult(
                        method: .motion,
                        completedAt: Date(),
                        tier: config.tier,
                        passed: true,
                        stepCount: progress.currentSteps,
                        deviceTimestamp: Date()
                    )
                    await completeVerification(method: .motion, result: result)
                    break
                }
            }
        case .quiz:
            quizQuestions = await VerificationService.shared.generateQuiz(
                difficulty: VerificationService.QuizDifficulty(rawValue: config.quizDifficulty) ?? .medium,
                count: config.quizQuestionCount
            )
            quizCurrentIndex = 0
            quizCorrectCount = 0
            quizStartTime = Date()
        case .qr, .photo, .geofence:
            break // Handled by respective views
        }
    }

    /// Two-way confirmation: after verification, session state depends on confirmation policy.
    func completeVerification(method: VerificationMethod, result: VerificationResult) async {
        guard var session = activeSession, let familyID else { return }

        session.verifiedAt = Date()
        session.verifiedWith = method
        session.verificationResult = result
        // Record verification duration for reward calculation
        if let startedAt = session.verificationStartedAt {
            session.verificationDurationSeconds = Int(Date().timeIntervalSince(startedAt))
        }
        session.rewardRubricVersion = RewardEngine.rubricVersion
        await MainActor.run { BetaDiagnostics.shared.recordVerification(method: method.rawValue, passed: result.passed) }
        BetaDiagnostics.log(.verificationSubmitted(
            method: method.rawValue,
            tier: effectiveVerificationTier.rawValue,
            passed: result.passed
        ))
        let detectedEvents = TamperDetectionService.shared.detectedEvents
        session.tamperCount = detectedEvents.count
        session.lastTamperType = detectedEvents.last?.type.rawValue
        session.lastUpdated = Date()
        session.version += 1

        // Apply confirmation policy
        let requiresParentReview = method.alwaysRequiresParentReview

        switch session.confirmationPolicy {
        case .autoAcknowledge where !requiresParentReview:
            session.state = .verified
            session.parentAction = .autoAcknowledged
            session.isDeviceLocked = false
            applyReward(session: &session)
            finishSession()

        case .requireParentApproval, _ where requiresParentReview:
            session.state = .pendingParentReview
            isAwaitingParentReview = true

        case .hybrid where !requiresParentReview:
            session.state = .verified
            session.parentAction = nil
            session.isDeviceLocked = false
            applyReward(session: &session)
            finishSession()

        default:
            session.state = .pendingParentReview
            isAwaitingParentReview = true
        }

        activeSession = session
        try? await localStore.saveActiveSession(session)

        do {
            try await syncService.saveSession(session, familyID: familyID)
        } catch {
            try? await localStore.appendToQueue(QueuedAction(
                actionType: .saveSession,
                payload: (try? JSONEncoder().encode(session)) ?? Data()
            ))
        }

        // If awaiting parent, observe for their action
        if isAwaitingParentReview {
            Task { await observeParentAction(sessionID: session.id) }
        }
    }

    /// Listens for parent's action on a pending session.
    func observeParentAction(sessionID: UUID) async {
        guard let familyID else { return }
        for await updatedSession in syncService.observeSession(familyID: familyID, sessionID: sessionID) {
            guard let updatedSession else { continue }
            if let action = updatedSession.parentAction {
                await MainActor.run {
                    activeSession = updatedSession
                    isAwaitingParentReview = false

                    switch action {
                    case .approved, .autoAcknowledged:
                        finishSession()

                    case .denied:
                        // Reset verification state so the child can re-verify.
                        // The session is already set to .verifying by the parent.
                        currentVerificationMethod = nil
                        motionProgress = nil
                        quizQuestions = []
                        quizCurrentIndex = 0
                        quizCorrectCount = 0
                        geofenceResult = nil

                    case .escalated:
                        // Session is failed — apply consequences locally
                        if var profile {
                            profile.pendingTierEscalation = true
                            self.profile = profile
                        }
                        finishSession()
                    }
                }
                break
            }
        }
    }

    /// Send a message to the parent (uses dedicated childMessage field).
    func sendMessageToParent(_ message: String) async {
        guard var session = activeSession, let familyID else { return }
        session.childMessage = message
        session.lastUpdated = Date()
        session.version += 1
        activeSession = session
        try? await syncService.saveSession(session, familyID: familyID)
    }

    // MARK: - Session Cleanup

    /// Applies reward points/streak optimistically to the local child profile.
    /// Server-authoritative reward is applied by Cloud Function (applyRewardOnVerified).
    /// Uses rewardOptimistic flag — never sets rewardServerApplied (server-only).
    private func applyReward(session: inout MorningSession) {
        guard !session.rewardOptimistic else { return }
        guard var profile else { return }
        let reward = RewardEngine.calculate(session: session)
        RewardEngine.apply(reward, to: &profile.stats, currentStreak: profile.stats.currentStreak)
        session.rewardOptimistic = true
        self.profile = profile
    }

    private func finishSession() {
        TamperDetectionService.shared.stopMonitoring()
        FamilyControlsService.shared.removeAllShields()
        Task { @MainActor in VoiceAlarmPlayerService.shared.stop() }
        isDeviceLocked = false
        escalationTimer?.invalidate()

        // Clear pending tier escalation after successful session
        if var profile {
            profile.pendingTierEscalation = false
            self.profile = profile
        }
    }

    // MARK: - Escalation

    private var escalationTimer: Timer?

    private func startEscalationTimer() {
        escalationTimer?.invalidate()
        escalationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkEscalation()
            }
        }
    }

    private func checkEscalation() async {
        guard var session = activeSession, session.isActive, let familyID else {
            escalationTimer?.invalidate()
            return
        }

        guard let level = currentEscalationLevel else { return }

        switch level.action {
        case .appLockPartial where !isDeviceLocked:
            FamilyControlsService.shared.applyPartialShield()
            isDeviceLocked = true
            session.isDeviceLocked = true
        case .appLockFull:
            FamilyControlsService.shared.applyFullShield()
            isDeviceLocked = true
            session.isDeviceLocked = true
        case .parentNotified:
            break // Sync handles notification
        default:
            break
        }

        session.currentEscalationStep = alarmSchedules
            .first { $0.id == session.alarmScheduleID }?
            .escalation.levels
            .firstIndex(where: { $0.id == level.id }) ?? 0
        session.lastUpdated = Date()
        session.version += 1
        activeSession = session

        try? await syncService.saveSession(session, familyID: familyID)
    }
}
