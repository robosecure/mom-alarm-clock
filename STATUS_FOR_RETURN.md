# Mom Alarm Clock — Status when you return

Generated Fri Apr 17, 2026, ~5:34 PM

---

## TL;DR

Archive is **99% built and paused on a Mac-login password prompt.** Enter your Mac password in the hidden `com.apple.SecurityAgent` dialog and the archive will finish, then go Organizer → Distribute App → TestFlight.

---

## What got done while you were away

**Commit:** `823ee85` — "V1 archive unblock: comment out Critical Alerts + Family Controls entitlements"

1. **Removed two entitlements from `ios/MomAlarmClock.entitlements`** (commented out with TODO-Restore headers):
   - `com.apple.developer.usernotifications.critical-alerts`
   - `com.apple.developer.family-controls`
   Both are behind the TODO headers so `scripts/pre-archive-check.sh` marks them as `WARN (pending approval)` rather than failing.
2. **Hardened `scripts/pre-archive-check.sh`** so the comment/active distinction uses a Python XML-comment stripper instead of plain grep (plain grep couldn't tell the difference).
3. **Pre-archive check passes** with 3 warnings:
   - 2× expected: entitlements pending Apple approval
   - 1× git: uncommitted changes (since cleared by the commit above)
4. **Switched Xcode destination to Wambat once** to force team-registration of your iPhone 16 Pro Max. This minted a Development provisioning profile for the team — the missing piece that was blocking every earlier archive.
5. **Switched destination back to `Any iOS Device (arm64)`** for the archive.
6. **Kicked off Product → Archive** — it got to **2116/2125 build tasks** (linking, bundling, asset processing all done) before pausing on the keychain password prompt.

---

## The blocker (needs you, one click)

The macOS SecurityAgent has a hidden dialog asking you to authorize `codesign` to use your "Apple Distribution: Ross Mathews" private key from Keychain. I can't see it (Apple's security-critical UI is shielded from automation) and I can't type into it.

**Action:** Look for a dialog on your screen, enter your Mac login password, click **Always Allow**. Archive completes automatically within ~30s.

If the dialog has already timed out and dismissed itself, you may see the archive as "Build Failed" or "Cancelled." In that case:
- Make sure Wambat is unplugged if Developer Mode is off (removes the distraction)
- Xcode menu → Product → Archive
- Watch for the dialog and authorize immediately this time

**Belt-and-suspenders:** Open **Keychain Access** → find "Apple Distribution: Ross Mathews" → double-click → **Access Control** tab → "Always allow access by these applications" → add `codesign` and `productbuild`. One-time setup and you won't see this prompt again.

---

## After the archive opens the Organizer

You'll see the Organizer window listing the new .xcarchive. Click the archive, then the blue **Distribute App** button on the right.

Flow:
1. Distribution method: **TestFlight & App Store** (or on Xcode 16, **App Store Connect**)
2. Destination: **Upload**
3. Signing: leave as Automatic (Xcode will re-sign with the Distribution cert)
4. Review → Upload
5. Apple may challenge for 2FA at this point — approve the code on your trusted Apple device

### If upload fails with "no app record found"

The bundle ID `com.momclock.MomAlarmClock` needs an App Store Connect app record BEFORE you can upload to TestFlight. Create it now at https://appstoreconnect.apple.com/apps → **+** → New App. Required fields:
- Platforms: iOS
- Name: Mom Alarm Clock
- Primary Language: English (US)
- Bundle ID: `com.momclock.MomAlarmClock` (Xcode Team, U474UU36TW)
- SKU: `momalarmclock-001` (anything unique)
- User Access: Full Access

Then retry Distribute App in Organizer.

---

## After the build is in TestFlight

1. App Store Connect → My Apps → Mom Alarm Clock → **TestFlight** tab
2. You'll see the build processing (takes 5-15 min after upload)
3. Add **Internal Testers** under your team — they get an email to install via the TestFlight app
4. For friends outside the team: create an **External Testing** group, add emails, submit for Apple's brief review (usually same-day for first external build)

---

## Still pending — Apple-portal work you'll need to do

These were blocked today but are unrelated to archive; they should run in parallel:

### 1. Submit Critical Alerts entitlement request  (~1-3 week approval)

- URL: https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
- Pre-written 500-word justification ready to paste: see `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` §Part 2 Step 3
- Required fields: Bundle ID `com.momclock.MomAlarmClock`, Team ID `U474UU36TW`

### 2. Submit Family Controls (Distribution) entitlement request  (~1-3 weeks)

- URL: https://developer.apple.com/contact/request/family-controls-distribution/
- Short justification: "Mom Alarm Clock uses Family Controls (Individual authorization) to progressively restrict entertainment apps on the child device when a scheduled alarm is ignored for 20+ minutes. Full justification in ENTITLEMENT_JUSTIFICATIONS.md §2."
- Required fields: same Bundle ID and Team ID as above

### 3. Create APNs .p8 Auth Key + upload to Firebase

- Full walkthrough: `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` §Part 1
- Needed for guardian-device push notifications (review pings, tamper alerts)
- Upload destination: Firebase Console → Project settings → Cloud Messaging → Apple app configuration

---

## When approvals land (1-3 weeks from today)

1. Open `ios/MomAlarmClock.entitlements`
2. Delete the `<!-- -->` wrappers around both entitlement keys
3. Bump `CFBundleVersion` in `ios/Info.plist` from 2 → 3
4. Re-run `scripts/pre-archive-check.sh` (should be all ok, no warnings)
5. Commit: `git commit -am "Restore Critical Alerts + Family Controls entitlements (Apple approval received)"`
6. Product → Archive → Organizer → Distribute → TestFlight upload
7. Push the new build to testers — alarm sounds now bypass DND, app-lock escalation works

---

## Files changed this session

```
ios/MomAlarmClock.entitlements                                    — commented out 2 entitlements
ios/MomAlarmClock.xcodeproj/project.pbxproj                       — DEVELOPMENT_TEAM surfaced to build settings (Xcode auto-change)
ios/MomAlarmClock.xcodeproj/xcshareddata/xcschemes/
     MomAlarmClock.xcscheme                                       — BuildableName converged to "Mom Alarm Clock.app" (Xcode auto-change)
scripts/pre-archive-check.sh                                      — Python-powered comment detection for entitlement check
STATUS_FOR_RETURN.md                                              — this file
```

All changes in commit `823ee85`. Working tree is clean.

---

## One-line next action

**Enter your Mac password in the hidden SecurityAgent dialog, then click Always Allow.** Everything else is queued up and ready.
