# Mom Alarm Clock — Entitlement Justifications

These justifications are required for Apple App Review. Keep this document updated as entitlements change.

---

## 1. Critical Alerts (`com.apple.developer.usernotifications.critical-alerts`)

**What it does:** Allows the app to play alarm sounds that bypass Silent Mode and Do Not Disturb.

**Why it's needed:** Mom Alarm Clock is an alarm app for children whose guardians need assurance that the alarm will actually wake their child. If the child's device is on Silent Mode or Do Not Disturb (common overnight), a standard notification would be inaudible, defeating the app's core purpose.

**How it's used:**
- Only for alarm fire notifications scheduled by the guardian
- Not for marketing, promotional, or non-critical notifications
- Guardian explicitly creates each alarm with a specific time
- Push notifications for guardian review use standard (non-critical) sound

**User control:** Guardians set all alarm times. Children cannot create alarms. The app never sends critical alerts outside of guardian-configured alarm schedules.

**Request URL:** https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/

---

## 2. Family Controls (`com.apple.developer.family-controls`)

**What it does:** Allows the app to restrict access to other apps on the child's device as part of alarm escalation.

**Why it's needed:** Mom Alarm Clock includes an escalation system: if a child ignores their alarm, the app progressively increases consequences. After 20 minutes of ignoring the alarm, entertainment apps are blocked. After 30 minutes, all non-essential apps are blocked. This is a key safety feature that gives guardians confidence the alarm system has teeth.

**How it's used:**
- Uses `AuthorizationCenter.shared.requestAuthorization(for: .individual)` — app-level authorization, not Family Sharing
- Partial shield: blocks entertainment category (games, social media) at the 20-minute escalation level
- Full shield: blocks all categories except Phone and Emergency at the 30-minute escalation level
- Shields are removed when the child completes verification or when the guardian cancels the alarm
- Guardian controls which escalation levels are active via alarm settings

**User control:** 
- The child must explicitly grant FamilyControls authorization on their device
- The guardian configures escalation levels (can disable app lock entirely)
- App lock is never applied without an active alarm session
- Locks are always removable by completing verification

**Note:** If Apple does not approve this entitlement, the app degrades gracefully — the two app-lock escalation levels simply have no effect, and a diagnostic log entry is written. All other escalation levels (gentle reminder, guardian notification) continue to work.

---

## 3. Background Modes

### `fetch` (Background App Refresh)
- Used to reschedule alarms from local persistence on background refresh
- Sends heartbeat to Firestore so guardians can see the child's device is active
- Registered as BGTaskScheduler task: `com.momclock.heartbeat`

### `remote-notification` (Push Notifications)
- Required for Firebase Cloud Messaging (FCM) to deliver guardian notifications
- Guardian receives push when child's verification is pending review
- Guardian receives push when a tamper event is detected

### `audio` (Background Audio)
- Used to play the guardian's custom voice alarm recording when the alarm fires
- Voice clip is pre-cached locally for offline playback
- Playback stops when the child begins verification

---

## 4. aps-environment (`production`)

Push notifications are used for:
- Notifying guardians when a child's verification needs review
- Notifying guardians of tamper events (volume changes, permission revocation)
- Push action buttons (Approve / Deny) directly from the notification

Push notifications are NOT used for:
- Marketing or promotional content
- Notifications to children (children receive only local alarm notifications)
- Any content unrelated to the active alarm/session flow
