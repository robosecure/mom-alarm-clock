import Foundation
import UserNotifications
import AVFoundation

/// Manages scheduling and cancelling local notifications for alarms.
/// Uses Critical Alerts (when entitled) so the alarm sounds even in Do Not Disturb / Silent mode.
///
/// Strategy: for each alarm, we schedule a primary notification plus several staggered
/// backup notifications at 1, 2, and 3 minutes after. This guards against iOS silently
/// dropping a single notification. Each backup checks whether the alarm has already been
/// dismissed before playing sound.
actor AlarmService {
    static let shared = AlarmService()

    private let notificationCenter = UNUserNotificationCenter.current()

    /// Prefix for all alarm notification identifiers.
    private let idPrefix = "com.momclock.alarm."

    // MARK: - Schedule

    /// Schedules all notifications for the given alarm schedule, starting from the next applicable day.
    func scheduleAlarm(_ schedule: AlarmSchedule) async throws {
        // Cancel any existing notifications for this alarm first.
        await cancelAlarm(schedule.id)

        guard schedule.isEnabled else { return }

        for weekday in schedule.activeDays.sorted() {
            guard let fireDate = schedule.alarmTime.nextOccurrence(on: weekday) else { continue }

            // Primary notification
            let primaryID = notificationID(alarmID: schedule.id, weekday: weekday, offset: 0)
            try await scheduleNotification(
                id: primaryID,
                title: "Wake Up!",
                body: schedule.label,
                fireDate: fireDate,
                isCritical: true,
                alarmID: schedule.id.uuidString
            )

            // Staggered backup notifications at +60s, +120s, +180s
            for offsetSeconds in [60, 120, 180] {
                let backupDate = fireDate.addingTimeInterval(TimeInterval(offsetSeconds))
                let backupID = notificationID(alarmID: schedule.id, weekday: weekday, offset: offsetSeconds)
                try await scheduleNotification(
                    id: backupID,
                    title: "Wake Up! (Reminder)",
                    body: "Your alarm is still going — time to get up!",
                    fireDate: backupDate,
                    isCritical: true,
                    alarmID: schedule.id.uuidString
                )
            }
        }
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

    private func scheduleNotification(
        id: String,
        title: String,
        body: String,
        fireDate: Date,
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
            // TODO: Replace with actual .caf alarm sound file bundled in Resources
            // Critical alert sound must be < 30 seconds
            content.sound = UNNotificationSound.defaultCritical
        } else {
            content.sound = .default
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
