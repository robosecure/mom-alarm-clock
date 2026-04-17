import Foundation
import SwiftUI

/// Primary view model for the parent-mode UI.
/// Manages children, alarms, two-way confirmation actions, and real-time session observation.
@MainActor
@Observable
final class ParentViewModel {
    // MARK: - Dependencies

    private let syncService: any SyncService

    init(syncService: any SyncService) {
        self.syncService = syncService
    }

    // MARK: - State

    var children: [ChildProfile] = []
    var selectedChildID: UUID?
    var alarmSchedules: [AlarmSchedule] = []
    var activeSessions: [MorningSession] = []
    var recentSessions: [MorningSession] = []
    var tamperEvents: [TamperEvent] = []
    var isLoading = false
    var errorMessage: String?
    var familyID: String?

    // MARK: - Computed

    var selectedChild: ChildProfile? {
        children.first { $0.id == selectedChildID }
    }

    var selectedChildSchedules: [AlarmSchedule] {
        guard let id = selectedChildID else { return [] }
        return alarmSchedules.filter { $0.childProfileID == id }
    }

    var selectedChildActiveSessions: [MorningSession] {
        guard let id = selectedChildID else { return [] }
        return activeSessions.filter { $0.childProfileID == id && $0.isActive }
    }

    /// Sessions awaiting parent review (two-way confirmation).
    var pendingReviewSessions: [MorningSession] {
        activeSessions.filter(\.isAwaitingParent)
    }

    /// Recomputed stats for the selected child.
    var selectedChildStats: ChildProfile.Stats? {
        guard selectedChildID != nil else { return nil }
        return StatsService.computeStats(sessions: recentSessions, tamperEvents: tamperEvents)
    }

    // MARK: - Data Loading

    func loadAllData() async {
        guard let authState = await LocalStore.shared.authState() else {
            errorMessage = "Not signed in."
            return
        }
        familyID = authState.familyID
        isLoading = true
        errorMessage = nil

        do {
            children = try await syncService.fetchChildProfiles(familyID: authState.familyID)
            if selectedChildID == nil {
                selectedChildID = children.first?.id
            }
            if let childID = selectedChildID {
                try await loadChildData(childID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadChildData(_ childID: UUID) async throws {
        guard let familyID else { return }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast

        async let schedules = syncService.fetchAlarmSchedules(familyID: familyID, childID: childID)
        async let sessions = syncService.fetchSessions(familyID: familyID, childID: childID, since: thirtyDaysAgo)
        async let tamper = syncService.fetchTamperEvents(familyID: familyID, childID: childID, since: thirtyDaysAgo)

        let (fetchedSchedules, fetchedSessions, fetchedTamper) = try await (schedules, sessions, tamper)
        alarmSchedules = fetchedSchedules
        recentSessions = fetchedSessions
        activeSessions = fetchedSessions.filter(\.isActive)
        tamperEvents = fetchedTamper
    }

    /// Real-time observation of active sessions for this family.
    func observeActiveSessions() async {
        guard let familyID, let childID = selectedChildID else { return }
        for await sessions in syncService.observeActiveSessions(familyID: familyID, childID: childID) {
            activeSessions = sessions
        }
    }

    // MARK: - Child Management

    func addChild(name: String, age: Int) async {
        guard let familyID else { return }
        var profile = ChildProfile(name: name, age: age)
        profile.pairingCode = ChildProfile.generatePairingCode()

        do {
            try await syncService.saveChildProfile(profile, familyID: familyID)
            children.append(profile)
            if selectedChildID == nil {
                selectedChildID = profile.id
            }
        } catch {
            errorMessage = "Failed to create child profile: \(error.localizedDescription)"
        }
    }

    /// Updates a child's name and age.
    func updateChildProfile(childID: UUID, name: String, age: Int) async {
        guard var child = children.first(where: { $0.id == childID }), let familyID else { return }
        child.name = name
        child.age = age
        do {
            try await syncService.saveChildProfile(child, familyID: familyID)
            if let idx = children.firstIndex(where: { $0.id == childID }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
        }
    }

    /// Updates the child's configurable reward list.
    func updateChildRewards(childID: UUID, rewards: [Reward]) async {
        guard var child = children.first(where: { $0.id == childID }), let familyID else { return }
        child.rewards = rewards
        do {
            try await syncService.saveChildProfile(child, familyID: familyID)
            if let idx = children.firstIndex(where: { $0.id == childID }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to save rewards: \(error.localizedDescription)"
        }
    }

    /// Removes a child profile. Guardian-only.
    /// NOTE: Firestore cascade delete is deferred — see DEFERRED.md [D-006].
    func removeChild(_ childID: UUID) async {
        guard familyID != nil else { return }
        // Remove from local state
        children.removeAll { $0.id == childID }
        if selectedChildID == childID {
            selectedChildID = children.first?.id
        }
        // Full Firestore cascade delete (alarms, sessions, tamperEvents) is deferred
        // to a server-side Cloud Function. See DEFERRED.md [D-006].
    }

    // MARK: - Alarm Management

    func saveAlarmSchedule(_ schedule: AlarmSchedule) async {
        guard let familyID else { return }
        do {
            try await syncService.saveAlarmSchedule(schedule, familyID: familyID)
            if let index = alarmSchedules.firstIndex(where: { $0.id == schedule.id }) {
                alarmSchedules[index] = schedule
            } else {
                alarmSchedules.append(schedule)
            }
        } catch {
            errorMessage = "Failed to save alarm: \(error.localizedDescription)"
        }
    }

    func deleteAlarmSchedule(_ scheduleID: UUID) async {
        guard let familyID else { return }
        do {
            try await syncService.deleteAlarmSchedule(scheduleID, familyID: familyID)
            alarmSchedules.removeAll { $0.id == scheduleID }
        } catch {
            errorMessage = "Failed to delete alarm: \(error.localizedDescription)"
        }
    }

    func toggleAlarm(_ scheduleID: UUID) async {
        guard var schedule = alarmSchedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.isEnabled.toggle()
        schedule.lastModified = Date()
        await saveAlarmSchedule(schedule)
    }

    // MARK: - Two-Way Confirmation Actions

    /// Parent approves a child's verification.
    /// Last reward outcome for diagnostics/receipts.
    var lastRewardOutcome: RewardEngine.SessionReward?

    func approveSession(_ sessionID: UUID) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }),
              let familyID else { return }

        session.parentAction = .approved
        session.parentActionAt = Date()
        session.state = .verified
        BetaDiagnostics.log(.parentAction(action: "approved"))
        session.isDeviceLocked = false
        session.lastUpdated = Date()
        session.version += 1

        // Calculate reward for optimistic UI — server Cloud Function is authoritative
        let reward = RewardEngine.calculate(session: session)
        lastRewardOutcome = reward
        session.rewardOptimistic = true
        // Do NOT set rewardServerApplied — only Cloud Function does that

        if var child = children.first(where: { $0.id == session.childProfileID }) {
            RewardEngine.apply(reward, to: &child.stats, currentStreak: child.stats.currentStreak)
            do {
                try await syncService.escalateSessionAndProfile(session: session, profile: child, familyID: familyID)
                if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                    activeSessions[idx] = session
                }
                if let idx = children.firstIndex(where: { $0.id == child.id }) {
                    children[idx] = child
                }
            } catch {
                errorMessage = "Failed to approve session: \(error.localizedDescription)"
            }
        } else {
            // No child profile found — just save session
            do {
                try await syncService.saveSession(session, familyID: familyID)
                if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                    activeSessions[idx] = session
                }
            } catch {
                errorMessage = "Failed to approve session: \(error.localizedDescription)"
            }
        }
    }

    /// Parent denies a child's verification (child must re-verify).
    /// Clears the previous verification result and sets state back to verifying.
    func denySession(_ sessionID: UUID, reason: String) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }),
              let familyID else { return }

        session.parentAction = .denied(reason: reason)
        session.parentActionAt = Date()
        session.state = .verifying // Back to verifying — child must try again
        session.denialCount += 1
        BetaDiagnostics.log(.parentAction(action: "denied"))
        session.verificationResult = nil
        session.verifiedAt = nil
        session.verifiedWith = nil
        session.lastUpdated = Date()
        session.version += 1

        do {
            try await syncService.saveSession(session, familyID: familyID)
            if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                activeSessions[idx] = session
            }
        } catch {
            errorMessage = "Failed to deny session: \(error.localizedDescription)"
        }
    }

    /// Parent escalates consequences for a session.
    /// Applies real consequences: streak reset and tier escalation on next session.
    /// Uses atomic batch write so session + profile are updated together or not at all.
    func escalateSession(_ sessionID: UUID, reason: String) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }),
              let familyID else { return }

        session.parentAction = .escalated(reason: reason)
        session.parentActionAt = Date()
        session.state = .failed
        BetaDiagnostics.log(.parentAction(action: "escalated"))
        session.lastUpdated = Date()
        session.version += 1

        guard var child = children.first(where: { $0.id == session.childProfileID }) else {
            errorMessage = "Child profile not found for escalation."
            return
        }

        // Apply consequences to the child profile
        child.stats.currentStreak = 0
        child.stats.rewardPoints = max(0, child.stats.rewardPoints - 25)
        child.pendingTierEscalation = true

        do {
            // Atomic: both session and profile written together
            try await syncService.escalateSessionAndProfile(session: session, profile: child, familyID: familyID)
            if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                activeSessions[idx] = session
            }
            if let idx = children.firstIndex(where: { $0.id == child.id }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to escalate session: \(error.localizedDescription)"
        }
    }

    /// Whether the parent can still act on a hybrid-policy session.
    func canActOnSession(_ session: MorningSession) -> Bool {
        // Always can act on pending review
        if session.state == .pendingParentReview { return true }
        // For hybrid: can act within the review window
        if session.isReviewWindowOpen { return true }
        return false
    }

    /// Sends a message to the child device.
    func sendMessage(_ message: String, toSession sessionID: UUID) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }),
              let familyID else { return }
        session.parentMessage = message
        session.lastUpdated = Date()
        session.version += 1
        do {
            try await syncService.saveSession(session, familyID: familyID)
            if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                activeSessions[idx] = session
            }
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    /// Deducts reward points for a redeemed reward.
    func redeemPoints(_ amount: Int) async {
        guard var child = selectedChild, let familyID else { return }
        child.stats.rewardPoints = max(0, child.stats.rewardPoints - amount)
        do {
            try await syncService.saveChildProfile(child, familyID: familyID)
            if let idx = children.firstIndex(where: { $0.id == child.id }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to redeem reward: \(error.localizedDescription)"
        }
    }

    /// Clears local session and tamper history for the selected child.
    func clearLocalHistory() async {
        recentSessions = []
        tamperEvents = []
        try? await LocalStore.shared.saveRecentSessions([])
    }

    /// Skips an alarm until the end of tomorrow (one-day skip for sick days, holidays).
    /// Sets skipUntil to start-of-day + 2 days, so the alarm is skipped for the rest of today and all of tomorrow.
    func skipAlarmTomorrow(_ scheduleID: UUID) async {
        guard var schedule = alarmSchedules.first(where: { $0.id == scheduleID }) else { return }
        let skipUntil = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: .now)) ?? .now
        schedule.skipUntil = skipUntil
        schedule.lastModified = Date()
        await saveAlarmSchedule(schedule)
    }

    /// Clears the skip on an alarm (un-skip).
    func clearAlarmSkip(_ scheduleID: UUID) async {
        guard var schedule = alarmSchedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.skipUntil = nil
        schedule.lastModified = Date()
        await saveAlarmSchedule(schedule)
    }

    /// Sets or clears voice alarm metadata for the selected child.
    func setVoiceAlarm(_ voiceAlarm: ChildProfile.VoiceAlarmMetadata?) async {
        guard var child = selectedChild, let familyID else { return }
        child.voiceAlarm = voiceAlarm
        do {
            try await syncService.saveChildProfile(child, familyID: familyID)
            if let idx = children.firstIndex(where: { $0.id == child.id }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to save voice alarm: \(error.localizedDescription)"
        }
    }

    /// Sets or clears next morning overrides for the selected child.
    func setNextMorningOverrides(_ overrides: ChildProfile.NextMorningOverrides?) async {
        guard var child = selectedChild, let familyID else { return }
        child.nextMorningOverrides = overrides
        do {
            try await syncService.saveChildProfile(child, familyID: familyID)
            if let idx = children.firstIndex(where: { $0.id == child.id }) {
                children[idx] = child
            }
        } catch {
            errorMessage = "Failed to save overrides: \(error.localizedDescription)"
        }
    }

    /// Remotely cancels an active alarm session.
    func cancelSession(_ sessionID: UUID) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }),
              let familyID else { return }
        session.state = .cancelled
        session.lastUpdated = Date()
        session.version += 1
        do {
            try await syncService.saveSession(session, familyID: familyID)
            if let idx = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                activeSessions[idx] = session
            }
        } catch {
            errorMessage = "Failed to cancel session: \(error.localizedDescription)"
        }
    }
}
