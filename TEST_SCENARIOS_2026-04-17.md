# Mom Alarm Clock — Fresh Test Scenarios
Date: 2026-04-17 · Simulator: iPhone 17 Pro (iOS 26.4) · Build: Debug, CODE_SIGNING_ALLOWED=NO · No Apple ID / offline-first LocalSyncService

These go **beyond** the original scenarios 1–5 (first-launch onboarding, pair parent+child, set alarm, child solves verification, parent approves extension). They target the code paths most likely to regress and are executable on the simulator alone.

---

## A. Verification Flow Variants

**A1. Quiz: wrong-then-right.** Child gets alarm, enters quiz, submits wrong answer, sees feedback, retries within maxAttempts, gets it right, alarm silences. Confirms `attemptsOnCurrentQuestion` resets per question and `totalAnswerTime` accumulates.

**A2. Quiz: all attempts exhausted.** Submit wrong answers until `maxAttempts` (default 3) hit on a question. Expect advance with "wrong" credit, not lockout. Confirm `quizCorrectCount < quizQuestions.count` → `completionView` shows "Not quite!" and offers new questions.

**A3. Quiz: timer expiration.** Let the 45s timer run out on question 1. Expect "Time's up!" feedback (orange), auto-advance, `totalAnswerTime += limit`. Critically: verify only ONE timer is active after advance (we just changed this area in Fix 3 territory — watch for duplicate ticks).

**A4. Photo verification happy path.** Escalate to photo tier; child captures photo of configured target; submit; parent sees pending review in VerificationReviewView.

**A5. Photo verification rejection.** Parent opens VerificationReviewView, denies photo. Child sees "try again" state, not a soft-lock.

---

## B. Escalation Timer & Snooze Rules

**B1. Snooze → re-fire.** Child snoozes alarm, timer counts down the snoozeSeconds window, alarm re-fires. Confirm no duplicate fires and snoozeCount increments.

**B2. Snooze cap.** Hit `maxSnoozes`. Next snooze button should be disabled or produce an error path that escalates verification tier, not a no-op.

**B3. Escalation tier bump.** Let escalation timer elapse without verification. Tier should bump from `standard` → `elevated` → `maximum`. Confirm quizQuestions get regenerated with harder config and photo/quiz mix updates.

**B4. Background → foreground mid-session.** Background the app during an active session, wait 20s, foreground. Session should still show correct timeRemaining, escalation tier should be preserved, and the Task.sleep banner loop should not show a phantom "Session expired" after our Fix 1.

---

## C. Parent Dashboard & Overrides

**C1. Approve session via in-app.** Parent taps Approve on a pending session. Child sees approved state within sync window.

**C2. Deny session via in-app.** Parent denies with reason. Child sees denial reason in `syncConflictMessage`.

**C3. Approve via notification action.** Simulate APPROVE userInfo payload via the NotificationCenter `.guardianNotificationAction` path (the block at `MomAlarmClockApp.swift:49`). Verify `parentVM.loadAllData()` runs if familyID is nil, then `approveSession(uuid)` fires.

**C4. Config override propagation.** Parent changes `timerSeconds` from 45 → 30 in config. Child's next question uses new limit (`vm.effectiveConfig?.timerSeconds`).

**C5. maxAttempts override.** Parent sets maxAttempts=1. Child's next quiz should advance after a single wrong answer.

---

## D. Tamper Detection

**D1. Volume silence.** Lower ringer volume to 0 during active session. Expect `TamperEvent.volumeMuted` reported (severity medium/high per config).

**D2. Notification permission revoked.** Deny notifications in Settings mid-session. `permissionCheckTimer` should fire a `permissionRevoked` event.

**D3. Timezone shift.** In Settings → General → Date & Time, flip to manual and change timezone. Expect `timeZoneChanged` event with the **new** identifier (Fix 2: we capture `tzID` synchronously on the posting thread — verify the reported detail matches the timezone you set, not the previous one).

**D4. Airplane mode drain.** Toggle airplane mode on before a session event, perform actions, toggle off. NetworkMonitor.drain should replay queued ops. If an op 401s, `onSessionRejected` should re-fetch authoritative state.

**D5. Tamper service double-start defense.** Kill app from App Switcher, relaunch, let a session start. `guard !isMonitoring else { return }` should prevent duplicate observers.

---

## E. Offline / Sync Edge Cases

**E1. Create session offline, drain on reconnect.** Airplane mode on → start alarm → verify locally → airplane off. Queue should drain, server should accept.

**E2. Conflict resolution.** Start a session on child, approve on parent while both clients are online, observe both arriving at the same terminal state.

**E3. Auth expiration banner.** Force a 401 response (if possible in dev). After 10s, `connectivityBanner` should show "Session expired. Please restart…". Confirm the banner clears when `lastDrainAuthExpired` resets. (This is the Fix 1 loop — verify no stuck banner after our Task.sleep cancellation-safe change.)

**E4. Rapid background/foreground.** Toggle the app 5× in 10s. No duplicate Tasks, no crashed Observers, no leaked timers. Check memory graph if time permits.

---

## F. Diagnostics, Sign-out, Account Deletion

**F1. Diagnostics export.** From parent settings, export diagnostics bundle. Confirm it writes a JSON/zip, shareable via activity controller, and does not leak child PII beyond what's documented.

**F2. Sign-out.** Sign out parent. Child on same device should be unaffected (separate role profile). Re-sign-in restores state.

**F3. Account deletion flow.** Trigger delete. Confirm double-confirmation UI, soft-delete local, and (in LocalSyncService) queue marker for server tombstone.

---

## G. Accessibility & UX

**G1. VoiceOver through quiz.** Rotate VoiceOver on. Quiz question is read, input is reachable, Submit button has label (`Submit answer`), feedback is announced.

**G2. Dynamic Type XXXL.** Set text size to accessibility-large. Confirm no truncated critical controls in ChildAlarmView, QuizVerificationView, ParentDashboard.

**G3. Dark mode toggle mid-session.** Flip dark mode during active alarm. No visual glitches, no white flash, tamper detection does NOT fire (appearance change is not tamper).

---

## H. Regression anchors (from prior fixes)

**H1. Fix 1 — App-launch timer leak.** Relaunch app 10× rapidly. Inspect memory; the `AsyncStream<Void>` Timer is gone; `Task.sleep` loop cleanly unwinds on scene disappear.

**H2. Fix 2 — Timezone observer MainActor hop.** Trigger D3 while app is foregrounded, and again while backgrounded (notification queue delivery). Captured `tzID` matches the actual system TZ at posting time.

**H3. Photo verification review.** The VerificationReviewView warnings (pre-existing) are just Swift 6 concurrency noise — verify the view still renders and Approve/Deny works in A4/A5.

---

## Execution checklist for today

- [ ] Tests re-run green (89+ cases)
- [ ] Scenarios A1, A3, B1, B3, C1, D3, E1, E3, H1, H2 (core 10) executed on simulator
- [ ] Any new bugs logged at bottom of this file

## Deferred (need Apple ID / physical device)

Photo camera capture with real camera, APNs push delivery, App Check attestation, Keychain migration on fresh install, TestFlight distribution.
