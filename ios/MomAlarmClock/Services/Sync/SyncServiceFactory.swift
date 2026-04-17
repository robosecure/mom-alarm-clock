import Foundation
import FirebaseCore

/// Creates the appropriate SyncService based on configuration.
/// Uses FirestoreSyncService if Firebase is initialized, otherwise LocalSyncService.
/// Must be called AFTER FirebaseApp.configure() in AppDelegate.
enum SyncServiceFactory {
    static func create() -> any SyncService {
        #if DEBUG
        // UI-test / screenshot fixture path: Firestore has no auth session,
        // so its reads get "Missing or insufficient permissions" rejected.
        // Force the local in-memory backend when a fixture is seeded.
        if ProcessInfo.processInfo.arguments.contains("-ui-fixture") {
            print("[Sync] -ui-fixture present — forcing LocalSyncService.")
            return LocalSyncService()
        }
        #endif
        if FirebaseApp.app() != nil {
            print("[Sync] Firebase configured — using Firestore for cross-device sync.")
            return FirestoreSyncService()
        }
        print("[Sync] Firebase not configured — using local-only sync.")
        return LocalSyncService()
    }
}
