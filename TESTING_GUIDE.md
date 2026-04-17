# Mom Alarm Clock — Testing Guide

**Version:** 1.0
**Last updated:** April 16, 2026
**Build:** Debug (Firebase production backend)

---

## What's Running

Two iOS simulators are active:
- **iPhone 17 Pro** (Guardian device)
- **iPhone 17e** (Child device)

Both connect to a **real Firebase backend** (`mom-alarm-clock` project). Data syncs between devices in real-time via Firestore listeners. Cloud Functions handle rewards, push notifications, and weekly summaries.

---

## Quick Start Testing (10 minutes)

### Scenario 1: Full End-to-End Flow

**Guardian device (iPhone 17 Pro):**
1. Tap **"I'm the Guardian"**
2. Tap **"Create Account"** path (or use Sign in with Apple if you have a test Apple ID)
3. Fill form:
   - First Name: `TestGuardian`
   - Email: `test+1@yourdomain.com` (use a real email for verification)
   - Password: `TestPass1234`
4. Tap **Create Account**
5. If using email, check your inbox, click the verification link, return to app, tap **"I've Verified My Email"**
6. Once on Dashboard, tap **"Add Child"**
7. Fill: Name = `Emma`, Age = `10`
8. Tap **Add Child** — you'll see the Pair Device screen with a join code
9. **Copy the join code** — you'll need it next

**Child device (iPhone 17e):**
10. Tap **"I'm the Child"**
11. Enter: Name = `Emma`, then the join code from step 9
12. Tap **Join Family**
13. Allow notifications when prompted

**Back on Guardian:**
14. Tap **"+"** or **Done** → tap the **"+"** to create an alarm
15. Set time to 2 minutes from now
16. Keep defaults: Wake-Up Quiz, Trust Mode
17. Tap **Create Alarm**

**Expected:**
- Child device should now show the alarm ("2 minutes" / "School Days")
- When the alarm fires, tap **"I'm Awake — Verify"** on child side
- Solve the quiz
- Child sees "You did it!"
- Points increment on both devices

---

### Scenario 2: Rewards Customization (NEW)

**Guardian:**
1. From Dashboard, tap **Rewards** under Quick Actions
2. You'll see 5 default rewards + current points (0)
3. Tap the **"Extra 30 min Screen Time"** reward
4. Change name to `Ice cream after dinner`, points to `30`
5. Tap an icon (ice cream, treat, etc.)
6. Tap **Save**

**Expected:** Reward updates immediately. "Using defaults" label disappears from the header.

7. Tap **"+ Add Reward"**
8. Create: `YouTube time`, 75 points, gamecontroller icon
9. **Save**
10. **Swipe left** on any reward → **Delete**

**Expected:** All changes persist. Sign out → sign back in → rewards still there.

---

### Scenario 3: Persistence & Sign-Out

1. As guardian, create an account + add child + create alarm
2. Go to **Settings** (gear icon) → **Sign Out** → **Confirm**
3. You'll see **"Welcome back"** on the landing page (remembers your role)
4. The Guardian Sign In form opens automatically
5. Sign in with the same email/password

**Expected:**
- Sign-in succeeds
- Dashboard loads with your child + alarm intact
- Rewards are still your customized versions

---

### Scenario 4: Child Settings (NEW)

**Child device:**
1. After pairing, tap the **gear icon** in top-right
2. You'll see:
   - My Profile (name, age, age group)
   - My Stats (streak, best streak, points, on-time count)
   - How Points Work (full breakdown)
   - About (version, build)
   - **Sign Out** button (red)

**Expected:** Signing out returns to landing page. Re-entering the join code (within 24 hours) re-pairs successfully.

---

### Scenario 5: Input Validation

**Guardian Registration:**
- Tap **Create Account** with all fields empty → all 3 errors appear inline
- Enter email `notanemail` → "Enter a valid email address."
- Try password `abc` → "Password must be at least 8 characters."
- Try `abcdefgh` → "Password needs at least one uppercase letter."
- Strength indicator: `abcdefgh` = Weak, `AbcdefG1` = Medium, `Abcdef123!X` = Strong

**Child Pairing:**
- Empty fields + **Join Family** → inline errors
- Join code `INVALID` → "Join code must be exactly 10 characters."
- Join code `IIIIIIIIII` → "Join code uses only letters A-Z (except I, O) and numbers 2-9."
- Auto-format: lowercase input becomes uppercase, spaces stripped, limit 10 chars

---

## Features Checklist

### Guardian
- [x] Register with email + password (with verification)
- [x] Sign in with Apple (requires real Apple ID)
- [x] Sign out / sign back in (remembered role)
- [x] Add up to 4 children
- [x] Join code (10 chars, Copy + Share buttons)
- [x] Create alarm (time, days, method, policy)
- [x] Advanced settings (difficulty, snooze, escalation)
- [x] Skip tomorrow
- [x] Tomorrow overrides
- [x] Voice alarm recording
- [x] **Rewards — edit, add, delete** (NEW)
- [x] Settings (Privacy & Data, How It Works, Delete Account)
- [x] Diagnostics (DEBUG builds)

### Child
- [x] Pair via join code
- [x] Welcome screen with "How It Works"
- [x] Alarm ringing screen with "Good morning!"
- [x] Quiz verification (age-aware difficulty)
- [x] Motion verification (step counter)
- [x] Result: "You did it!" with streak + points
- [x] Celebration overlay (first-ever verification + streak milestones at 3/7/14/30 days)
- [x] **Settings (gear icon)** (NEW): profile, stats, points breakdown, sign out
- [x] Notifications-off warning banner (NEW)

### Backend (Firebase — live)
- [x] Auth: Email/Password + Anonymous + Apple
- [x] Firestore (8 collections, role-based rules)
- [x] Storage (voice alarms)
- [x] App Check (App Attest)
- [x] **8 Cloud Functions deployed:**
  - `applyRewardOnVerified` — server-authoritative rewards
  - `setReviewWindowDeadline` — hybrid policy enforcement
  - `notifyParentOnPendingReview` — push for Strict Mode
  - `notifyParentOnTamperEvent` — push for tamper alerts
  - `clearOverridesOnSessionComplete` — auto-clear tomorrow overrides
  - `cleanupOldSessions` — retention cap at 500/child
  - `cleanupOldTamperEvents` — retention cap at 2000/child
  - `weeklySummary` — Sunday 6 PM Eastern digest

---

## Known Limitations

| Area | Status |
|------|--------|
| QR code verification | Hidden from launch (placeholder scanner) |
| Geofence verification | Hidden from launch (no map picker yet) |
| Multi-parent / co-parenting | Deferred to v1.1 |
| Real-time motion verification | Requires physical device pedometer |
| Cross-device push notifications | Requires APNs key upload (check Firebase Console) |
| Critical Alerts | Requires separate Apple entitlement approval |

---

## If Something Breaks

1. **App won't launch** → Check build succeeded: `xcodebuild ... build`
2. **Data missing** → Firebase may be rate-limited. Wait 30s and pull-to-refresh the dashboard.
3. **Cross-device sync not working** → Verify both simulators have the real `GoogleService-Info.plist` (not placeholder). Check Firebase Console → Firestore → see if writes appear.
4. **Alarm didn't fire** → Check Child device Settings > Notifications > Mom Alarm Clock. Simulator can't fire scheduled alarms while in background — bring the app to foreground near alarm time.
5. **Sign-in fails with "Invalid email or password"** → Check the email is verified. Look for verification link in your inbox.

---

## Firebase Console

https://console.firebase.google.com/project/mom-alarm-clock

Check:
- **Authentication** → See all registered users
- **Firestore Database** → Live data in families, users, familyCodes, sessions
- **Storage** → Voice alarm uploads
- **Functions** → Execution logs for each function
- **App Check** → Should show "Unenforced" initially (switch to Enforced after beta)

---

## Next Steps After Testing

1. Report any bugs found
2. If all 5 scenarios pass, you're ready for **TestFlight submission**
3. Before submission:
   - Replace `DEVELOPMENT_TEAM` in `ios/project.yml` with your Apple Team ID
   - Upload APNS .p8 key to Firebase Console (for push notifications on real devices)
   - Change `aps-environment` to `production` in entitlements (if not already)
   - Request Critical Alerts entitlement from Apple

Full release checklist: [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
