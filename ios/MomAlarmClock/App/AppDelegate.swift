import UIKit
import UserNotifications
import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseCrashlytics
import FirebaseAnalytics
import FirebaseAppCheck

/// AppDelegate handles notification center delegation and background task registration.
/// Critical Alerts require the com.apple.developer.usernotifications.critical-alerts entitlement
/// which must be requested from Apple via https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    static let heartbeatTaskIdentifier = "com.momclock.heartbeat"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // App Check: debug provider for dev, App Attest for production.
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(MomAppCheckProviderFactory())
        #endif

        // Firebase must be configured before any Firebase service is used.
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["API_KEY"] as? String,
           !apiKey.hasPrefix("YOUR_") {
            FirebaseApp.configure()
            print("[Firebase] Configured from GoogleService-Info.plist")
        } else {
            print("[Firebase] Not configured — using local-only mode")
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        AlarmService.registerNotificationCategories()
        registerBackgroundTasks()
        requestNotificationPermissions()

        // Register for remote notifications (required for FCM on iOS)
        application.registerForRemoteNotifications()

        // Reschedule all alarms from local persistence on every launch.
        Task {
            await AlarmService.shared.rescheduleAllAlarms()
            await LocalStore.shared.pruneOldSessions()
        }

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

            // Reschedule alarms on every background refresh as a safety net
            Task { await AlarmService.shared.rescheduleAllAlarms() }

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
        // Also trigger alarm session creation for foreground notifications
        let userInfo = notification.request.content.userInfo
        if let alarmID = userInfo["alarmID"] as? String {
            NotificationCenter.default.post(
                name: .alarmNotificationTapped,
                object: nil,
                userInfo: ["alarmID": alarmID]
            )
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap — route to the correct alarm/verification screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Track push delivery for diagnostics
        let pushType = userInfo["type"] as? String ?? "alarm"
        Task { @MainActor in
            BetaDiagnostics.shared.recordPushReceived(type: pushType)
            BetaDiagnostics.log(.pushReceived(type: pushType))
        }

        // Handle guardian approve/deny from notification action buttons
        let actionID = response.actionIdentifier
        if actionID == "APPROVE" || actionID == "DENY" {
            if let sessionID = userInfo["sessionID"] as? String {
                NotificationCenter.default.post(
                    name: .guardianNotificationAction,
                    object: nil,
                    userInfo: ["sessionID": sessionID, "action": actionID]
                )
            }
        }

        if let alarmID = userInfo["alarmID"] as? String {
            NotificationCenter.default.post(
                name: .alarmNotificationTapped,
                object: nil,
                userInfo: ["alarmID": alarmID]
            )
        }
        completionHandler()
    }

    // MARK: - APNS Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM Token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, FirebaseApp.app() != nil else { return }
        print("[FCM] Token: \(token.prefix(20))...")
        Task { @MainActor in BetaDiagnostics.shared.recordTokenRegistration(token) }

        // Store the token under the user's Firestore doc for Cloud Functions to read
        Task {
            guard let authState = await LocalStore.shared.authState() else { return }
            let db = Firestore.firestore()
            try? await db.collection("users").document(authState.userID).updateData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ])
        }
    }
}

// MARK: - Custom Notification Names

extension Notification.Name {
    static let alarmNotificationTapped = Notification.Name("alarmNotificationTapped")
    static let guardianNotificationAction = Notification.Name("guardianNotificationAction")
}
