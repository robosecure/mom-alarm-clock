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

### [D-006] Child removal leaves orphan documents in Firestore
- **Risk:** Medium (billing + GDPR)
- **Issue:** `ParentViewModel.removeChild()` removes the child locally but does not call `syncService.deleteChildProfile()`. Related alarms, sessions, and tamper events for that child are not cascaded — they remain in Firestore forever.
- **Why architectural:** The right fix has a server-side counterpart. Options:
  1. Add `SyncService.deleteChildProfile(childID, familyID)` that runs a client batch delete for children/alarms/sessions/tamperEvents. Feasible but racy if the child device has a queue in-flight.
  2. Cloud Function triggered on `families/{fid}/children/{cid}` delete that cascade-deletes the subcollections server-side. Safer against client clock skew and offline deletes.
- **Mitigation:** Guardian account deletion still cascades the whole family correctly (see AuthService). Orphan risk is only for partial child removal (rare in v1.0).
- **Target:** v1.1 (propose as Cloud Function `cleanupOnChildDelete`)

---

## Resolved

### [D-R001] Firestore rules integrity — RESOLVED
- 22 rules tests verify role isolation, field permissions, state machine, version guards, hybrid window.

### [D-R002] StatsService / RewardEngine duplication — RESOLVED
- RewardEngine (client, optimistic) and applyRewardOnVerified (server, authoritative) both use rubric v1. Server wins on conflict. Separate by design.

### [D-R003] Firestore rules file corruption — RESOLVED
- File was previously corrupted by lean-ctx hook. Current file is 182 lines, verified complete.
