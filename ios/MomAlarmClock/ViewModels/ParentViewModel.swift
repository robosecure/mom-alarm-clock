import Foundation
import SwiftUI

/// Primary view model for the parent-mode UI.
/// Manages the list of children, their alarm configurations, live session status, and history.
@Observable
final class ParentViewModel {
    // MARK: - State

    var children: [ChildProfile] = []
    var selectedChildID: UUID?
    var alarmSchedules: [AlarmSchedule] = []
    var activeSessions: [MorningSession] = []
    var recentSessions: [MorningSession] = []
    var tamperEvents: [TamperEvent] = []
    var isLoading = false
    var errorMessage: String?

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

    // MARK: - Data Loading

    /// Fetches all children and their data from CloudKit.
    func loadAllData() async {
        isLoading = true
        errorMessage = nil

        do {
            children = try await CloudSyncService.shared.fetchChildProfiles()
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

    /// Fetches alarm schedules and recent sessions for a specific child.
    func loadChildData(_ childID: UUID) async throws {
        async let schedules = CloudSyncService.shared.fetchAlarmSchedules(forChild: childID)
        async let sessions = CloudSyncService.shared.fetchMorningSessions(
            forChild: childID,
            from: Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        )

        let (fetchedSchedules, fetchedSessions) = try await (schedules, sessions)
        alarmSchedules = fetchedSchedules
        recentSessions = fetchedSessions
        activeSessions = fetchedSessions.filter(\.isActive)
    }

    // MARK: - Child Management

    /// Creates a new child profile with a pairing code.
    func addChild(name: String, age: Int) async {
        var profile = ChildProfile(name: name, age: age)
        profile.pairingCode = ChildProfile.generatePairingCode()

        do {
            _ = try await CloudSyncService.shared.save(childProfile: profile)
            children.append(profile)
            if selectedChildID == nil {
                selectedChildID = profile.id
            }
        } catch {
            errorMessage = "Failed to create child profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Alarm Management

    /// Creates or updates an alarm schedule and syncs to CloudKit.
    func saveAlarmSchedule(_ schedule: AlarmSchedule) async {
        do {
            _ = try await CloudSyncService.shared.save(alarmSchedule: schedule)
            if let index = alarmSchedules.firstIndex(where: { $0.id == schedule.id }) {
                alarmSchedules[index] = schedule
            } else {
                alarmSchedules.append(schedule)
            }
        } catch {
            errorMessage = "Failed to save alarm: \(error.localizedDescription)"
        }
    }

    /// Toggles an alarm schedule on or off.
    func toggleAlarm(_ scheduleID: UUID) async {
        guard var schedule = alarmSchedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.isEnabled.toggle()
        schedule.lastModified = Date()
        await saveAlarmSchedule(schedule)
    }

    // MARK: - Remote Actions

    /// Sends a message to the child device during an active session.
    func sendMessage(_ message: String, toSession sessionID: UUID) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.parentMessage = message
        session.lastUpdated = Date()
        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    /// Remotely cancels an active alarm session.
    func cancelSession(_ sessionID: UUID) async {
        guard var session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.state = .cancelled
        session.lastUpdated = Date()
        do {
            _ = try await CloudSyncService.shared.save(morningSession: session)
            if let index = activeSessions.firstIndex(where: { $0.id == sessionID }) {
                activeSessions[index] = session
            }
        } catch {
            errorMessage = "Failed to cancel session: \(error.localizedDescription)"
        }
    }
}
