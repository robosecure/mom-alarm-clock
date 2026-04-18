import Foundation
import Network

/// Shared network reachability monitor. Observes NWPathMonitor and drains
/// the LocalStore offline queue when connectivity is restored.
///
/// All mutable state is @MainActor-isolated to prevent concurrent drain races.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.momclock.networkmonitor")
    private var isDraining = false

    /// Inject the sync service so the queue drain knows where to replay actions.
    var syncService: (any SyncService)?
    var familyID: String?

    /// Called after a session write is rejected so the caller can refresh from server.
    var onSessionRejected: ((_ sessionID: String) async -> Void)?

    // MARK: - Sync Health (observable by DiagnosticsView)

    private(set) var lastDrainTime: Date?
    private(set) var lastDrainSucceeded: Int = 0
    private(set) var lastDrainRulesRejected: Int = 0
    private(set) var lastDrainAuthExpired: Int = 0
    private(set) var lastDrainTransient: Int = 0
    private(set) var lastDrainError: String?
    private(set) var rejectedSessionIDs: [String] = []

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasDisconnected = !self.isConnected
                self.isConnected = connected
                if connected && wasDisconnected {
                    await self.drainOfflineQueue()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Offline Queue Drain

    func drainOfflineQueue() async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        guard let syncService, let familyID else {
            lastDrainError = "Missing sync config"
            return
        }

        let pending = await LocalStore.shared.pendingQueue()
        guard !pending.isEmpty else { return }

        DebugLog.log("[NetworkMonitor] Draining \(pending.count) queued actions...")

        var remaining: [QueuedAction] = []
        var succeeded = 0
        var rulesRejected = 0
        var authExpired = 0
        var transient = 0
        var rejectedIDs: [String] = []
        let decoder = JSONDecoder()

        for action in pending {
            do {
                switch action.actionType {
                case .saveSession:
                    let session = try decoder.decode(MorningSession.self, from: action.payload)
                    try await syncService.saveSession(session, familyID: familyID)
                case .saveTamperEvent:
                    let event = try decoder.decode(TamperEvent.self, from: action.payload)
                    try await syncService.saveTamperEvent(event, familyID: familyID)
                case .updateProfile:
                    let profile = try decoder.decode(ChildProfile.self, from: action.payload)
                    try await syncService.saveChildProfile(profile, familyID: familyID)
                case .updateHeartbeat:
                    break
                }
                succeeded += 1
            } catch {
                let failure = FirestoreSyncService.classifyError(error)
                switch failure {
                case .rulesRejected(let reason):
                    rulesRejected += 1
                    if action.actionType == .saveSession,
                       let session = try? decoder.decode(MorningSession.self, from: action.payload) {
                        let sid = session.id.uuidString
                        rejectedIDs.append(sid)
                        DebugLog.log("[NetworkMonitor] Rules-rejected session \(sid) v\(session.version): \(reason)")
                        // Trigger refresh so UI converges to server state
                        await onSessionRejected?(sid)
                    }
                    // Drop -- stale or unauthorized
                case .authExpired:
                    authExpired += 1
                    remaining.append(action) // Retry after re-auth
                case .transientNetwork:
                    transient += 1
                    remaining.append(action) // Retry on next drain
                case .unknown:
                    remaining.append(action) // Retry
                }
            }
        }

        lastDrainTime = Date()
        lastDrainSucceeded = succeeded
        lastDrainRulesRejected = rulesRejected
        lastDrainAuthExpired = authExpired
        lastDrainTransient = transient
        lastDrainError = remaining.isEmpty ? nil : "\(remaining.count) actions queued for retry"
        rejectedSessionIDs = rejectedIDs

        do {
            if remaining.isEmpty {
                await LocalStore.shared.clearQueue()
            } else {
                try await LocalStore.shared.replaceQueue(remaining)
            }
        } catch {
            lastDrainError = "Queue update failed: \(error.localizedDescription)"
        }

        DebugLog.log("[NetworkMonitor] Drain: \(succeeded) ok, \(rulesRejected) rules-rejected, \(authExpired) auth-expired, \(transient) transient, \(remaining.count) queued.")
    }
}
