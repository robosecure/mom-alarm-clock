import Foundation
import AVFoundation
import UserNotifications
import Network

/// Monitors the child's device for tamper attempts during an active alarm session.
///
/// Detected tampering is reported to Firestore so the parent device receives a
/// near-real-time alert. Tamper events also trigger automatic escalation.
///
/// Device-side detections (implemented here):
/// - Volume KVO: observes AVAudioSession.outputVolume for decreases
/// - Notification permission polling: checks if the user revoked notification auth
/// - Network loss: NWPathMonitor detects airplane mode or WiFi/cellular off
/// - Timezone change: NSSystemTimeZoneDidChange notification
///
/// Parent-side detections (inferred by HeartbeatService):
/// - Device powered off / app force quit: detected via missing heartbeats
@Observable
final class TamperDetectionService {
    static let shared = TamperDetectionService()

    private(set) var isMonitoring = false
    private(set) var detectedEvents: [TamperEvent] = []

    private var volumeObservation: NSKeyValueObservation?
    private var permissionCheckTimer: Timer?
    private var networkMonitor: NWPathMonitor?
    private var timezoneObserver: NSObjectProtocol?
    private var lastKnownVolume: Float = 1.0
    private var childProfileID: UUID?

    // MARK: - Start / Stop

    /// Begins monitoring for tamper events. Call when an alarm session starts.
    func startMonitoring(childProfileID: UUID) {
        guard !isMonitoring else { return }
        self.childProfileID = childProfileID
        isMonitoring = true
        detectedEvents = []

        startVolumeObserver()
        startPermissionChecker()
        startNetworkLossDetector()
        startTimezoneChangeDetector()

        print("[TamperDetection] Monitoring started.")
    }

    /// Stops all monitoring. Call when the alarm session ends.
    func stopMonitoring() {
        isMonitoring = false
        volumeObservation?.invalidate()
        volumeObservation = nil
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        if let timezoneObserver {
            NotificationCenter.default.removeObserver(timezoneObserver)
            self.timezoneObserver = nil
        }

        print("[TamperDetection] Monitoring stopped. Events detected: \(detectedEvents.count)")
    }

    // MARK: - Volume Observer

    /// Watches AVAudioSession.outputVolume via KVO.
    /// If volume decreases during an active alarm, it is flagged as tampering.
    private func startVolumeObserver() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch {
            print("[TamperDetection] Failed to activate audio session: \(error)")
        }
        lastKnownVolume = session.outputVolume

        volumeObservation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
            guard let self, let newVolume = change.newValue, let oldVolume = change.oldValue else { return }
            if newVolume < oldVolume && newVolume < 0.3 {
                Task { @MainActor in
                    self.reportEvent(
                        type: .volumeLowered,
                        detail: "Volume reduced from \(Int(oldVolume * 100))% to \(Int(newVolume * 100))% during active alarm.",
                        severity: .high
                    )
                }
            }
        }
    }

    // MARK: - Permission Checker

    /// Periodically checks whether notification permissions are still granted.
    private func startPermissionChecker() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkNotificationPermission()
            }
        }
    }

    private func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            await MainActor.run {
                reportEvent(
                    type: .notificationsDisabled,
                    detail: "Notification permissions were revoked during an active alarm session.",
                    severity: .critical
                )
            }
        }
    }

    // MARK: - Network Loss Detector

    /// Detects when the child's device loses network connectivity during an active session.
    /// Uses NWPathMonitor — detects airplane mode, WiFi off, cellular off.
    private func startNetworkLossDetector() {
        let monitor = NWPathMonitor()
        self.networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self, self.isMonitoring else { return }
            if path.status == .unsatisfied {
                Task { @MainActor in
                    self.reportEvent(
                        type: .networkLost,
                        detail: "Network connectivity lost during active alarm session.",
                        severity: .medium
                    )
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.momclock.tamper.network"))
    }

    // MARK: - Timezone Change Detector

    /// Detects when the system timezone is changed during an active session.
    /// A child might change the timezone to make the alarm fire at a different time.
    private func startTimezoneChangeDetector() {
        timezoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isMonitoring else { return }
            self.reportEvent(
                type: .timeZoneChanged,
                detail: "System timezone was changed to \(TimeZone.current.identifier) during active alarm session.",
                severity: .high
            )
        }
    }

    // MARK: - Reporting

    /// The sync service for reporting events. Set externally before starting monitoring.
    var syncService: (any SyncService)?
    var familyID: String?

    /// Records a tamper event locally and pushes it to the backend.
    @MainActor
    private func reportEvent(type: TamperEvent.TamperType, detail: String, severity: TamperEvent.Severity) {
        guard let childProfileID else { return }

        // Deduplicate — don't report the same type within 60 seconds
        let cutoff = Date().addingTimeInterval(-60)
        if detectedEvents.contains(where: { $0.type == type && $0.timestamp > cutoff }) {
            return
        }

        var event = TamperEvent(
            type: type,
            detail: detail,
            severity: severity,
            childProfileID: childProfileID
        )
        // Attach consequence so parent sees the impact
        event.consequence = TamperConsequence.defaultConsequence(for: type)
        detectedEvents.append(event)
        BetaDiagnostics.log(.tamperDetected(type: type.rawValue))

        // Push to backend asynchronously
        if let syncService, let familyID {
            Task {
                do {
                    try await syncService.saveTamperEvent(event, familyID: familyID)
                    print("[TamperDetection] Event reported: \(type.displayName)")
                } catch {
                    // Queue for offline retry
                    try? await LocalStore.shared.appendToQueue(QueuedAction(
                        actionType: .saveTamperEvent,
                        payload: (try? JSONEncoder().encode(event)) ?? Data()
                    ))
                    print("[TamperDetection] Queued event for later: \(type.displayName)")
                }
            }
        }
    }

    /// Apply tamper consequences to a child profile for the next morning.
    /// Call after a session ends with tamper events.
    func applyConsequences(to profile: inout ChildProfile) {
        let shouldEscalate = detectedEvents.contains { $0.effectiveConsequence.escalateVerificationTier }
        if shouldEscalate {
            profile.pendingTierEscalation = true
        }

        // Streak and points impacts are computed by StatsService from the events themselves
    }
}
