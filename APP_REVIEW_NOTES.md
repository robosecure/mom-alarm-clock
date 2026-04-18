# Mom Alarm Clock — App Review Notes

Paste this into the "App Review Information > Notes" field in App Store Connect.

---

## What This App Does

Mom Alarm Clock is a two-device family alarm app. A guardian sets alarms on their phone. The child's device fires the alarm and requires the child to complete a short verification task (quiz, step counting, or photo) to prove they are awake.

By default, the alarm clears automatically once the child verifies. The guardian is only notified when something needs attention (verification failure, tamper event, or manual review mode).

## How to Test

**Guardian device:**
1. Open the app and create a guardian account (email + password)
2. Add a child (name + age)
3. Note the join code shown after signup
4. Create an alarm for 2-3 minutes from now with "Quiz" verification

**Child device (can use a second simulator or device):**
1. Open the app and tap "I'm a Child"
2. Enter the join code from the guardian device
3. Wait for the alarm to fire
4. Complete the quiz to verify

**Expected result:** The alarm fires, the child completes the quiz, and the session is marked as verified. The guardian can view the result in History.

[PLACEHOLDER: If you'd like to provide a pre-configured demo account, add credentials here:
- Guardian email: demo@momclock.com
- Guardian password: [password]
- Child join code: [code]]

## Permissions Used

| Permission | Why | What happens if denied |
|-----------|-----|----------------------|
| Notifications | Fires the alarm on the child's device; notifies guardian of pending reviews | Alarm scheduling still works but notifications may be silent |
| Microphone | Guardian can record a personal voice alarm message (optional feature) | Voice alarm feature is unavailable; standard alarm sound plays |
| Camera | Photo verification (optional method) | Photo verification is unavailable; quiz and motion still work |
| Photo Library | Photo verification picker (optional method) | Photo verification is unavailable; quiz and motion still work |
| Location | Geofence verification — confirms child reached a wake-up spot (optional, v1.1) | Geofence verification is unavailable; other methods work |
| Motion | Step counting verification — confirms child is out of bed (optional) | Motion verification is unavailable; quiz still works |

## Special Entitlements

**Critical Alerts (com.apple.developer.usernotifications.critical-alerts):**
Used so the alarm can bypass Silent Mode and Do Not Disturb on the child's device. If unavailable, standard notification sound is used. The alarm still fires but may be silenced by device settings.

**Family Controls (com.apple.developer.family-controls):**
Used for optional app-lock escalation. If a child ignores the alarm for 20+ minutes, entertainment apps can be restricted. If unavailable, escalation continues with notification-based reminders only. The app functions fully without this entitlement.

## Privacy

- Account deletion is available in-app: Settings > Delete Account
- Privacy & Data section in Settings explains what is collected
- "How It Works" section in Settings explains the product
- No tracking, no ads, no data sales
- Children cannot create accounts independently
- Age is stored as a number (not date of birth) and used only to tailor quiz difficulty
- Full privacy policy available in-app (once hosted URL is configured)

## Known Limitations

- App lock (FamilyControls) requires the child to grant Screen Time permission — this is an iOS requirement, not something the app can bypass
- Critical Alerts requires a separate Apple entitlement — without it, alarms use standard notification sounds
- QR code verification is not available in this release (hidden from the verification method picker; planned for a future update)
- The app requires iOS 17.0 or later
