# DEFERRED.md — Marathon Session Deferred Items

## [R0-001] StatsService duplicates RewardEngine reward logic
- **Severity:** P1
- **Found in:** Round 0
- **Assigned to:** Future (not safe overnight)
- **Reason deferred:** Consolidating would change aggregate reward calculation behavior. StatsService.computeRewardPoints sums points across history; RewardEngine calculates per-session. Replacing one with the other would shift dashboard totals. Requires daytime review with before/after comparison.
- **Notes:** Both functions work correctly for their respective purposes. The risk is rubric divergence over time, not a current bug.

## [R0-002] Firestore rules content integrity unverified
- **Severity:** P1
- **Found in:** Round 0
- **Assigned to:** Round 1
- **Reason deferred:** Needs verification in security round.
- **Notes:** Rules file was previously corrupted by lean-ctx hook (rewritten to 18 lines). Current file is 180 lines — verify content is complete.

## [C2-R2-001] observeParentAction loops on deleted session
- **Severity:** P2
- **Found in:** Cycle 2, Round 2
- **Assigned to:** Future
- **Reason deferred:** Changing async stream behavior is risky overnight. The continue prevents crashes, and the Task gets cancelled when the view disappears. Not a user-visible bug.
- **Notes:** If session doc is deleted from Firestore, observeSession yields nil repeatedly. The loop continues but doesn't crash. Fix: add a timeout or nil-count limit.

## [C2-R2-002] VoiceAlarmCacheService has no download timeout
- **Severity:** P2
- **Found in:** Cycle 2, Round 2
- **Assigned to:** Future
- **Reason deferred:** Firebase Storage writeAsync uses URLSession defaults (60s timeout). Adding explicit timeout requires wrapping the call which could introduce bugs. Not worth the risk overnight.
- **Notes:** The default URLSession timeout (60s) is acceptable for a ≤30s audio file. If network is very slow, the download will eventually time out on its own.
