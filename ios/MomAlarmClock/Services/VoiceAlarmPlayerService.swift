import Foundation
import AVFoundation

/// Plays the cached voice alarm clip when an alarm fires.
/// Falls back to default sound if no clip is cached.
@MainActor
final class VoiceAlarmPlayerService {
    static let shared = VoiceAlarmPlayerService()

    private var player: AVAudioPlayer?
    private(set) var isPlaying = false

    /// Attempts to play the cached voice alarm for a child.
    /// Returns true if a voice clip was played, false if fallback is needed.
    @discardableResult
    func playIfCached(childID: UUID) async -> Bool {
        let fileURL = await VoiceAlarmCacheService.shared.cachedFileURL(childID: childID)
        let hasCached = await VoiceAlarmCacheService.shared.hasCachedFile(childID: childID)

        guard hasCached else {
            print("[VoiceAlarm] No cached clip for child \(childID) — using default sound")
            return false
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.numberOfLoops = 0 // Play once
            player?.volume = 1.0
            player?.play()
            isPlaying = true

            print("[VoiceAlarm] Playing cached clip for child \(childID)")

            // Auto-stop tracking when done
            Task {
                try? await Task.sleep(for: .seconds(player?.duration ?? 30))
                isPlaying = false
            }
            return true
        } catch {
            print("[VoiceAlarm] Playback failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Stops any currently playing voice alarm.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}
