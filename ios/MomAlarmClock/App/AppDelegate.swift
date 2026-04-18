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
           !apiKey.isEmpty,
           apiKey != "PLACEHOLDER",
           !apiKey.hasPrefix("YOUR_") {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            DebugLog.log("[Firebase] Configured from GoogleService-Info.plist")
        } else {
            DebugLog.log("[Firebase] Not configured — using local-only mode")
        }

        UNUserNotificationCenter.current().delegate = self
        AlarmService.registerNotificationCategories()
        registerBackgroundTasks()
        requestNotificationPermissions()

        // FCM requires a valid Firebase config
        if FirebaseApp.app() != nil {
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
        }

        // Reschedule all alarms from local persistence on every launch.
        // Also wire HeartbeatService if this is a child device so the BG task has config.
        Task {
            await AlarmService.shared.rescheduleAllAlarms()
            await LocalStore.shared.pruneOldSessions()

            // Wire HeartbeatService for child devices so offline detection works.
            if let authState = await LocalStore.shared.authState(),
               authState.role == .child,
               let profile = await LocalStore.shared.childProfile() {
                let sync = SyncServiceFactory.create()
                await HeartbeatService.shared.configure(
                    syncService: sync,
                    familyID: authState.familyID,
                    childID: profile.id
                )
            }
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
                DebugLog.log("[AppDelegate] Notification auth error: \(error.localizedDescription)")
            }
            DebugLog.log("[AppDelegate] Notification auth granted: \(granted)")
            // Publish result so banners / setup wizard can react
            Task { @MainActor in
                await BetaDiagnostics.shared.refreshPushState()
                if !granted {
                    NotificationCenter.default.post(
                        name: .notificationPermissionDenied,
                        object: nil
                    )
                }
            }
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
    nonisolated func userNotificationCenter(
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
    nonisolated func userNotificationCenter(
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
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM Token

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, FirebaseApp.app() != nil else { return }
        DebugLog.log("[FCM] Token: \(token.prefix(20))...")
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
    static let notificationPermissionDenied = Notification.Name("notificationPermissionDenied")
}
