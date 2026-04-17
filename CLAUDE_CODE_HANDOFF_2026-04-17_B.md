# Handoff for Claude Code — Mom Alarm Clock (2026-04-17, second pass)

Copy/paste everything below the line into Claude Code in VS Code.

---

You are picking up from an autonomous 2-hour testing/orchestration session. Here's where things stand.

## What's already done — DO NOT redo

1. **First Claude Code pass (earlier today)** — 9 bug fixes + `@MainActor` on ParentViewModel/AuthService. 0 Swift warnings achieved. See `SESSION_SUMMARY_2026-04-17.md` section "Claude Code continuation".
2. **Second Claude Code pass (visual/brand overhaul, just finished in VS Code)** — 55 files modified, 3,416 insertions / 1,943 deletions. Brand system: `design/icons/*.png` (all iOS app icon sizes 20→1024), `design/logos/logo-horizontal.svg`, `logo-mark.svg`, `launch-logo.svg`. Asset catalog populated: `ios/MomAlarmClock/Assets.xcassets/AppIcon.appiconset/`, `LaunchLogo.imageset/`, `AccentColor.colorset/`, `LaunchBackground.colorset/`. Plus substantial UI/UX updates across SetupWizardView, RewardStoreView (+224 lines), AlarmControlsView, ParentAuthView, AddChildView, AppDelegate, MomAlarmClockApp, and others. CoreLogicTests grew by ~399 lines. Firebase config entitlements updated. **All of this is currently uncommitted in the working copy** (`git status` shows 55 files modified + many new untracked files). Commits 59–76 (docs, launch checklist, P-016→P-020 proposals, monetization model, analytics events, privacy manifest, showcase rebuild) are already committed.
3. **Autonomous verification (just completed)** —
   - Fresh `./run_tests.sh` → **90/90 tests pass** (exit=0, 0.073s runtime), including the uncommitted brand/UI changes.
   - Build log has **0 code warnings** — only benign AppIntents metadata notes remain.
   - **H1 regression anchor PASS:** 10 rapid app relaunches on simulator CE8349D4 — app lands cleanly each time on the role picker, no crashes, steady RSS ~362MB / 2.2% CPU. The `AsyncStream<Void>` Timer leak fix is holding.
   - Simulator smoke: fresh install, launched cleanly, new brand (blue alarm clock with bells icon) renders correctly, role picker shows "I'm the Guardian / I'm the Child" with new copy. Screenshots saved: `core10_00_role_picker.png`, `core10_H1_after_10_relaunches.png`.

## What's blocked — the TestFlight path

Archive-to-TestFlight was attempted and **cannot complete autonomously** for structural reasons:

- `security find-identity -v -p codesigning` shows only **"Apple Development: Ross Mathews (A4RQ74YWKJ)"** — a **Development** cert. No **Apple Distribution** cert present.
- `~/Library/MobileDevice/Provisioning Profiles/` does not exist — zero profiles on this machine.
- Xcode earlier failed Archive with: *"Your team has no devices from which to generate a provisioning profile"* and *"No profiles for 'com.momclock.MomAlarmClock' were found"*.
- Team ID in Xcode: **U474UU36TW**. The Development cert's user ID **A4RQ74YWKJ** appears to be a separate membership — worth checking that these are the same Apple Developer account, because Xcode may be signed into a DIFFERENT Apple ID than the one that owns the Distribution cert/membership.

**Resolution path (requires human-in-loop):**

1. In Xcode → Settings → Accounts, verify the Apple ID signed in matches Team U474UU36TW and has an active paid Developer membership.
2. Click "Manage Certificates…" on that team and create an "Apple Distribution" (or "iOS Distribution") certificate if missing.
3. Register the bundle ID `com.momclock.MomAlarmClock` at https://developer.apple.com/account/resources/identifiers/list/bundleId if not already done.
4. In Xcode project → Signing & Capabilities, confirm "Automatically manage signing" is ON for the Release configuration and Team is U474UU36TW.
5. Product → Archive with "Any iOS Device (arm64)" as the run destination. Xcode will download the Distribution profile.
6. From Organizer: Distribute App → App Store Connect → Upload.

## Your job

### 1. Commit Claude Code's uncommitted work

The working copy has 55 modified files + 14 new untracked iOS source/asset files + 10+ new top-level docs. Review with `git diff --stat`, group into logical commits, and push. Suggested groups:

- **C77-ASSETS** — new brand assets under `design/` and `ios/MomAlarmClock/Assets.xcassets/` + `project.yml` update wiring AssetCatalog compiler and accent color.
- **C78-AUTH-UX** — `ParentAuthView.swift` (+150), new `EmailVerificationView.swift`, `AuthGateView.swift` changes, `ChildPairingView.swift` update, `AuthService.swift` and `MomAlarmClockApp.swift` tweaks.
- **C79-PARENT-UX** — `AlarmControlsView`, `AddChildView`, `FamilySettingsView`, `HistoryView`, `NextMorningSettingsView`, `ParentDashboardView`, `RewardStoreView`, `SetupWizardView`, `SetupWizardViewModel`, `VerificationReviewView`, `VoiceAlarmRecorderView` refreshes.
- **C80-CHILD-UX** — new `CelebrationOverlay.swift`, `ChildSettingsView.swift`, plus updates to `ChildAlarmView`, `PendingReviewView`, `QuizVerificationView`.
- **C81-MODELS-SERVICES** — new `AgeBand.swift`, `Reward.swift`, `InputValidation.swift`, model modifications, `StatsService`, `TamperDetectionService`, `HeartbeatService`, `BetaDiagnostics`, sync service tweaks, `LocalStore`, `VoiceAlarmCacheService`, etc.
- **C82-TESTS** — CoreLogicTests.swift grew by ~399 insertions.
- **C83-DOCS** — new root docs: `APP_REVIEW_NOTES.md`, `APP_STORE_METADATA.md`, `ENTITLEMENT_JUSTIFICATIONS.md`, `LAUNCH_CHECKLIST.md`, `PRIVACY_POLICY.md`, `PRIVACY_SUBMISSION_REFERENCE.md`, `SCREENSHOT_PLAN.md`, `TESTING_GUIDE.md`, `USER_GUIDE.md`, `TEST_SCENARIOS_2026-04-17.md`, `SESSION_SUMMARY_2026-04-17.md`, new build scripts.
- **C84-FIREBASE** — `.firebaserc`, `firebase.json`, `firestore.rules`, `functions/index.js`, `functions/package.json`, `functions/rules.test.js` updates.

If you'd rather ship it as one big commit `C77-OVERHAUL: brand system + comprehensive UX polish + docs`, that works too — but multi-commit is easier to revert.

### 2. Scan for bugs in the overhaul

I spot-checked a few flagged items from a Explore-agent review. Agent had ~70% false-positive rate because many flagged "`@State` on @Observable" findings misread how @Observable interacts with @State in iOS 17 (it's the recommended pattern, not a bug). The ones worth checking:

- **EmailVerificationView.swift:119-122** — `resendEmail()` spawns an inner `Task { try? await Task.sleep(for: .seconds(5)); resent = false }`. If the view is dismissed mid-sleep, the closure writes to the (dead) @State binding. Safe in practice (@State is backed by persistent storage), but if a new view instance takes over, you've got two 5s timers racing. Consider storing the Task as `@State private var resetTask: Task<Void, Never>?` and cancelling it in `onDisappear`.
- **PhotoVerificationView.swift:103-121** — `submitPhoto()` sets `isComplete = true; isSubmitting = false` BEFORE the `await vm.completeVerification(...)` call completes, which reverses the UX contract (UI shows "complete" before the ViewModel has actually processed). Move the state flips to AFTER the `await`, or gate them on the result.
- **Check EmailVerificationView.swift:24** — `Auth.auth().currentUser?.email` read directly in view body re-runs Firebase SDK call on every render. Cache in @State at `onAppear`.

Don't bother with the "missing `[weak self]` on a singleton actor's Task" findings — singleton actors don't deallocate, so those are noise.

### 3. Re-verify after commit

Run `./run_tests.sh` again. Expect 90/90. Build log should show 0 warnings (aside from AppIntents notes).

### 4. Execute the core 10 scenarios properly

Autonomous simulator-driving hit a wall: iOS long-press accent popups intercept keystrokes from the macOS keyboard when using the iOS simulator under computer-use, making text-entry flows (sign-up, pairing code, alarm time) unreliable. Options ordered by ROI:

- **Best:** Write minimal XCUITest cases for the core 10 scenarios. They become CI-scriptable. Put them under `ios/MomAlarmClockTests/` — the scheme and project are already in place. Start with A1 (quiz wrong-then-right), B1 (snooze), C1 (parent approve), D3 (timezone change).
- **Medium:** Use `xcrun simctl ui` + `simctl pbpaste`-based shortcuts for the text fields; you can paste instead of type to avoid the accent-popup issue.
- **Minimum:** Manual testing by the user once the Apple ID/signing is sorted out on a physical device via TestFlight.

Please draft the XCUITests regardless — they pay dividends forever.

### 5. What NOT to touch

- **Don't remove the `Continue mom-alarm-clock development` tab in VS Code.** Keep your conversation there active; the user is monitoring progress in both windows.
- **Don't try to create a Distribution cert or edit provisioning** autonomously — that's human-in-loop work per the blocker above.
- **Don't "fix" `@State private var vm = SetupWizardViewModel()`** on line 8 of `SetupWizardView.swift`. With `@Observable`, `@State` on a reference-type class IS the correct pattern (as of iOS 17). An earlier review flagged it as a bug; that was a misread.
- **Don't commit `/tmp/*.log` or DerivedData artifacts** — already in `.gitignore`, just noting.

### 6. When you're done

Update `SESSION_SUMMARY_2026-04-17.md` with a new "Autonomous + Claude Code pass 3" section listing:

1. Commits pushed (by hash) and what went in each.
2. Any new fixes you made on top of the overhaul.
3. Test result: X/Y (expected 90/90 or higher if you added XCUITests).
4. Swift warning count before/after your pass.
5. What's still blocked (Distribution cert, APNs .p8, Critical Alerts approval, first TestFlight build).

## Reference files

- `/Users/wamsley/mom-alarm-clock/SESSION_SUMMARY_2026-04-17.md` — full day's history
- `/Users/wamsley/mom-alarm-clock/TEST_SCENARIOS_2026-04-17.md` — 30+ scenarios
- `/Users/wamsley/mom-alarm-clock/DEFERRED.md` — [D-006] orphan cleanup + any others
- `/Users/wamsley/mom-alarm-clock/LAUNCH_CHECKLIST.md` + `/Users/wamsley/mom-alarm-clock/RELEASE_CHECKLIST.md`
- `/Users/wamsley/mom-alarm-clock/core10_00_role_picker.png`, `core10_H1_after_10_relaunches.png` — evidence screenshots

## Constraints

- Swift 6 strict concurrency target, `@Observable`, SwiftUI iOS 17+. Deployment target 17.0 in `project.yml`.
- XcodeGen generates the xcodeproj — edit `ios/project.yml` and run `xcodegen`, don't hand-edit the xcodeproj.
- Don't run concurrent xcodebuild processes — SPM cache gets corrupted (we lost 20 min to that earlier). `pkill -f xcodebuild` before a fresh run.
- Simulator UDID is hard-coded in `run_tests.sh`: **CE8349D4-210F-419E-A532-2882BB1C2037** (iPhone 17 Pro, iOS 26.4).

Good luck.
