import Foundation
import FirebaseStorage
import FirebaseCore

/// Downloads and caches guardian voice alarm clips for offline playback.
/// Listens for metadata changes and re-downloads when updatedAt changes.
actor VoiceAlarmCacheService {
    static let shared = VoiceAlarmCacheService()

    // FileManager lives on the actor — all accesses go through actor-isolated methods.
    private let fileManager = FileManager.default

    /// Status for diagnostics.
    private(set) var lastDownloadResult: String = "Not attempted"
    private(set) var isCached: Bool = false
    private(set) var cachedUpdatedAt: Date?

    // MARK: - Cache Directory

    private var cacheDirectory: URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            let dir = fileManager.temporaryDirectory.appendingPathComponent("VoiceAlarmCache", isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let dir = docs.appendingPathComponent("VoiceAlarmCache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns the local file URL for a child's cached voice alarm.
    func cachedFileURL(childID: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(childID.uuidString).m4a")
    }

    // MARK: - Sync

    /// Checks if the cached file matches the metadata. Downloads if stale or missing.
    func syncIfNeeded(childID: UUID, metadata: ChildProfile.VoiceAlarmMetadata?) async {
        guard let metadata, metadata.enabled else {
            // Voice alarm disabled or deleted — remove cache
            removeCachedFile(childID: childID)
            isCached = false
            cachedUpdatedAt = nil
            lastDownloadResult = "Disabled"
            return
        }

        let localURL = cachedFileURL(childID: childID)

        // Check if we already have the latest version
        if fileManager.fileExists(atPath: localURL.path),
           let cachedAt = cachedUpdatedAt,
           cachedAt >= metadata.updatedAt {
            isCached = true
            lastDownloadResult = "Up to date"
            return
        }

        // Download from Firebase Storage
        guard FirebaseApp.app() != nil else {
            lastDownloadResult = "Firebase not configured"
            return
        }

        let storageRef = Storage.storage().reference(withPath: metadata.storagePath)

        do {
            let _ = try await storageRef.writeAsync(toFile: localURL)
            isCached = true
            cachedUpdatedAt = metadata.updatedAt
            lastDownloadResult = "Downloaded at \(Date().formatted(date: .omitted, time: .standard))"
            print("[VoiceAlarm] Cached clip for child \(childID.uuidString)")
        } catch {
            isCached = false
            lastDownloadResult = "Download failed: \(error.localizedDescription)"
            print("[VoiceAlarm] Download failed: \(error.localizedDescription)")
        }
    }

    /// Removes the cached file for a child.
    func removeCachedFile(childID: UUID) {
        let url = cachedFileURL(childID: childID)
        try? fileManager.removeItem(at: url)
    }

    /// Whether a cached file exists for a child.
    func hasCachedFile(childID: UUID) -> Bool {
        fileManager.fileExists(atPath: cachedFileURL(childID: childID).path)
    }
}
