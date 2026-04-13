import Foundation
import AVFoundation
import UserNotifications
import Combine

/// Monitors the child's device for tamper attempts during an active alarm session.
///
/// Detected tampering is reported to CloudKit immediately so the parent device
/// receives a near-real-time alert. Tamper events also trigger automatic escalation.
///
/// Detection strategies:
/// - Volume KVO: observes AVAudioSession outputVolume for decreases
/// - Notification permission polling: checks if the user revoked notification auth
/// - Network reachability: detects airplane mode activation
/// - Heartbeat gaps: detected on the parent side via HeartbeatService
@Observable
final class TamperDetectionService {
    static let shared = TamperDetectionService()

    private(set) var isMonitoring = false
    private(set) var detectedEvents: [TamperEvent] = []

    private var volumeObservation: NSKeyValueObservation?
    private var permissionCheckTimer: Timer?
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

        print("[TamperDetection] Monitoring started.")
    }

    /// Stops all monitoring. Call when the alarm session ends.
    func stopMonitoring() {
        isMonitoring = false
        volumeObservation?.invalidate()
        volumeObservation = nil
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil

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

    // MARK: - Reporting

    /// Records a tamper event locally and pushes it to CloudKit.
    @MainActor
    private func reportEvent(type: TamperEvent.TamperType, detail: String, severity: TamperEvent.Severity) {
        guard let childProfileID else { return }

        // Deduplicate — don't report the same type within 60 seconds
        let cutoff = Date().addingTimeInterval(-60)
        if detectedEvents.contains(where: { $0.type == type && $0.timestamp > cutoff }) {
            return
        }

        let event = TamperEvent(
            type: type,
            detail: detail,
            severity: severity,
            childProfileID: childProfileID
        )
        detectedEvents.append(event)

        // Push to CloudKit asynchronously
        Task {
            do {
                _ = try await CloudSyncService.shared.report(tamperEvent: event)
                print("[TamperDetection] Event reported to cloud: \(type.displayName)")
            } catch {
                print("[TamperDetection] Failed to report event: \(error.localizedDescription)")
            }
        }
    }
}
