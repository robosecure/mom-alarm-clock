import Foundation

// MARK: - Alarm Sound Asset Placeholder
//
// This file is a placeholder indicating where to add the alarm sound file.
//
// Requirements:
// - Format: .caf (Core Audio Format) — required for Critical Alerts
// - Duration: Must be 30 seconds or less
// - File name: alarm_critical.caf
// - Place the .caf file in this Resources directory
//
// How to create a .caf file from an existing sound:
//   afconvert input.mp3 alarm_critical.caf -d LEI16 -f caff -c 1
//
// How to reference in code:
//   UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("alarm_critical.caf"))
//
// For development/testing, the app uses UNNotificationSound.defaultCritical which
// plays the system default critical alert sound.
//
// Recommended: include 2-3 alarm sound variants so parents can choose:
//   - alarm_gentle.caf     — soft chime for the first escalation level
//   - alarm_standard.caf   — standard alarm for the second level
//   - alarm_critical.caf   — loud, impossible-to-ignore for higher escalation

/// Sound file names available in the bundle.
enum AlarmSounds {
    static let gentle = "alarm_gentle.caf"
    static let standard = "alarm_standard.caf"
    static let critical = "alarm_critical.caf"

    /// All available sound names.
    static let all = [gentle, standard, critical]
}
