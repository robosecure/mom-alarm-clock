import Foundation
import FirebaseCore

/// Creates the appropriate SyncService based on configuration.
/// Uses FirestoreSyncService if Firebase is initialized, otherwise LocalSyncService.
/// Must be called AFTER FirebaseApp.configure() in AppDelegate.
enum SyncServiceFactory {
    static func create() -> any SyncService {
        if FirebaseApp.app() != nil {
            print("[Sync] Firebase configured — using Firestore for cross-device sync.")
            return FirestoreSyncService()
        }
        print("[Sync] Firebase not configured — using local-only sync.")
        return LocalSyncService()
    }
}
