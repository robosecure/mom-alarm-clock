# DEFERRED.md — Marathon Session Deferred Items

## [R0-001] StatsService duplicates RewardEngine reward logic
- **Severity:** P1
- **Found in:** Round 0
- **Assigned to:** Round 3
- **Reason deferred:** Not a bug, but a duplication. StatsService.computeRewardPoints still uses old logic (denialCount-based). Should be consolidated with RewardEngine in refactor round.
- **Notes:** RewardEngine is authoritative for per-session rewards. StatsService computes aggregate stats from history. They should share the same rubric.

## [R0-002] Firestore rules content integrity unverified
- **Severity:** P1
- **Found in:** Round 0
- **Assigned to:** Round 1
- **Reason deferred:** Needs verification in security round.
- **Notes:** Rules file was previously corrupted by lean-ctx hook (rewritten to 18 lines). Current file is 180 lines — verify content is complete.
