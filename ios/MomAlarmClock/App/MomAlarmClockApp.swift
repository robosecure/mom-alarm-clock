import SwiftUI

/// Main entry point for Mom Alarm Clock.
/// Uses server-validated auth state to determine role. No local-only role switching.
@main
struct MomAlarmClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var syncService: any SyncService = SyncServiceFactory.create()
    @State private var authService: AuthService
    @State private var parentVM: ParentViewModel
    @State private var childVM: ChildViewModel

    init() {
        let sync = SyncServiceFactory.create()
        let auth = AuthService(syncService: sync)
        let parent = ParentViewModel(syncService: sync)
        let child = ChildViewModel(syncService: sync)

        _syncService = State(initialValue: sync)
        _authService = State(initialValue: auth)
        _parentVM = State(initialValue: parent)
        _childVM = State(initialValue: child)
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(authService)
                .environment(parentVM)
                .environment(childVM)
                .task {
                    NetworkMonitor.shared.syncService = syncService
                    // Wire rejection callback: refresh rejected sessions so UI converges
                    NetworkMonitor.shared.onSessionRejected = { sessionID in
                        guard let familyID = await LocalStore.shared.authState()?.familyID,
                              let uuid = UUID(uuidString: sessionID) else { return }
                        // Re-fetch from server to get authoritative state
                        for await session in syncService.observeSession(familyID: familyID, sessionID: uuid) {
                            if let session {
                                await MainActor.run {
                                    childVM.activeSession = session
                                    childVM.syncConflictMessage = "Session updated from server."
                                }
                            }
                            break // Only need one snapshot
                        }
                    }
                    // Monitor auth-expired rejections and show banner
                    Task { @MainActor in
                        // Check periodically if drain reported auth issues
                        for await _ in AsyncStream<Void> { cont in
                            Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in cont.yield() }
                        } {
                            if NetworkMonitor.shared.lastDrainAuthExpired > 0 {
                                childVM.connectivityBanner = "Session expired. Please restart the app to re-authenticate."
                            } else {
                                childVM.connectivityBanner = nil
                            }
                        }
                    }
                }
        }
    }
}
