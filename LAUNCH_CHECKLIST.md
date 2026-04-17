# Mom Alarm Clock — Final Launch Checklist & Tester Script

---

## Release Configuration

| # | Item | Status | Action Required |
|---|------|--------|-----------------|
| 1 | GoogleService-Info.plist in correct target | **MISSING** | Download from Firebase Console > Project Settings > iOS app, place in `ios/MomAlarmClock/` |
| 2 | DEVELOPMENT_TEAM set correctly | **PLACEHOLDER** | Replace `TEAM_ID_HERE` in `project.yml:17` with your Apple Developer Team ID |
| 3 | Bundle identifier for release | OK | `com.momclock.MomAlarmClock` — verify this matches Firebase and App Store Connect |
| 4 | Firebase Auth: Email/Password | **MANUAL** | Enable in Firebase Console > Authentication > Sign-in method |
| 5 | Firebase Auth: Anonymous | **MANUAL** | Enable in Firebase Console > Authentication > Sign-in method |
| 6 | Firestore rules deployed | **DEPLOY** | `firebase deploy --only firestore:rules` |
| 7 | Firestore indexes deployed | **DEPLOY** | `firebase deploy --only firestore:indexes` (3 composite indexes defined) |
| 8 | Cloud Functions deployed | **DEPLOY** | `cd functions && npm install && firebase deploy --only functions` (7 functions) |
| 9 | Firebase Storage rules deployed | **DEPLOY** | `firebase deploy --only storage` |
| 10 | APNS key uploaded to Firebase | **MANUAL** | See `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` Part 1 for click-by-click steps |
| 11 | Push notifications capability | OK | Entitlements set to `aps-environment: production` (verified by pre-archive-check) |
| 12 | App Check configured | OK | MomAppCheckProviderFactory uses App Attest (release) / Debug (dev) |
| 13 | Privacy policy URL live | **MANUAL** | Host privacy policy, add URL to App Store Connect |
| 14 | Support contact ready | **MANUAL** | Add support email to App Store Connect listing |
| 15 | Account deletion flow visible and working | OK | Settings > Delete Account — deletes Firebase Auth user + Firestore doc + local state |

### Pre-deploy commands

```bash
# 1. Set your team ID
sed -i '' 's/TEAM_ID_HERE/YOUR_REAL_TEAM_ID/' ios/project.yml

# 2. Regenerate Xcode project
cd ios && xcodegen generate

# 3. Deploy Firebase backend
firebase deploy --only firestore:rules,firestore:indexes,storage,functions

# 4. Flip aps-environment for release
# In ios/MomAlarmClock.entitlements, change:
#   <string>development</string>  →  <string>production</string>
```

---

## Build / Signing

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Debug build succeeds | **PASS** | Verified 2026-04-14, zero errors |
| 2 | Release build succeeds | **TEST** | Requires GoogleService-Info.plist + real Team ID |
| 3 | Archive succeeds | **TEST** | Run after Release build passes |
| 4 | TestFlight upload succeeds | **TEST** | Upload via Xcode Organizer or `xcodebuild -exportArchive` |
| 5 | App launches cleanly from TestFlight on real device | **TEST** | First real-device smoke test |

---

## Core Flows — Code Wiring Verification

All 12 core flows have been verified as properly wired in the codebase:

| # | Flow | Wired | Key Files |
|---|------|-------|-----------|
| 1 | Guardian signup/sign-in | YES | AuthService.signUpAsParent, ParentAuthView |
| 2 | Child pairing with join code | YES | AuthService.joinFamily, ChildPairingView |
| 3 | Join code share | YES | ShareLink in ParentAuthView + FamilySettingsView |
| 4 | Join code single-use | YES | Firestore rules mark code as used |
| 5 | Alarm schedule saves correctly | YES | ParentViewModel.saveAlarmSchedule → SyncProtocol |
| 6 | Alarm fires on time | YES | UNCalendarNotificationTrigger with repeats:true |
| 7 | Alarm creates exactly one session | YES | MorningSession.deterministicID + duplicate guard |
| 8 | Child verification works | YES | ChildViewModel.completeVerification → state transition |
| 9 | Guardian approve/deny/escalate | YES | ParentViewModel approve/deny/escalateSession |
| 10 | Denial returns child to verification | YES | PendingReviewView shows "Verify Again" NavigationLink |
| 11 | Hybrid review window | YES | Cloud Function sets reviewWindowEndsAt, rules enforce |
| 12 | Push notification for pending review | YES | Cloud Function + PENDING_REVIEW category + APPROVE/DENY actions |
| 13 | Push action buttons work | YES | AppDelegate handles actions → .guardianNotificationAction |
| 14 | Offline queue + sync | YES | LocalStore.appendToQueue + NetworkMonitor.drainOfflineQueue |
| 15 | Diagnostics export | YES | DiagnosticsView.exportDiagnostics → pasteboard |
| 16 | Delete account | YES | AuthService.deleteAccount (Firebase Auth + Firestore + local) |

---

## Voice Alarm

| # | Item | Wired | Notes |
|---|------|-------|-------|
| 1 | Guardian can record | YES | VoiceRecorderView with AVAudioRecorder |
| 2 | Guardian can preview | YES | Playback in VoiceRecorderView |
| 3 | Guardian can save/upload | YES | Firebase Storage at families/{fid}/children/{cid}/voiceAlarm/ |
| 4 | Child downloads and caches | YES | VoiceAlarmCacheService (actor) |
| 5 | Cached clip plays on alarm fire | YES | VoiceAlarmPlayerService referenced in ChildViewModel |
| 6 | Fallback when clip missing | YES | Falls back to system notification sound |
| 7 | Child cannot upload voice clip | YES | Storage rules: only parent role can write |
| 8 | Non-family account cannot read clip | YES | Storage rules: familyID must match |

---

## Safety / Privacy

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | No sensitive data in analytics/logs | OK | logError() logs only function name, familyID, sessionID, error message |
| 2 | No join code in diagnostics export | **VERIFY** | Manual check: run diagnostics export and confirm no join code in output |
| 3 | No message bodies in push logs | OK | pushLog writes only: type, sessionID, dedupKey, success, error, timestamp |
| 4 | Delete account copy explains what's deleted | OK | "This permanently deletes your account and sign-in credentials. Your family data will be removed." |
| 5 | PrivacyInfo.xcprivacy present | OK | Declares: UserDefaults, email, name, audio, coarse location. Tracking: false |
| 6 | All privacy usage descriptions in Info.plist | OK | Camera, Location (WhenInUse + Always), Motion, Photos, Microphone |

---

## Real-Device Tester Script

### Devices Needed
- 1 guardian device (iPhone, iOS 17+)
- 1 child device (iPhone, iOS 17+)
- Both on the same Wi-Fi initially; later tests require airplane mode on child device

---

### Test 1: First-Time Setup

**Guardian device:**
1. Install app from TestFlight
2. Tap "I'm a Guardian"
3. Enter name, email, password → Create Account
4. Note the family join code displayed
5. Tap **Share** (share sheet should appear) or **Copy**

**Child device:**
1. Install app from TestFlight
2. Tap "I'm a Child"
3. Enter the join code from guardian
4. Enter child's name → Join Family

**Pass criteria:**
- [ ] Child joins the correct family
- [ ] Guardian dashboard shows the child's name and "Paired" status
- [ ] No errors, loading spinners that never resolve, or stuck states
- [ ] Join code cannot be reused (try entering it on a third device — should fail)

---

### Test 2: Strict Morning Flow

**Guardian device:**
1. Tap the child → "+" to add alarm
2. Set time to **2–3 minutes from now**
3. Primary method: **Quiz** (or Math)
4. After Verification: **Require Guardian Approval** (strict)
5. Save alarm

**Child device:**
1. Wait for the alarm notification
2. Confirm alarm fires (sound + notification)
3. Open app → Tap "I'm Awake — Verify"
4. Complete the quiz verification
5. Should see "Waiting for Guardian" screen

**Guardian device:**
1. Confirm push notification arrives ("Verification Pending")
2. Open the pending review
3. Confirm verification proof is shown (quiz score, timestamp)
4. Tap **Approve**

**Pass criteria:**
- [ ] Session is created exactly once (no duplicates in History)
- [ ] Child reaches "Waiting for Guardian" state after verification
- [ ] Guardian receives push notification for pending review
- [ ] Approval updates child's screen immediately (shows "Approved!" with green checkmark)
- [ ] Session ends cleanly (child returns to idle after ~5 seconds)
- [ ] Stats update: streak, points visible on child's idle screen

---

### Test 3: Deny Flow

Repeat Test 2 setup (strict alarm, 2–3 min from now).

**Guardian device:**
1. When pending review arrives, tap **Deny**
2. Enter a reason (e.g., "Please try again")

**Child device:**
1. Confirm denial reason appears on screen
2. Confirm "Verify Again" button is visible
3. Tap "Verify Again" and complete verification
4. Wait for guardian to approve this time

**Guardian device:**
1. Approve the retry

**Pass criteria:**
- [ ] Child sees denial reason clearly
- [ ] Child is returned to verification (not stuck)
- [ ] Guardian can approve after child retries
- [ ] History shows the denial + subsequent approval

---

### Test 4: Push Action Buttons

Create another strict session (same setup as Test 2).

**Run A — Approve from notification:**
1. When push arrives on guardian device, long-press the notification
2. Tap **Approve** directly from the notification
3. Verify child's state updates without opening the app

**Run B — Deny from notification:**
1. Repeat with a new session
2. Long-press push notification → tap **Deny**
3. Verify child sees denial

**Pass criteria:**
- [ ] Approve action works from notification without opening app
- [ ] Deny action works from notification without opening app
- [ ] Child state updates correctly in both cases
- [ ] No duplicate actions (action only fires once)

---

### Test 5: Offline Queue

**Setup:** Create a strict alarm on guardian device.

**Child device:**
1. Wait for alarm to fire
2. Open app, see the active alarm screen
3. **Turn on Airplane Mode** before starting verification
4. Confirm offline banner appears ("Offline: actions will sync when online")
5. Complete verification while offline
6. **Turn off Airplane Mode**

**Pass criteria:**
- [ ] App shows offline state clearly (gray banner at top)
- [ ] Verification completes locally without crash
- [ ] Action is queued (no error shown to child)
- [ ] Queue drains when connectivity returns
- [ ] Guardian eventually receives the pending review
- [ ] Child and guardian states converge to the same final state

---

### Test 6: Voice Alarm (if enabled)

**Guardian device:**
1. Navigate to child's profile → Voice Alarm
2. Record a short clip (e.g., "Time to wake up!")
3. Preview playback — confirm it sounds correct
4. Save/upload

**Child device:**
1. Set an alarm that should use the voice clip
2. Wait for alarm to fire
3. Confirm the voice clip plays instead of the default sound

**Guardian device:**
1. Delete the voice clip

**Child device:**
1. Trigger another alarm
2. Confirm fallback to default alarm sound (no crash)

**Pass criteria:**
- [ ] Guardian can record, preview, and upload
- [ ] Child hears the voice clip on alarm fire
- [ ] Removing the clip gracefully falls back to default sound
- [ ] No crash when cached clip is missing

---

### Test 7: Account Deletion

**Guardian device:**
1. Go to Settings → Delete Account
2. Read the confirmation dialog
3. Tap "Delete Everything"

**Pass criteria:**
- [ ] Confirmation clearly states what will be deleted
- [ ] App returns to the login/signup screen after deletion
- [ ] Attempting to sign in with the same credentials fails
- [ ] Child device loses connection to the family (session becomes orphaned or child is signed out)

---

### Test 8: First Celebration (one-time)

This triggers on the child's **first-ever approved verification**.

**Child device (fresh install or cleared storage):**
1. Complete Test 2 flow for the first time
2. When guardian approves, watch for confetti animation

**Pass criteria:**
- [ ] Confetti emoji animation appears with "First Wake-Up Complete!" banner
- [ ] Animation auto-dismisses after ~4 seconds
- [ ] Does NOT appear on subsequent approvals

---

## Deployment Sequence

```
1. firebase deploy --only firestore:rules,firestore:indexes
2. firebase deploy --only storage
3. cd functions && npm install && firebase deploy --only functions
4. Verify functions deployed: firebase functions:list
5. Update DEVELOPMENT_TEAM in project.yml
6. Add GoogleService-Info.plist to ios/MomAlarmClock/
7. Change aps-environment to "production" in entitlements
8. xcodegen generate
9. xcodebuild archive ...
10. Upload to TestFlight
11. Run tester script on real devices
```

---

## Critical Blockers (Must Fix Before TestFlight)

| # | Blocker | Fix |
|---|---------|-----|
| 1 | GoogleService-Info.plist missing | Download from Firebase Console |
| 2 | DEVELOPMENT_TEAM is placeholder | Set real Apple Team ID in project.yml |
| 3 | ~~aps-environment is `development`~~ | ~~Change to production~~ (DONE — verified by pre-archive-check.sh) |
| 4 | Firebase backend not deployed | Run deploy commands above |
| 5 | Firebase Auth providers not enabled | Enable Email/Password + Anonymous in Firebase Console |
| 6 | APNS key not uploaded | See `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` Part 1 |
| 7 | Critical Alerts entitlement not requested | See `APNS_AND_ENTITLEMENTS_PLAYBOOK.md` Part 2 |

---

*Generated 2026-04-14. All code paths verified against codebase. Runtime behavior requires real-device testing per the tester script above.*
