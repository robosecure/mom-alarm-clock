import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseCore
import FirebaseAnalytics
import FirebaseAppCheck

/// Centralized observability for beta testing.
/// Tracks push token state, notification delivery, and logs privacy-safe analytics events.
@MainActor @Observable
final class BetaDiagnostics {
    static let shared = BetaDiagnostics()

    // MARK: - Push State

    private(set) var fcmToken: String?
    private(set) var fcmTokenRegisteredAt: Date?
    private(set) var lastPushReceivedAt: Date?
    private(set) var lastPushType: String?
    private(set) var pushPermissionGranted: Bool = false

    // MARK: - Session Tracking

    private(set) var lastAlarmDidFireAt: Date?
    private(set) var lastAlarmSource: String?
    private(set) var lastVerificationMethod: String?
    private(set) var lastVerificationPassed: Bool?

    func recordAlarmFired(source: String) {
        lastAlarmDidFireAt = Date()
        lastAlarmSource = source
    }

    func recordVerification(method: String, passed: Bool) {
        lastVerificationMethod = method
        lastVerificationPassed = passed
    }

    // MARK: - App Check State

    private(set) var appCheckEnabled: Bool = false
    private(set) var appCheckProvider: String = "unknown"
    private(set) var appCheckLastResult: String?

    func refreshAppCheckState() async {
        guard FirebaseApp.app() != nil else {
            appCheckEnabled = false
            appCheckProvider = "none"
            return
        }
        appCheckEnabled = true
        #if DEBUG
        appCheckProvider = "debug"
        #else
        appCheckProvider = "appAttest"
        #endif
        // Attempt a token fetch to verify it works
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: false)
            appCheckLastResult = "OK (\(token.token.prefix(8))...)"
        } catch {
            appCheckLastResult = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh

    func refreshPushState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushPermissionGranted = settings.authorizationStatus == .authorized

        if let token = Messaging.messaging().fcmToken {
            fcmToken = String(token.prefix(20)) + "..."
        }
    }

    func recordTokenRegistration(_ token: String) {
        fcmToken = String(token.prefix(20)) + "..."
        fcmTokenRegisteredAt = Date()
    }

    func recordPushReceived(type: String) {
        lastPushReceivedAt = Date()
        lastPushType = type
    }

    // MARK: - Diagnostics Export

    /// Generates a privacy-safe JSON blob for support.
    /// No secrets, tokens, email addresses, join codes, message bodies, or precise identifiers.
    /// IDs are truncated to 8 characters. Device name is redacted.
    func exportDiagnostics(auth: AuthService) async -> String {
        await refreshPushState()
        await refreshAppCheckState()
        let queueCount = await LocalStore.shared.pendingQueue().count
        let alarmCount = await UNUserNotificationCenter.current().pendingNotificationRequests().count

        let dict: [String: Any] = [
            "_header": "Mom Alarm Clock — Privacy-Safe Diagnostics",
            "_notice": "This export contains no emails, passwords, tokens, join codes, or message content. IDs are truncated. Safe to share with support.",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            "role": auth.currentUser?.role.rawValue ?? "none",
            "familyID": String(auth.currentUser?.familyID.prefix(8) ?? "none"),
            "firebaseConfigured": FirebaseApp.app() != nil,
            "appCheckEnabled": appCheckEnabled,
            "appCheckProvider": appCheckProvider,
            "appCheckResult": appCheckLastResult ?? "untested",
            "pushPermission": pushPermissionGranted,
            "fcmTokenPresent": fcmToken != nil,
            "fcmTokenRegistered": fcmTokenRegisteredAt?.ISO8601Format() ?? "never",
            "lastPushReceived": lastPushReceivedAt?.ISO8601Format() ?? "never",
            "networkConnected": NetworkMonitor.shared.isConnected,
            "queueLength": queueCount,
            "lastDrain": NetworkMonitor.shared.lastDrainTime?.ISO8601Format() ?? "never",
            "lastDrainSucceeded": NetworkMonitor.shared.lastDrainSucceeded,
            "lastDrainRulesRejected": NetworkMonitor.shared.lastDrainRulesRejected,
            "lastDrainAuthExpired": NetworkMonitor.shared.lastDrainAuthExpired,
            "lastDrainTransient": NetworkMonitor.shared.lastDrainTransient,
            "rejectedSessionCount": NetworkMonitor.shared.rejectedSessionIDs.count,
            "scheduledAlarms": alarmCount,
            "deviceModel": UIDevice.current.model,
            "iOS": UIDevice.current.systemVersion,
            "timezone": TimeZone.current.identifier,
            "hasActiveSession": await LocalStore.shared.activeSession() != nil,
            "lastAlarmFiredAt": lastAlarmDidFireAt?.ISO8601Format() ?? "never",
            "lastAlarmSource": lastAlarmSource ?? "none",
            "lastVerificationMethod": lastVerificationMethod ?? "none",
            "lastVerificationPassed": lastVerificationPassed as Any,
            "cachedAlarmSchedules": await LocalStore.shared.alarmSchedules().count,
            "familyControlsAuthorized": FamilyControlsService.shared.isAuthorized,
            "exportedAt": Date().ISO8601Format(),
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"error\": \"serialization failed\"}"
    }

    // MARK: - Privacy-Safe Analytics Events

    /// Logs an analytics event. Never includes PII, join codes, message bodies, or photos.
    /// Nonisolated because Firebase Analytics is thread-safe.
    nonisolated static func log(_ event: AnalyticsEvent) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    enum AnalyticsEvent {
        case pairingSuccess(role: String)
        case alarmFired(method: String, tier: String)
        case verificationSubmitted(method: String, tier: String, passed: Bool)
        case parentAction(action: String) // "approved", "denied", "escalated"
        case syncRulesRejected(count: Int)
        case pushSent // logged server-side
        case pushReceived(type: String)
        case sessionCreated
        case tamperDetected(type: String)
        case streakMilestone(days: Int)
        case rewardRedeemed(points: Int)
        case queueWriteFailed

        var name: String {
            switch self {
            case .pairingSuccess: "pairing_success"
            case .alarmFired: "alarm_fired"
            case .verificationSubmitted: "verification_submitted"
            case .parentAction: "parent_action"
            case .syncRulesRejected: "sync_rules_rejected"
            case .pushSent: "push_sent"
            case .pushReceived: "push_received"
            case .sessionCreated: "session_created"
            case .tamperDetected: "tamper_detected"
            case .streakMilestone: "streak_milestone"
            case .rewardRedeemed: "reward_redeemed"
            case .queueWriteFailed: "queue_write_failed"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .pairingSuccess(let role):
                return ["role": role]
            case .alarmFired(let method, let tier):
                return ["method": method, "tier": tier]
            case .verificationSubmitted(let method, let tier, let passed):
                return ["method": method, "tier": tier, "passed": passed]
            case .parentAction(let action):
                return ["action": action]
            case .syncRulesRejected(let count):
                return ["count": count]
            case .pushSent:
                return [:]
            case .pushReceived(let type):
                return ["type": type]
            case .sessionCreated:
                return [:]
            case .tamperDetected(let type):
                return ["type": type]
            case .streakMilestone(let days):
                return ["days": days]
            case .rewardRedeemed(let points):
                return ["points": points]
            case .queueWriteFailed:
                return [:]
            }
        }
    }
}
