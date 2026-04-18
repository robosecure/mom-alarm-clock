import Foundation
import UserNotifications
import AVFoundation

/// Manages scheduling and cancelling local notifications for alarms.
/// Uses Critical Alerts (when entitled) so the alarm sounds even in Do Not Disturb / Silent mode.
///
/// FIX: Uses repeating triggers with weekday+hour+minute components so alarms fire
/// every week automatically, not just once. This was the root cause of the "alarms fire
/// once and then stop" bug — the old code used full date components with repeats: false.
actor AlarmService {
    static let shared = AlarmService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let localStore = LocalStore.shared

    /// Prefix for all alarm notification identifiers.
    private let idPrefix = "com.momclock.alarm."

    // MARK: - Schedule

    /// Schedules repeating notifications for each active day in the alarm schedule.
    /// Uses weekday+hour+minute components with `repeats: true` so alarms recur weekly.
    func scheduleAlarm(_ schedule: AlarmSchedule) async throws {
        await cancelAlarm(schedule.id)

        guard schedule.isEffectivelyEnabled else { return }

        for weekday in schedule.activeDays.sorted() {
            let primaryID = notificationID(alarmID: schedule.id, weekday: weekday, offset: 0)
            try await scheduleRepeatingNotification(
                id: primaryID,
                title: "Wake Up!",
                body: schedule.label,
                weekday: weekday,
                hour: schedule.alarmTime.hour,
                minute: schedule.alarmTime.minute,
                isCritical: true,
                alarmID: schedule.id.uuidString
            )

            // One backup notification 2 minutes later (also repeating)
            let backupMinute = (schedule.alarmTime.minute + 2) % 60
            let backupHour = schedule.alarmTime.minute + 2 >= 60
                ? (schedule.alarmTime.hour + 1) % 24
                : schedule.alarmTime.hour
            let backupID = notificationID(alarmID: schedule.id, weekday: weekday, offset: 120)
            try await scheduleRepeatingNotification(
                id: backupID,
                title: "Wake Up! (Reminder)",
                body: "Your alarm is still going — time to get up!",
                weekday: weekday,
                hour: backupHour,
                minute: backupMinute,
                isCritical: true,
                alarmID: schedule.id.uuidString
            )
        }
    }

    /// Reschedules all alarms from local persistence. Called on app launch and background refresh.
    /// Also detects drift: if scheduled notification count doesn't match expected, self-heals.
    func rescheduleAllAlarms() async {
        let schedules = await localStore.alarmSchedules()
        let enabledSchedules = schedules.filter(\.isEffectivelyEnabled)

        // Drift detection: count expected vs actual notifications
        let pending = await notificationCenter.pendingNotificationRequests()
        let alarmNotifs = pending.filter { $0.identifier.hasPrefix(idPrefix) }
        let expectedCount = enabledSchedules.reduce(0) { $0 + $1.activeDays.count * 2 } // primary + backup per day

        if alarmNotifs.count != expectedCount {
            DebugLog.log("[Alarm] Drift detected: \(alarmNotifs.count) scheduled vs \(expectedCount) expected. Self-healing.")
            // Cancel all stale alarm notifications and reschedule from scratch
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: alarmNotifs.map(\.identifier)
            )
        }

        for schedule in enabledSchedules {
            try? await scheduleAlarm(schedule)
        }
        DebugLog.log("[Alarm] Rescheduled \(enabledSchedules.count) alarms (\(expectedCount) notifications) from local store.")
    }

    /// Cancels all notifications associated with a specific alarm schedule.
    func cancelAlarm(_ alarmID: UUID) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let idsToRemove = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("\(idPrefix)\(alarmID.uuidString)") }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToRemove)
    }

    /// Cancels all Mom Alarm Clock notifications.
    func cancelAll() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        weekday: Int,
        hour: Int,
        minute: Int,
        isCritical: Bool,
        alarmID: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["alarmID": alarmID]
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .critical

        if isCritical {
            content.sound = UNNotificationSound.defaultCritical
        } else {
            content.sound = .default
        }

        // KEY FIX: Use only weekday + hour + minute with repeats: true.
        // This makes the alarm fire every week on this day at this time,
        // instead of once on a specific calendar date.
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await notificationCenter.add(request)
    }

    private func notificationID(alarmID: UUID, weekday: Int, offset: Int) -> String {
        "\(idPrefix)\(alarmID.uuidString).\(weekday).\(offset)"
    }
}

// MARK: - Notification Actions

extension AlarmService {
    /// Registers notification categories with snooze and dismiss actions.
    static func registerNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze",
            options: []
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "I'm Awake",
            options: [.authenticationRequired, .foreground]
        )
        let category = UNNotificationCategory(
            identifier: "ALARM",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        // Guardian: pending review notification with approve/deny actions
        let approveAction = UNNotificationAction(
            identifier: "APPROVE",
            title: "Approve",
            options: [.authenticationRequired]
        )
        let denyAction = UNNotificationAction(
            identifier: "DENY",
            title: "Deny — Re-verify",
            options: [.authenticationRequired, .destructive]
        )
        let reviewCategory = UNNotificationCategory(
            identifier: "PENDING_REVIEW",
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category, reviewCategory])
    }
}
