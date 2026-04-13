import Foundation
import BackgroundTasks
import Network

/// Periodically pings CloudKit (or a future backend) so the parent device can detect
/// if the child's device goes offline. If heartbeats stop, the parent receives a
/// "device offline" warning — this is critical for detecting power-off tampering.
///
/// iOS severely limits background execution. We use two complementary strategies:
/// 1. BGAppRefreshTask — scheduled every 15 minutes (iOS decides actual timing)
/// 2. Web Audio API heartbeat — a lightweight web view that plays silent audio to keep
///    the app process alive (implemented separately in the web layer)
actor HeartbeatService {
    static let shared = HeartbeatService()

    /// How often we attempt to send a heartbeat (iOS may not honor this exactly).
    private let targetInterval: TimeInterval = 15 * 60 // 15 minutes

    /// The threshold after which the parent considers the child's device offline.
    static let offlineThreshold: TimeInterval = 30 * 60 // 30 minutes without heartbeat

    private let cloudSync = CloudSyncService.shared
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = true

    init() {
        startNetworkMonitoring()
    }

    // MARK: - Background Refresh

    /// Called by AppDelegate when the BGAppRefreshTask fires.
    nonisolated func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                try await sendHeartbeat()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            await scheduleNextRefresh()
        }
    }

    /// Schedules the next background app refresh.
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: AppDelegate.heartbeatTaskIdentifier
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: targetInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[Heartbeat] Next refresh scheduled for ~\(Int(targetInterval / 60)) min from now.")
        } catch {
            print("[Heartbeat] Failed to schedule refresh: \(error.localizedDescription)")
        }
    }

    // MARK: - Heartbeat

    /// Sends a heartbeat ping to CloudKit, updating the child profile's lastHeartbeat timestamp.
    func sendHeartbeat() async throws {
        guard isNetworkAvailable else {
            print("[Heartbeat] Skipping — no network.")
            return
        }

        guard let childIDString = UserDefaults.standard.string(forKey: "childProfileID"),
              let childID = UUID(uuidString: childIDString) else {
            print("[Heartbeat] No child profile ID stored.")
            return
        }

        // Fetch the current profile, update heartbeat, and save back
        let profiles = try await cloudSync.fetchChildProfiles()
        guard var profile = profiles.first(where: { $0.id == childID }) else {
            print("[Heartbeat] Child profile not found in CloudKit.")
            return
        }

        profile.lastHeartbeat = Date()
        _ = try await cloudSync.save(childProfile: profile)
        print("[Heartbeat] Sent at \(Date().formatted(date: .omitted, time: .standard))")
    }

    // MARK: - Offline Detection (Parent Side)

    /// Checks whether a child's device appears to be offline based on their last heartbeat.
    static func isDeviceOffline(lastHeartbeat: Date?) -> Bool {
        guard let lastHeartbeat else { return true }
        return Date().timeIntervalSince(lastHeartbeat) > offlineThreshold
    }

    /// Returns a human-readable string for the last heartbeat time.
    static func lastSeenDescription(lastHeartbeat: Date?) -> String {
        guard let lastHeartbeat else { return "Never connected" }
        let interval = Date().timeIntervalSince(lastHeartbeat)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        return lastHeartbeat.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.updateNetworkStatus(path.status == .satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.momclock.heartbeat.network"))
    }

    private func updateNetworkStatus(_ available: Bool) {
        isNetworkAvailable = available
    }
}
