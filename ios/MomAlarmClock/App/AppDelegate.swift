import UIKit
import UserNotifications
import BackgroundTasks

/// AppDelegate handles notification center delegation and background task registration.
/// Critical Alerts require the com.apple.developer.usernotifications.critical-alerts entitlement
/// which must be requested from Apple via https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static let heartbeatTaskIdentifier = "com.momclock.heartbeat"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerBackgroundTasks()
        requestNotificationPermissions()
        return true
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        // .criticalAlert requires the entitlement; without it this flag is silently ignored.
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        center.requestAuthorization(options: options) { granted, error in
            if let error {
                print("[AppDelegate] Notification auth error: \(error.localizedDescription)")
            }
            print("[AppDelegate] Notification auth granted: \(granted)")
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.heartbeatTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            HeartbeatService.shared.handleBackgroundRefresh(refreshTask)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notification even when app is in foreground — essential for alarm UX.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap — route to the correct alarm/verification screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let alarmID = userInfo["alarmID"] as? String {
            NotificationCenter.default.post(
                name: .alarmNotificationTapped,
                object: nil,
                userInfo: ["alarmID": alarmID]
            )
        }
        completionHandler()
    }
}

// MARK: - Custom Notification Names

extension Notification.Name {
    static let alarmNotificationTapped = Notification.Name("alarmNotificationTapped")
}
