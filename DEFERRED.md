# DEFERRED.md — Known Issues Deferred Past v1.0

These are architectural or edge-case issues identified during development that are not launch blockers.

---

## Active Deferrals

### [D-001] Offline stale write divergence
- **Risk:** Medium
- **Issue:** Child completes verification offline, parent denies server-side before queue drains. Local state diverges.
- **Mitigation:** Firestore rules enforce version checking. NetworkMonitor classifies rejections and triggers session refresh.
- **Full fix:** Would require CRDTs or server-side merge logic.

### [D-002] observeParentAction loops on deleted session
- **Risk:** Low
- **Issue:** If session doc is deleted while child observes it, listener may loop.
- **Mitigation:** Error handling prevents crashes. Session deletion is rare (only via account deletion).

### [D-003] VoiceAlarmCacheService no download timeout
- **Risk:** Low
- **Issue:** Firebase Storage download has no explicit timeout beyond URLSession's 60s default.
- **Mitigation:** Fallback to standard alarm sound works. 60s default is acceptable for <=30s audio.

### [D-004] QR verification placeholder
- **Risk:** Low (hidden from launch)
- **Issue:** QR scanning uses simulated button, not DataScannerViewController.
- **Mitigation:** QR filtered out of method picker and tier availability. Not selectable in v1.0.
- **Target:** v1.1 (P-026)

### [D-005] Increased volume + parent call escalation
- **Risk:** Low (not in default profile)
- **Issue:** `increasedVolume` and `parentCallTriggered` enum cases exist but have no implementation.
- **Mitigation:** Marked `isLaunchReady: false`. Default profile uses only 4 launch-ready actions.
- **Target:** v1.1 (P-027)

### [D-006] Child removal leaves orphan documents in Firestore — RESOLVED
- **Risk:** Medium (billing + GDPR) — resolved
- **Fix:** Added `SyncService.deleteChildProfile(childID, familyID)` + `ParentViewModel.removeChild` now calls it. Server-side `exports.cleanupOnChildDelete` in `functions/index.js` is an `onDocumentDeleted` trigger on `/families/{fid}/children/{cid}` that cascades alarms, sessions, tamperEvents (paginated 200 per batch) and deletes the voice alarm Storage blob. `LocalSyncService.deleteChildProfile` mirrors the cascade locally so offline guardians don't leak orphans either.
- **Remaining:** deploy the Cloud Function (`firebase deploy --only functions:cleanupOnChildDelete`). Add a jest integration test alongside the existing retention tests.

---

## Resolved

### [D-R001] Firestore rules integrity — RESOLVED
- 22 rules tests verify role isolation, field permissions, state machine, version guards, hybrid window.

### [D-R002] StatsService / RewardEngine duplication — RESOLVED
- RewardEngine (client, optimistic) and applyRewardOnVerified (server, authoritative) both use rubric v1. Server wins on conflict. Separate by design.

### [D-R003] Firestore rules file corruption — RESOLVED
- File was previously corrupted by lean-ctx hook. Current file is 182 lines, verified complete.
