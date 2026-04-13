import Foundation
import SwiftUI

/// Primary view model for the child-mode UI.
/// Manages alarm state, verification flow, escalation progression, and parent messages.
@Observable
final class ChildViewModel {
    // MARK: - State

    var profile: ChildProfile?
    var alarmSchedules: [AlarmSchedule] = []
    var activeSession: MorningSession?
    var currentVerificationMethod: VerificationMethod?
    var parentMessage: String?
    var isDeviceLocked: Bool = false
    var errorMessage: String?

    // Verification state
    var motionProgress: VerificationService.MotionProgress?
    var quizQuestions: [VerificationService.QuizQuestion] = []
    var quizCurrentIndex: Int = 0
    var quizCorrectCount: Int = 0
    var geofenceResult: VerificationService.GeofenceResult?

    // MARK: - Computed

    var nextAlarm: AlarmSchedule? {
        alarmSchedules
            .filter(\.isEnabled)
            .sorted { a, b in
                let aNext = a.alarmTime.nextOccurrence() ?? .distantFuture
                let bNext = b.alarmTime.nextOccurrence() ?? .distantFuture
                return aNext < bNext
            }
            .first
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

    /// Loads the child profile and alarm schedules from CloudKit.
    /// Called after the child enters a pairing code during setup.
    func loadData() async {
        guard let idString = UserDefaults.standard.string(forKey: "childProfileID"),
              let id = UUID(uuidString: idString) else {
            errorMessage = "No child profile configured. Please pair with a parent device."
            return
        }

        do {
            let profiles = try await CloudSyncService.shared.fetchChildProfiles()
            profile = profiles.first { $0.id == id }
            alarmSchedules = try await CloudSyncService.shared.fetchAlarmSchedules(forChild: id)

            // Schedule local notifications for all active alarms
            for schedule in alarmSchedules where schedule.isEnabled {
                try await AlarmService.shared.scheduleAlarm(schedule)
            }

            // Subscribe to alarm changes from the parent
            try await CloudSyncService.shared.subscribeToAlarmChanges(forChild: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Alarm Actions

    /// Called when the alarm fires. Creates a new morning session.
    func alarmDidFire(scheduleID: UUID) async {
        guard let profile else { return }

        var session = MorningSession(
            childProfileID: profile.id,
            alarmScheduleID: scheduleID,
            alarmFiredAt: Date()
        )
        activeSession = session

        // Start tamper detection
        TamperDetectionService.shared.startMonitoring(childProfileID: profile.id)

        // Sync to CloudKit
        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
        } catch {
            print("[Child] Failed to sync session start: \(error)")
        }

        // Begin escalation timer
        startEscalationTimer()
    }

    /// Handles snooze action.
    func snooze() async {
        guard var session = activeSession else { return }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }
        let rules = schedule?.snoozeRules ?? AlarmSchedule.SnoozeRules()

        guard rules.allowed, session.snoozeCount < rules.maxCount else { return }

        session.snoozeCount += 1
        session.state = .snoozed
        session.lastUpdated = Date()
        activeSession = session

        // Schedule the next ring
        let duration = rules.duration(forSnooze: session.snoozeCount - 1)
        // In a real implementation, schedule a local notification for `duration` minutes from now.
        print("[Child] Snoozed for \(duration) minutes (snooze \(session.snoozeCount)/\(rules.maxCount))")

        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
        } catch {
            print("[Child] Failed to sync snooze: \(error)")
        }
    }

    /// Starts the verification flow with the required method.
    func beginVerification() async {
        guard var session = activeSession else { return }
        let schedule = alarmSchedules.first { $0.id == session.alarmScheduleID }
        let method = currentEscalationLevel?.requiredVerification?.first ?? schedule?.primaryVerification ?? .motion

        session.state = .verifying
        session.lastUpdated = Date()
        activeSession = session
        currentVerificationMethod = method

        // Prepare verification-specific state
        switch method {
        case .motion:
            for await progress in await VerificationService.shared.startMotionTracking() {
                motionProgress = progress
                if progress.isComplete {
                    await completeVerification(method: .motion)
                    break
                }
            }
        case .quiz:
            quizQuestions = await VerificationService.shared.generateQuiz()
            quizCurrentIndex = 0
            quizCorrectCount = 0
        case .qr, .photo, .geofence:
            break // These are handled by their respective views
        }
    }

    /// Called when verification is successfully completed.
    func completeVerification(method: VerificationMethod) async {
        guard var session = activeSession else { return }

        session.state = .verified
        session.verifiedAt = Date()
        session.verifiedWith = method
        session.isDeviceLocked = false
        session.lastUpdated = Date()
        session.tamperEvents = TamperDetectionService.shared.detectedEvents
        activeSession = session

        // Stop tamper detection and remove app shields
        TamperDetectionService.shared.stopMonitoring()
        FamilyControlsService.shared.removeAllShields()
        isDeviceLocked = false

        // Cancel remaining alarm notifications
        if let scheduleID = alarmSchedules.first(where: { $0.id == session.alarmScheduleID })?.id {
            await AlarmService.shared.cancelAlarm(scheduleID)
        }

        // Sync final state
        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
        } catch {
            print("[Child] Failed to sync verification: \(error)")
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
        guard var session = activeSession, session.isActive else {
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
            // CloudKit sync handles parent notification
            break
        default:
            break
        }

        session.currentEscalationStep = alarmSchedules
            .first { $0.id == session.alarmScheduleID }?
            .escalation.levels
            .firstIndex(where: { $0.id == level.id }) ?? 0
        session.lastUpdated = Date()
        activeSession = session

        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
        } catch {
            print("[Child] Failed to sync escalation: \(error)")
        }
    }
}
