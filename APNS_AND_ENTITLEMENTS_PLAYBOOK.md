# APNs Key + Critical Alerts Playbook

Two things this document walks you through step by step, because both require you to sign in to developer.apple.com yourself:

1. **Create an APNs Authentication Key (.p8) and upload it to Firebase** — required for push notifications to reach real devices (review pings, tamper alerts, push-action Approve/Deny).
2. **Submit the Critical Alerts entitlement request to Apple** — required for alarm sounds to bypass Silent Mode / DND on the child device.

Everything up to the portal login has been prepared for you: entitlements declare both keys, bundle ID is consistent, `aps-environment` is `production`, and the pre-archive check (`./scripts/pre-archive-check.sh`) passes.

---

## Part 1 — APNs Authentication Key

### Why a .p8 (not a .p12)

Firebase recommends Auth Keys over push certificates. One .p8 works for both dev and production, never expires, and works across all apps under your Team ID. Safer to rotate and simpler to manage.

### Step 1: Create the key in the Apple Developer portal

1. Sign in at https://developer.apple.com/account/resources/authkeys/list
2. Click the blue **+** button next to **Keys**
3. **Key Name:** `Mom Alarm Clock APNs` (or anything descriptive — it's only seen by you)
4. Check **Apple Push Notifications service (APNs)**
5. Click **Configure** next to APNs
6. Leave **Environment** set to **Sandbox & Production** (this is a single-key setup; don't split)
7. **Key Restriction:** select **Team Scoped** (safer — if you have more than one bundle ID on this Team, use **Topic Specific** and pick `com.momclock.MomAlarmClock`)
8. Click **Save**
9. Click **Continue** → **Register**
10. **Download** the .p8 file. You can only download it ONCE. Save it somewhere safe; Apple will not let you re-download it. Naming convention: `AuthKey_XXXXXXXXXX.p8` where the X's are the Key ID.

### Step 2: Record three pieces of information

You will need all three to paste into Firebase:

| What | Where to find it |
|---|---|
| **Key ID** (10 characters) | Shown on the key detail page after creation, or next to the key in the list |
| **Team ID** (10 characters) | Top right of https://developer.apple.com/account — under your name, or **Membership** tab |
| **Bundle ID** | Already known: `com.momclock.MomAlarmClock` |

### Step 3: Upload to Firebase Console

1. Go to https://console.firebase.google.com/
2. Open the **Mom Alarm Clock** project
3. Gear icon → **Project settings**
4. **Cloud Messaging** tab
5. Scroll to **Apple app configuration** → your iOS app
6. Under **APNs Authentication Key**, click **Upload**
7. Select the `.p8` file you saved
8. Enter the **Key ID** and **Team ID**
9. Click **Upload**

### Step 4: Verify it took

From the repo root:

```bash
# Fire a test FCM push to the current build on the simulator.
# This requires the app to be installed and to have run at least once
# (so it has registered an FCM token in Firestore).
node scripts/send-test-push.js --env=sandbox
```

(If that script doesn't exist yet, skip — uploading the key is the gating step for live-device testing. TestFlight is where it actually matters.)

On the real device: the first alarm you schedule should produce a pending-review push on the guardian device.

### Rollback / rotation

If the key leaks or you need to revoke: go back to https://developer.apple.com/account/resources/authkeys/list, click the key, **Revoke**. Then repeat steps 1–3 with a new key. No code changes required.

---

## Part 2 — Critical Alerts Entitlement Request

### Status of the declaration

The entitlement is **already declared** in `ios/MomAlarmClock.entitlements`:

```xml
<key>com.apple.developer.usernotifications.critical-alerts</key>
<true/>
```

But declaring it is not enough — Apple must approve your Team's right to use it. Without approval, the entitlement is ignored at runtime (notifications fall back to normal sounds).

### Step 1: Open the request form

URL: https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/

You must be signed in with the Team Agent account (or an account with the **Account Holder** / **Admin** role).

### Step 2: Fill in the form

- **Name, Email, Phone:** your info
- **App Name:** `Mom Alarm Clock`
- **App ID / Bundle ID:** `com.momclock.MomAlarmClock`
- **Team ID:** (the same 10-character Team ID from Part 1)
- **App Store Connect ID:** (the numeric App ID from App Store Connect, if the app record exists — otherwise leave blank and mention in the message that the record is not yet created)

### Step 3: Paste this justification

The full justification is already in `ENTITLEMENT_JUSTIFICATIONS.md` section 1. For the form's free-text field, here is a 500-word version trimmed to fit Apple's textarea. You can paste this verbatim:

> Mom Alarm Clock is a children's alarm clock app in which guardians schedule wake-up alarms for their children and set verification requirements (math, quiz, photo, step count, or geofence) that the child must complete before the alarm dismisses. The core value proposition is that guardians can trust the alarm will actually wake their child — without this trust, the app fails its purpose.
>
> We are requesting the Critical Alerts entitlement so that alarm notifications on the child's device can bypass Silent Mode and Do Not Disturb. Children commonly silence their phones overnight (as do adults), and on many nights a child's device is on DND or Silent Mode when the alarm is scheduled to fire. Without Critical Alerts, the scheduled alarm would be inaudible, defeating the app's purpose entirely. Standard user notifications are not sufficient for this use case for the same reason alarm clock apps generally request this entitlement.
>
> Usage is narrow and guardian-controlled:
>
> 1. Critical Alerts are used exclusively for alarm-fire notifications scheduled by a guardian. They are never used for marketing, promotional, secondary-flow, or engagement notifications.
> 2. Every alarm time is explicitly set by the guardian via the guardian UI. Children cannot schedule alarms and cannot elevate any notification to Critical. There is no programmatic promotion of non-alarm notifications.
> 3. All other notifications in the app (guardian-review pings, tamper alerts, approval receipts) use the standard UNNotificationInterruptionLevel — not Critical.
> 4. Volume is capped at 50% and the user can disable Critical Alerts entirely in Settings → Notifications → Mom Alarm Clock at any time.
> 5. We fail gracefully. If the entitlement is denied, alarms continue to fire using the standard notification path — they simply risk being silenced when the device is on DND. We do not block app functionality on the entitlement.
>
> The app is designed specifically for this narrow safety use case. We have implemented App Check, per-family Firestore rules, an explicit parental consent flow, and an account deletion path. Privacy declarations in PrivacyInfo.xcprivacy cover every category of data collected.
>
> Please let us know if additional technical details, a build for review, or any other information would help. Thank you for considering this request.

### Step 4: Submit and expect a 1–3 week wait

Apple responds by email to the Team Agent. During the wait:

- You can still upload builds to TestFlight with the entitlement declared. TestFlight will install and run the build; the entitlement will simply be inactive until approved.
- On real devices, alarms will fire at normal-notification volume (respecting Silent Mode) until approval lands.
- Once approved, no code change is required — the entitlement flips on automatically because it's already in the .entitlements file.

### If the request is denied

Apple occasionally declines with a request for more information. Common fixes:

- Add a short screen recording demonstrating the alarm-fire flow + the user-facing Settings toggle
- Emphasize the single narrow use (alarm sound only) and the graceful degradation path
- Re-submit with the clarification pasted into the new request

The justification above has been structured to preempt the most common decline reasons (promotional use, scope creep, forced activation).

---

## Companion references

- Full entitlement narrative (used in App Store Review Notes too): `ENTITLEMENT_JUSTIFICATIONS.md`
- Pre-archive sanity check: `scripts/pre-archive-check.sh` — run this before every archive
- App Review Notes (paste into App Store Connect): `APP_REVIEW_NOTES.md`
- Launch sequence & tester script: `LAUNCH_CHECKLIST.md`
