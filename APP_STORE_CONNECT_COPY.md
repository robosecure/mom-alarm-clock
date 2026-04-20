# App Store Connect — Paste-Ready Copy

Everything you need to fill in the App Store Connect forms tomorrow. Each section matches a screen you'll see in ASC. Copy the block, paste it in, move on. Character counts shown where Apple enforces limits.

**One-time setup (before pasting anything below):**
Bundle ID: `com.momclock.MomAlarmClock`
Team ID: `U474UU36TW`
SKU (unique ID you invent): `momalarmclock-001`
Primary language: English (US)

---

## 1. App Information (initial app-record creation)

**Name** (30 char limit)
```
Mom Alarm Clock
```
(15 chars)

**Subtitle** (30 char limit)
```
Alarms that prove they're up
```
(28 chars)

**Bundle ID:** `com.momclock.MomAlarmClock` (select from dropdown — must match Xcode exactly)

**Primary Category:** Lifestyle
**Secondary Category:** Productivity

**Content Rights:** Does your app contain, show, or access third-party content? → **No**

**Age Rating:** complete questionnaire below (§7) → result will be **4+**

---

## 2. Pricing and Availability

- **Price:** Free (Tier 0)
- **Availability:** All territories (or at minimum: United States)
- **Volume Purchase Program:** No change (default)
- **Pre-Order:** Off

---

## 3. Version 1.0 Metadata (the main submission screen)

### Promotional Text (170 char limit, editable without re-review)
```
Stop nagging. Set an alarm your child must actually solve to dismiss. Quiz, steps, or photo. You get peace of mind — they learn to own their morning.
```
(153 chars)

### Description (4000 char limit)
```
Mom Alarm Clock is the family alarm built for parents who are tired of shaking a shoulder twelve times before school.

Here's how it works: you set the alarm on your phone. It fires on your child's phone. And before the alarm will stop, your child has to prove they're actually awake — by solving a quiz, taking a few steps, or snapping a selfie.

No more hitting snooze from under the covers. No more "I'm up!" followed by another thirty minutes of silence. The alarm doesn't dismiss until your kid does something that proves they're out of bed.

KEY FEATURES

• Two-device pairing. One device belongs to you (the guardian). The other belongs to your child. You schedule; they wake up.

• Three verification methods.
  — Quiz: age-appropriate math or trivia questions
  — Step count: the alarm dismisses once the phone has moved enough to count as "out of bed"
  — Photo: a quick selfie that proves they're upright

• Trust mode by default. Once your child verifies, the alarm auto-acknowledges. You only get a notification when something actually needs attention — a failed verification, a tamper attempt, or a session you've flagged for manual review.

• Streaks and rewards. Kids who wake up on time build a streak and earn reward points. It gamifies the hardest part of every school morning.

• History at a glance. See every morning's wake-up time, verification method, and result in one scrollable timeline.

• Escalation that's humane. If the alarm is ignored for too long, the app gently escalates with reminder notifications rather than locking the device (unless you've opted in to app-lock escalation, available in a future update).

• Built for school mornings. Recurring alarms, weekday-only schedules, and snooze rules that actually enforce themselves.

WHO IT'S FOR

Parents of kids who:
• are old enough to have their own phone or tablet
• struggle to wake up on time for school
• say "I'm up!" and then absolutely aren't
• or just need a little more accountability without a parent standing over the bed

PRIVACY AND SAFETY

• No tracking. No ads. No data sales. Ever.
• Children can't create accounts. A guardian pairs every child device with a family code.
• Age is stored as a number, used only to tailor quiz difficulty.
• Account deletion is one tap in Settings → Delete Account.
• Full privacy policy in-app and at our website.

GETTING STARTED

1. Install the app on both devices.
2. On your phone, create a guardian account and add your child.
3. On your child's phone, tap "I'm a Child" and enter the family code from your device.
4. Set your first alarm. You're done.

Mom Alarm Clock doesn't replace your parenting — but it does replace the morning shoulder-shake.
```

### Keywords (100 char limit, no spaces around commas)
```
kids,alarm,family,wake,child,morning,school,routine,parent,verified,clock,chore
```
(78 chars — room to add 1-2 more if desired)

### Support URL
```
https://robosecure.github.io/mom-alarm-clock-legal/support.html
```
⚠️ **TODO before submission:** confirm this page exists on GitHub Pages. If not, either (a) publish a minimal support page at that URL, or (b) use `https://robosecure.github.io/mom-alarm-clock-legal/` as the root.

### Marketing URL (optional — leave blank for V1)
Skip for V1.

### Privacy Policy URL
```
https://robosecure.github.io/mom-alarm-clock-legal/privacy.html
```

### Copyright
```
© 2026 Rob Wamsley
```

### Version (build metadata)
- **Version string:** `1.0`
- **Build number:** will auto-populate after TestFlight upload (should be `2` from your Info.plist)

### What's New in This Version (required for every submission after 1.0 — skip for initial 1.0)
N/A for V1.0. For V1.0.1 and later, a reasonable first line is:
```
First release. Pair your family, set an alarm, make the phone actually wake them up.
```

---

## 4. App Privacy (the nutrition label)

Apple asks: "Do you or your third-party partners collect data from this app?" → **Yes**

Check each category below. For each one: **Linked to user: Yes**, **Used for tracking: No**, **Purposes: App Functionality** (unless otherwise noted).

| Category | Type | Why |
|---|---|---|
| Contact Info | Email Address | Guardian account creation |
| Contact Info | Name | Guardian name + child's first name |
| User Content | Photos or Videos | Optional photo verification |
| User Content | Audio Data | Optional voice alarm recording |
| Identifiers | User ID | Firebase Auth UID (required for family pairing) |
| Usage Data | Product Interaction | Firebase Analytics — **also check "Analytics"** as a purpose |
| Diagnostics | Crash Data | Firebase Crashlytics |
| Diagnostics | Performance Data | Firebase Crashlytics / Performance |

**Do NOT declare Location** — geofence verification is planned for V1.1 and is filtered out in V1 code (`VerificationMethod.isAvailableForLaunch` returns false for geofence). Declare it when you re-enable the feature.

**Tracking:** No. (Apple defines tracking as linking to third-party data for advertising — you don't do this.)

---

## 5. Age Rating Questionnaire

Click every row → **None / No**:
- Cartoon or Fantasy Violence → None
- Realistic Violence → None
- Prolonged Graphic or Sadistic Realistic Violence → None
- Profanity or Crude Humor → None
- Mature/Suggestive Themes → None
- Horror/Fear Themes → None
- Medical/Treatment Information → None
- Alcohol, Tobacco, or Drug Use or References → None
- Simulated Gambling → None
- Sexual Content and Nudity → None
- Graphic Sexual Content and Nudity → None
- Contests → None
- Unrestricted Web Access → **No**
- Gambling → **No**

**Result:** 4+

---

## 6. App Review Information (the "talking to Apple" screen)

**First Name:** Rob
**Last Name:** Wamsley
**Phone Number:** (your mobile, include country code — e.g. +1 555 555 5555)
**Email:** wamsley.rob@gmail.com

**Sign-in required:** Yes

**Demo Account:**
- Username: `demo-guardian@momclock.app`
- Password: `DemoGuardian2026!`

**Notes:** Paste the full contents of `APP_REVIEW_NOTES.md` into this field. It already includes the second demo account, the family join code, permissions rationale, entitlement status, and known limitations.

**Attachment:** Optional. A 10-15 second screen recording of the alarm-fire → quiz → approved loop helps App Review a lot. Record on the simulator if the live seed flow is slow.

---

## 7. TestFlight Configuration

### Beta App Description (required before external testers can install)
```
Mom Alarm Clock is a two-device family alarm. One device belongs to the guardian (parent), who schedules alarms. The other belongs to the child, who must complete a short verification task — quiz, step count, or photo — to dismiss the alarm. The default flow auto-acknowledges verified sessions; the guardian is only notified when something actually needs attention. This beta exists to validate the core wake-up loop end-to-end on real devices before public release.
```

### Beta App Feedback Email
```
wamsley.rob@gmail.com
```
(Or create a fresh `beta@momclock.app` alias if you want feedback separate from support.)

### What to Test (paste into every new build's "Test Information" field)
```
Focus areas for this beta:

1. PAIRING. Install on two devices. Create a guardian account on one. Tap "I'm a Child" on the other and paste the family code shown after signup. Confirm the child appears in the guardian's family list.

2. ALARM FIRE. Create an alarm for 2–3 minutes from now with Quiz verification. Lock the child device. Confirm the alarm fires with sound at the scheduled time, even on the lock screen.

3. VERIFICATION. Complete the quiz on the child device. Confirm the alarm dismisses, the guardian sees the session as "Approved," and the streak counter increments.

4. EDIT FLOW. On the guardian device, tap an existing alarm, change the time, tap Save. Confirm the next fire uses the new time.

5. HISTORY. Open the History tab. Confirm completed sessions appear with the correct date, verification method, and result.

Please report:
• Alarms that fail to fire
• Sessions that don't sync between devices within 30 seconds
• Verification loops (e.g. quiz keeps asking the same question)
• Crashes (send the crash report via the TestFlight feedback button)
```

### License Agreement
Leave as default (Apple's standard EULA).

### Marketing URL
Leave blank for V1.

### Privacy Policy URL
```
https://robosecure.github.io/mom-alarm-clock-legal/privacy.html
```

---

## 8. Screenshots (shot-list + capture plan)

**Required size for V1:** 6.9" iPhone (iPhone 16 Pro Max) — `1320 × 2868` or `2868 × 1320`.
**Optional but recommended:** 6.5" iPhone — `1242 × 2688`. If skipped, Apple auto-scales the 6.9" shots.

Minimum 3, maximum 10. Recommend 5–6 captured on the **same physical iPhone 16 Pro Max** you're using for development, ordered so the Apple review listing reads left-to-right as a story.

### The 6 shots to capture

| # | Screen | Setup on the seeded demo account | Caption overlay |
|---|---|---|---|
| 1 | Guardian "Today" view with Alex's alarm | Sign in as demo-guardian, open Today tab | **Set it once.** Every morning, handled. |
| 2 | Alarm creation — Quiz verification picker visible | Tap "+ Alarm", scroll to verification picker, tap "Quiz" | **Pick the wake-up challenge.** |
| 3 | Child alarm-ringing screen with quiz question | Sign in on second device as demo-child, trigger a test alarm, pause before answering | **Prove you're actually awake.** |
| 4 | Verified result screen with streak | Complete quiz; screenshot the approved state with the 6-day streak | **Build the streak. Earn the reward.** |
| 5 | Family pairing — join code visible | Guardian device, Family settings, show join code | **Pair the family in one tap.** |
| 6 | History timeline | Guardian device, History tab, 7 days visible | **See every morning at a glance.** |

### How to capture cleanly
1. Turn on Do Not Disturb so no personal notifications bleed in
2. Set the clock to `9:41 AM` on every shot (Apple's convention — device setting: Developer > Clock)
3. Signal bar full, battery 100%, Wi-Fi on
4. Use the physical iPhone 16 Pro Max, not the simulator — simulator screenshots get rejected sometimes
5. Press Volume Up + Side button to capture; screenshots land in Photos
6. AirDrop to Mac, drop into `/Users/wamsley/mom-alarm-clock/marketing/screenshots/` (create the folder)

### Caption overlay (optional but converts better)
If you want captioned frames like every polished App Store listing: use Rotato, Fastlane `frameit`, or just Figma with a device frame asset. Not required for initial submission — plain device screenshots are accepted.

---

## 9. App Store Icon

Already in the build: `AppIcon.appiconset`. Apple pulls the 1024×1024 automatically from the uploaded IPA — no separate upload needed.

---

## 10. Pre-submission sanity check

Before hitting **Submit for Review**, confirm each:
- [ ] Every field in §3 filled (no "Not specified" anywhere)
- [ ] Privacy nutrition label completed (§4)
- [ ] Age rating submitted (§5)
- [ ] App Review Information completed with demo account (§6)
- [ ] At least 3 screenshots uploaded for 6.9"
- [ ] Build attached from TestFlight (select from dropdown — only appears once TestFlight processing completes, ~15 min after upload)
- [ ] Version 1.0 + correct build number visible at top of the version page
- [ ] Export compliance: the app **does not** use custom encryption → select "Uses standard iOS encryption" → "Exempt" — no upload needed

---

## 11. Entitlement request — Family Controls (tighter version)

For when you submit the entitlement request tomorrow. The Critical Alerts justification is already in `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` §Part 2 Step 3 — paste that one as-is. This one is new:

Paste into https://developer.apple.com/contact/request/family-controls-distribution/ :

```
Mom Alarm Clock is a children's alarm app in which guardians schedule wake-up alarms for their children, and the child's device must complete a verification task (quiz, step count, or photo) before the alarm dismisses.

We are requesting the Family Controls (Distribution) entitlement for a single, narrow purpose: progressive app-lock escalation when a child ignores a scheduled alarm for 20+ minutes.

Usage model:
1. The entitlement is invoked only on the child's device, only when a scheduled alarm reaches the 20-minute ignore threshold.
2. On invocation, the app uses FamilyActivitySelection (Individual authorization) to request temporary restriction of a pre-approved category of entertainment apps (games, social).
3. The restriction lifts automatically the moment the child completes verification, or when the guardian manually clears the session.
4. The child is shown a full-screen explanation before any restriction is applied. The feature is opt-in per family in Settings.
5. Nothing about the restriction is persistent, monetized, promotional, or used for any purpose other than ending the ignored-alarm state.

Graceful degradation: if the entitlement is denied, the escalation path continues with notification-based reminders only. No core app functionality depends on the entitlement.

Bundle ID: com.momclock.MomAlarmClock
Team ID: U474UU36TW

Happy to provide a build or screen recording if helpful. Thank you.
```

---

## 12. What's NOT in this file

These still need to happen at their respective tools — they're not copy-paste-able:
- Upload the .ipa (Xcode Organizer → Distribute App)
- Create the APNs .p8 key (developer.apple.com)
- Upload the .p8 to Firebase Console
- Seed the demo account (run `scripts/seed-demo-account.js` with service-account credentials)
- Capture the six screenshots on the physical device

All six are walked through in `LAUNCH_BRIEF_2026-04-18.md`.

---

**Last updated:** 2026-04-20
