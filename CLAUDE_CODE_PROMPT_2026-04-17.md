# Prompt for Claude Code — Mom Alarm Clock (2026-04-17 handoff)

Copy/paste everything below the line into Claude Code.

---

You are picking up from a testing session where we (a) ran the full automated suite on a simulator with no Apple ID (using `CODE_SIGNING_ALLOWED=NO`), (b) did a fresh static code review and fixed two real bugs, and (c) started on three Swift 6 compile-mode warnings (currently warnings, errors in Swift 6 language mode). The Apple ID will be back in Xcode in a few hours — use it for anything that needs real signing.

## Context files to read first

1. `/Users/wamsley/mom-alarm-clock/SESSION_SUMMARY_2026-04-17.md` — what was done today
2. `/Users/wamsley/mom-alarm-clock/TEST_SCENARIOS_2026-04-17.md` — 30+ scenarios, with the "core 10" checklist
3. `/Users/wamsley/mom-alarm-clock/PROPOSALS.md`, `LAUNCH_CHECKLIST.md`, `TESTING_GUIDE.md` — project-level docs

## What's already done (do NOT redo)

### Fixes applied today (verified by 90/90 tests passing)
- **`ios/MomAlarmClock/App/MomAlarmClockApp.swift:88-100`** — App-launch Timer leak. Was `AsyncStream<Void>` wrapping `Timer.scheduledTimer` (never invalidated). Replaced with a `while !Task.isCancelled { try? await Task.sleep(for: .seconds(10)) … }` loop.
- **`ios/MomAlarmClock/Services/TamperDetectionService.swift:144-163`** — Timezone-observer MainActor hop. Wrapped body in `Task { @MainActor in … }` and captured `TimeZone.current.identifier` synchronously on the posting thread so the reported TZ matches the moment of change.

### Swift 6 warning fixes started (NOT verified — tests not yet re-run)
- **`MomAlarmClockApp.swift:53`** — `Task {` → `Task { @MainActor in` on the `.guardianNotificationAction` handler, to stop sending `parentVM` across an unspecified actor.
- **`ios/MomAlarmClock/Persistence/LocalStore.swift`** — Removed `nonisolated` from `fileManager`/`encoder`/`decoder`. Converted `storeDirectory` from actor-isolated computed property to a stored `let` resolved in `init()` using a local `FileManager` so nonisolated init no longer touches actor-isolated state.
- **`ios/MomAlarmClock/Services/VoiceAlarmCacheService.swift:12`** — Removed `nonisolated` from `fileManager`; now lives on the actor.

**Verify these by running tests.** If any regress, fix and iterate. Do NOT revert these without reading what they replaced — the old code was compiling but had real issues (detailed in today's session summary).

### False positives confirmed today (do NOT "fix" these, they're already correct)
- `TamperDetectionService.startMonitoring()` already has `guard !isMonitoring else { return }` at line ~37 — earlier static-review agent flagged this as missing, it wasn't.

## What's pending (your job)

### 1. Verify today's fixes hold
- Run `./run_tests.sh` (synchronous) or `./launch_tests.sh` (background; tails `/tmp/mom_test.log`).
- Expected: 90/90 pass. Warnings in the build log should drop from 3 Swift-6-error-class to 0.
- If Swift-6 warnings remain, fix them — list them in your final report with file:line.

### 2. Execute the "core 10" UI scenarios from `TEST_SCENARIOS_2026-04-17.md`
A1, A3, B1, B3, C1, D3, E1, E3, H1, H2. Simulator is `CE8349D4-210F-419E-A532-2882BB1C2037` (iPhone 17 Pro, iOS 26.4). D3 and H2 specifically validate today's timezone-observer fix — do both foreground and background timezone flips.

### 3. Fresh static code review — second pass
Focus areas (based on today's pass, not already covered):
- **`ChildViewModel.swift:339`** — `try? await localStore.appendToQueue(...)` silently swallows queue-persistence failures. If the offline queue itself can't write, the user loses the action with no signal. Propose and apply a fix (surface via `syncConflictMessage` or a diagnostics event).
- **`AppDelegate.swift:83`** — `requestAuthorization` callback only `print`s on error/denial. No UX path to re-prompt or surface "you need to enable notifications for alarms to work." Fix: write granted/denied to a published state that SetupWizard or a banner can read.
- **`ChildViewModel.escalationTimer`** and **`TamperDetectionService`** have no `deinit` cleanup. On `@Observable` classes this is usually fine because they're long-lived singletons, but confirm — if any instance is created per-session, a leak is possible. Audit and add `deinit { stopMonitoring() }` where appropriate.
- **`QuizVerificationView.swift:125`** — `Timer.scheduledTimer` block references `@State` (`questionStartTime`, `timeRemaining`, `questionTimer`, `vm`, `userAnswer`, `feedback`, `feedbackColor`, `totalAnswerTime`) and calls `startQuestionTimer()`. Under Swift 6 this closure is a non-isolated `Sendable` context. Runs on main runloop at runtime so it works, but the compiler will error in Swift-6 mode. Fix: capture the View's state management differently or wrap the block body in `MainActor.assumeIsolated`.
- **`VoiceAlarmRecorderView.swift:176`** — same `Timer.scheduledTimer` pattern; same fix.
- **`ParentViewModel.swift:159`** — orphan-cleanup in Firestore is architectural. Propose the server-side counterpart in a GitHub-ready description; don't try to fix unilaterally.

Plus: scan for new issues you find on this pass. Read the code, don't just take my word for it.

### 4. Apple-ID-gated work (once password arrives)
- Re-sign Debug with your Team Identifier, install on simulator AND a physical device if paired, confirm no signing errors.
- APNs push delivery (real remote push, not just the NotificationCenter hop in `MomAlarmClockApp.swift:49`).
- App Check attestation — verify `APP_CHECK_ROLLOUT.md` steps.
- Keychain migration on fresh install (first-launch delete `~/Library/Keychains/` entries via `xcrun simctl keychain reset` and confirm app recovers).
- TestFlight upload rehearsal (do NOT actually submit to App Store; just confirm the archive succeeds and passes App Store validation).

**Do NOT** use the Apple ID for anything the user hasn't explicitly asked for — no App Store submissions, no new certificates, no device provisioning churn.

## Constraints and conventions

- SwiftUI + `@Observable`, Swift 6 strict concurrency target.
- XcodeGen generates the project from `ios/project.yml`. If you need to touch the project file, edit the yaml and run `xcodegen` — do NOT hand-edit `MomAlarmClock.xcodeproj`.
- Firebase is opt-in via `GoogleService-Info.plist` API_KEY — if the placeholder is present, `SyncServiceFactory` falls back to `LocalSyncService`. This is intentional; don't "fix" it.
- Tests live in `ios/MomAlarmClockTests/CoreLogicTests.swift`. When you add behavior, add tests.
- Background xcodebuild via `run_tests.sh` / `launch_tests.sh` / `resolve_packages.sh` / `launch_resolve.sh` (logs to `/tmp/mom_*.log`). These scripts use the iPhone 17 Pro simulator UDID hard-coded.
- **No concurrent xcodebuild runs.** Today we lost ~20 minutes to an abseil SPM clone that failed because two xcodebuild processes hit the SPM cache at once. `pkill -f xcodebuild` before starting any fresh build if you've launched one recently.

## Deliverables

When done, update `SESSION_SUMMARY_2026-04-17.md` (append a new "Claude Code continuation" section) with:
1. List of bugs fixed (file:line + 1-line summary each)
2. Swift 6 warning count before/after
3. Test result: X/Y pass
4. UI scenarios: pass/fail per scenario with any captured screenshots in the repo root
5. Any new bugs discovered and whether fixed or logged as follow-up
6. State of Apple-ID-gated work (done, blocked, deferred)

Report back with a short summary when the above file is updated.
