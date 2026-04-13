# Mom Alarm — Overnight Marathon Improvement Session

You are Claude Code working on the Mom Alarm Clock iOS app repo.

## Before anything else

Read the full repo structure and produce a file manifest with line counts. This grounds all later work in real files — never reference a file you haven't confirmed exists.

## Mission

Run an overnight hardening session: Round 0 (baseline), then up to 4 rounds (security → bugs → refactor → docs). In each round, fix issues in small batches, validate, commit, and report. I will tell you to stop when I wake up.

By the end, the app is measurably better without scope creep: fewer bugs, simpler code, stronger security boundaries, clearer documentation.

---

## Non-negotiable constraints

- **No new features.** This is hardening/refinement only. Never introduce something "because it's cool."
- **Do not break core flows:**
  1. Parent + Child pairing across two devices
  2. Alarms fire reliably AND always create/update a MorningSession (idempotent session ID, no duplicates)
  3. Verification works (math/quiz); guardian approve/deny/escalate works; denial returns child to verify
  4. Offline queue drains idempotently; UI converges; rejection reasons are accurate
  5. Push notifications + diagnostics remain functional
  6. RewardEngine is server-authoritative; rewards apply exactly-once per session with audit trail
  7. Tomorrow overrides apply to next session only; auto-clear server-side; child cannot modify
  8. Guardian Voice Alarm (≤30s) works: record/preview/upload/delete, child caches offline, on alarm fire: session creation first → then voice playback → graceful fallback. Storage rules enforce guardian-only write, family-scoped read, size/type limits
- **Do not weaken** Firestore/Storage rules or security invariants.
- **Do not increase the warning count.** Record the baseline count in Round 0.
- **Every claim must reference exact file(s) changed.** No hand-waving.

---

## Model requirement: Opus 4.6 only — never downgrade

This session must run on Claude Opus 4.6 exclusively.

**Before each round**, run the token monitor script:

```bash
python3 /Users/wamsley/mom-alarm-clock/scripts/token_monitor.py --check
```

If the script reports **≥ 85% usage**, or if you detect/suspect the model has been downgraded to Sonnet:

1. **Stop immediately.**
2. Commit any uncommitted safe work: `git commit -m "RN: WIP — stopping for token reset"`
3. Write a `SESSION-PAUSE.md` file at the repo root containing:
   - Current round and step (e.g., "Round 2, Implement, batch 2 of 3")
   - What was just completed
   - What remains in the current round
   - Any in-flight changes that were NOT committed
4. **Do not continue working.** Do not attempt the next fix, the next round, or any "just one more thing."
5. Tell me: *"Opus token limit approaching. Session paused. See SESSION-PAUSE.md for resumption point. Waiting for token reset."*

When I return after the token reset, I will re-invoke this prompt. Read `SESSION-PAUSE.md` and `DEFERRED.md` to pick up exactly where you left off.

**Never let a lesser model continue this work. Partial progress with Opus is better than full progress with Sonnet.**

---

## Canary check

Pick this critical flow as the canary: **alarm firing → MorningSession created (idempotent, no duplicates)**. The canary test must pass after every batch, not just at round boundaries. If the canary fails, stop and fix it before continuing.

---

## Validation commands

Use these exact commands. Do not guess alternatives:

```bash
# Regenerate project + Build (MUST run xcodegen first — project uses project.yml)
cd /Users/wamsley/mom-alarm-clock/ios && \
xcodegen generate 2>&1 && \
xcodebuild build -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClock \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1

# Warning count (baseline in Round 0, then compare)
xcodebuild build -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClock \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  /usr/bin/grep -c "warning:"

# Unit tests
xcodebuild test -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClockTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1

# Firestore rules tests
cd /Users/wamsley/mom-alarm-clock/functions && npm install && npm run test:rules 2>&1
```

**Note:** 2-device smoke testing is manual and cannot be automated here. Where the prompt says "validate a flow," that means: confirm the code path builds, relevant unit/emulator tests pass, and you've traced the logic to confirm correctness. Do not claim you ran a multi-device test.

---

## Stuck/rollback rules

- If a build **fails twice consecutively** after your fixes, `git stash` or revert to the last green state and move on to the next item or round.
- Do not spend **more than 3 attempts** fixing a single issue. After 3 attempts, log it in `DEFERRED.md` and move on.
- If you find yourself in a loop (same error recurring), stop, document the issue in `DEFERRED.md`, and advance.

---

## Commit discipline

Git commit after each successful batch within a round. Use conventional commit messages prefixed by the round number:

```
R1: harden Firestore field validation for session documents
R2: fix DST edge case in alarm scheduling
R3: extract reward calculation into RewardEngine helper
R4: update SETUP.md with App Check rollout steps
```

---

## Time management

Spend roughly **60–90 minutes per round**. If a round's inventory is small, finish early and move on. If a round is running long, commit what's done, log the rest in `DEFERRED.md`, and advance.

---

## DEFERRED.md

Maintain a `DEFERRED.md` file at the repo root. Every deferred item gets:

```markdown
## [RN-###] Short title
- **Severity:** P0 / P1 / P2
- **Found in:** Round N
- **Assigned to:** Round N (or "Future")
- **Reason deferred:** [why it wasn't fixed now]
- **Notes:** [any context for the next session]
```

Each round should read `DEFERRED.md` at the start to check for items punted from earlier rounds.

---

## Cross-cutting rule

If a **P0 data-loss or security issue** is found outside the current round's focus, fix it immediately regardless of round boundaries. For anything P1 or below that crosses rounds, log it in `DEFERRED.md` with the appropriate round assignment. Do not use this escape hatch to rationalize scope creep.

---

## Definition of "done" for any change

- Builds cleanly (warning count ≤ baseline)
- Canary check passes
- Relevant tests pass (or you update them with clear justification)
- Docs updated if setup/behavior changed
- Committed with round-prefixed message

---

## ROUND 0 — Baseline

**Goal:** Prove the app currently builds and passes tests. Identify top risks before changing anything.

Do this:

1. Read repo structure, produce file manifest with line counts.
2. Build. Record the baseline warning count.
3. Run unit/emulator tests. Record pass/fail counts.
4. Run Firestore rules tests if configured.
5. Trace the canary flow (alarm → MorningSession) through the code and confirm the logic is sound.
6. Run token monitor to establish baseline usage.
7. Produce a "Baseline Findings" list:
   - 3 biggest risks
   - 3 easiest wins
   - Anything that must not be touched tonight
   - Pre-existing test failures (if any)

**Output — use these headings:**

```
## Round 0 — Baseline
1. File Manifest (summary — full manifest in separate file if large)
2. Build Result + Warning Count Baseline
3. Test Results (pass/fail counts)
4. Canary Flow Trace (sound / not sound + notes)
5. Token Usage Baseline
6. Top 3 Risks
7. Top 3 Easy Wins
8. Do-Not-Touch List
```

---

## Rounds 1–4: Marathon Structure

Each round follows this loop:

### 1) Inventory
- Scan repo for issues ONLY in this round's focus area.
- Read `DEFERRED.md` for items assigned to this round.
- Classify findings as P0 / P1 / P2.
- Select top 3–10 fixes that are safe and small.

### 2) Implement (small batch)
- Implement selected fixes, keep diffs tight.
- Add/adjust tests only where they prevent regressions.

### 3) Validate
- Build (confirm warning count ≤ baseline).
- Run canary check.
- Run relevant tests.
- Run token monitor — if ≥ 85%, pause immediately.
- For any touched flow, trace the logic to confirm correctness.

### 4) Commit
- `git commit` with round-prefixed message.

### 5) Report (keep it concise)

```
## Round N — [Focus Area]
1. Changes (file, what, why — one line each)
2. Validation (build: ✅/❌, canary: ✅/❌, tests: N passed / N failed, token usage: N%)
3. Deferred (logged in DEFERRED.md)
```

**That's it. Three headings. Don't spend tokens on ceremony.**

---

### Round 1 — Security + Correctness Enforcement

**Focus:**
- Firestore rules: field-level protections, state transitions, review window enforcement
- Storage rules: Voice Alarm access control, size/type constraints
- Cloud Functions: idempotency guards, dedupe, safe triggers (no re-entrant loops)
- App Check sanity (no accidental lockouts)
- Client spoof vectors
- Reward persistence: server-authoritative, applied exactly once per session

**Deliverables:**
- Updated rules/functions if needed
- Short security audit note (inline in report, not a separate doc)
- Extend emulator tests for new/changed invariants

---

### Round 2 — Bug Hunt + Reliability Hardening

**Focus:**
- Alarm scheduling edge cases (DST, time zone change, permission revoked, duplicates, drift self-heal)
- Session creation across paths (foreground vs. tap vs. backup reminder) and duplicate guards
- Offline queue: drain ordering, idempotency, rejection classification, convergence banners
- Push reliability: dedupe, token refresh, failure handling, diagnostics accuracy
- Voice Alarm reliability: cache invalidation/backoff, playback never blocks session, graceful fallback

**Deliverables:**
- Fixes + at least 3 new regression checks (unit tests, rules tests, or equivalent)

---

### Round 3 — Refactor + Simplification (NO behavior change)

**Focus:**
- Reduce duplication, remove dead code / unused flags
- Naming consistency (session states, fields, rule names)
- Consolidate sources of truth (RewardEngine, EffectiveVerificationConfig, deterministic ID generation)
- Simplify view models (extract helpers, reduce side effects)

**Deliverables:**
- Cleaner architecture, zero behavior changes
- Brief explanation of the most important refactors (2–3 sentences each)

---

### Round 4 — Documentation + Developer Ergonomics + Final Polish

**Focus:**
- Setup docs: Firebase, APNS/FCM, Storage, App Check rollout, rules/functions deploy, emulator tests
- "How to run" docs: diagnostics export, push debugging
- Release checklist (TestFlight → Prod) including App Check enforcement + rollback plan
- UI copy polish and honest limitations (best-effort tamper detection, iOS constraints)

**Deliverables:**
- Updated docs + release checklist

---

## After Round 4 — Final Pass

1. Full build + full test suite + canary check.
2. Compare warning count to baseline.
3. Review `DEFERRED.md` — if anything P0 remains, fix it now.
4. Run token monitor one final time.
5. Produce final summary:

```
## Final Summary

### Before vs. After
- Warning count: [before] → [after]
- Test count: [before] → [after]
- Key improvements: [bullet list]

### Launch Readiness Snapshot
- ✅ / ❌ Core flows confirmed
- ✅ / ❌ Security invariants confirmed
- ✅ / ❌ Docs updated
- ✅ / ❌ Tests passing
- ⚠️ Remaining risks (from DEFERRED.md) + suggested next wave

### Commits This Session
[list of commit messages]
```
