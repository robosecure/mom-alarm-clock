import SwiftUI
import FirebaseCore

/// Main entry point for Mom Alarm Clock.
/// Uses server-validated auth state to determine role. No local-only role switching.
@main
struct MomAlarmClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var syncService: any SyncService
    @State private var authService: AuthService
    @State private var parentVM: ParentViewModel
    @State private var childVM: ChildViewModel

    init() {
        // DEBUG-only: seed LocalStore from launch args BEFORE services read it.
        // No-op in Release builds and when -ui-fixture is not passed.
        #if DEBUG
        UITestFixture.seedIfRequested()
        #endif

        // CRITICAL: Configure Firebase BEFORE creating the sync service.
        // SwiftUI App.init() runs before AppDelegate.didFinishLaunchingWithOptions,
        // so we must configure Firebase here to ensure SyncServiceFactory picks up
        // FirestoreSyncService instead of falling back to LocalSyncService.
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["API_KEY"] as? String,
           !apiKey.isEmpty,
           apiKey != "PLACEHOLDER",
           !apiKey.hasPrefix("YOUR_") {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
                print("[Firebase] Configured early in App.init()")
            }
        }

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
                .onReceive(NotificationCenter.default.publisher(for: .guardianNotificationAction)) { notif in
                    guard let sessionID = notif.userInfo?["sessionID"] as? String,
                          let action = notif.userInfo?["action"] as? String,
                          let uuid = UUID(uuidString: sessionID) else { return }
                    // Hop to MainActor explicitly; parentVM is @Observable MainActor-isolated,
                    // and sending it across an unspecified-actor Task risks races in Swift 6.
                    Task { @MainActor in
                        if parentVM.familyID == nil {
                            await parentVM.loadAllData()
                        }
                        switch action {
                        case "APPROVE":
                            await parentVM.approveSession(uuid)
                        case "DENY":
                            await parentVM.denySession(uuid, reason: "Denied from notification")
                        default:
                            break
                        }
                    }
                }
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
                    // Monitor auth-expired rejections and show banner.
                    // Uses Task.sleep so the loop fully unwinds (including the sleep) when
                    // the enclosing .task is cancelled on view disappear. Previously an
                    // AsyncStream wrapped a Timer.scheduledTimer that was never invalidated,
                    // leaking a timer every time the view re-entered.
                    Task { @MainActor in
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(10))
                            if Task.isCancelled { break }
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
