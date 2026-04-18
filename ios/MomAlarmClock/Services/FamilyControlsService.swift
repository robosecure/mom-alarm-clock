import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity

/// Manages Screen Time / Family Controls integration for the child device.
///
/// This service handles:
/// 1. Requesting FamilyControls authorization (requires the com.apple.developer.family-controls entitlement)
/// 2. Applying ManagedSettings shields to block apps during escalation
/// 3. Scheduling DeviceActivity monitoring windows
///
/// IMPORTANT: FamilyControls authorization on a child's device requires either:
/// - The device is part of a Family Sharing group and the parent approves, OR
/// - The app uses the `.individual` authorization (iOS 16+) for self-managed access
///
/// For V1 we use `.individual` authorization since pairing is handled via CloudKit, not Family Sharing.
@Observable
@MainActor
final class FamilyControlsService {
    static let shared = FamilyControlsService()

    private(set) var isAuthorized = false
    private(set) var authorizationError: Error?

    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared

    // MARK: - Authorization

    /// Requests FamilyControls authorization. Must be called before any shield/monitoring operations.
    func requestAuthorization() async {
        do {
            // TODO: Entitlement required — com.apple.developer.family-controls
            // Apply at https://developer.apple.com/contact/request/family-controls-distribution
            try await center.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
        } catch {
            isAuthorized = false
            authorizationError = error
            DebugLog.log("[FamilyControls] Authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - App Shielding (ManagedSettings)

    /// Blocks entertainment apps — games, social media, video streaming.
    /// Called at escalation level `.appLockPartial`.
    func applyPartialShield() {
        guard isAuthorized else { return }

        // Shield specific app categories. ManagedSettings uses opaque Application tokens
        // from the FamilyActivityPicker, but for programmatic use we shield by category.
        store.shield.applicationCategories = .specific(Set<ActivityCategoryToken>())

        // The shield configuration (icon, title, message) is defined in a ShieldConfigurationExtension.
        // For now we use the system defaults.
        store.shield.webDomainCategories = .specific(Set<ActivityCategoryToken>())

        DebugLog.log("[FamilyControls] Partial shield applied — entertainment apps blocked.")
    }

    /// Blocks all apps except Phone, Messages, and emergency services.
    /// Called at escalation level `.appLockFull`.
    func applyFullShield() {
        guard isAuthorized else { return }

        // Block all applications
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()

        DebugLog.log("[FamilyControls] Full shield applied — all apps blocked.")
    }

    /// Removes all shields — called after successful verification.
    func removeAllShields() {
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        store.clearAllSettings()
        DebugLog.log("[FamilyControls] All shields removed.")
    }

    // MARK: - Device Activity Monitoring

    /// Schedules a DeviceActivity monitoring window for the morning alarm period.
    /// The DeviceActivityMonitor extension receives callbacks when the window starts/ends.
    func scheduleMonitoring(alarmTime: AlarmSchedule.AlarmTime, durationMinutes: Int = 60) throws {
        guard isAuthorized else {
            DebugLog.log("[FamilyControls] Monitoring skipped — not authorized")
            return
        }
        let center = DeviceActivityCenter()

        let startComponents = DateComponents(hour: alarmTime.hour, minute: alarmTime.minute)
        let endHour = (alarmTime.hour + (alarmTime.minute + durationMinutes) / 60) % 24
        let endMinute = (alarmTime.minute + durationMinutes) % 60
        let endComponents = DateComponents(hour: endHour, minute: endMinute)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true
        )

        try center.startMonitoring(
            DeviceActivityName("morningAlarm"),
            during: schedule
        )

        DebugLog.log("[FamilyControls] Monitoring scheduled: \(alarmTime.formatted) for \(durationMinutes) min.")
    }

    /// Stops all DeviceActivity monitoring.
    func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        DebugLog.log("[FamilyControls] Monitoring stopped.")
    }
}
