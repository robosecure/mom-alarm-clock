# Firestore Rules Validation Checklist

Manual bypass tests to verify security invariants. Run these against the Firebase Emulator or live project using the Firebase Console's Rules Playground.

## How to Test

1. Open Firebase Console > Firestore > Rules Playground
2. Set the auth UID and custom claims as specified
3. Attempt the operation
4. Verify the expected result (ALLOW / DENY)

---

## Test 1: Child cannot write parent-only fields on session

**Setup:** Auth as child user in family X
**Operation:** Update `families/{familyX}/sessions/{sid}`
**Payload:** `{ "parentAction": { "approved": {} }, "state": "verified" }`
**Expected:** DENY (parentAction is in parentOnlyFields)

## Test 2: Child cannot set state to cancelled

**Setup:** Auth as child user
**Operation:** Update session with `{ "state": "cancelled" }`
**Expected:** DENY (child cannot transition to cancelled)

## Test 3: Child cannot escalate role to parent

**Setup:** Auth as child user with existing `users/{uid}` doc where role=child
**Operation:** Update `users/{uid}` with `{ "role": "parent" }`
**Expected:** DENY (role must equal resource.data.role)

## Test 4: Child cannot change familyID

**Setup:** Auth as child user
**Operation:** Update `users/{uid}` with `{ "familyID": "differentFamily" }`
**Expected:** DENY (familyID must equal resource.data.familyID)

## Test 5: Parent cannot deny after hybrid window expires

**Setup:** Auth as parent user. Session has `state: "verified"`, `reviewWindowEndsAt: <past timestamp>`
**Operation:** Update session with `{ "state": "verifying", "parentAction": { "denied": { "reason": "test" } } }`
**Expected:** DENY (request.time > reviewWindowEndsAt)

## Test 6: Child cannot create join codes

**Setup:** Auth as child user
**Operation:** Create `familyCodes/{code}` with `{ "familyID": "x", "createdAt": ..., "createdBy": uid, "expiresAt": ... }`
**Expected:** DENY (getUserData().role must be 'parent')

## Test 7: Version guard prevents state regression

**Setup:** Session exists with `version: 5`
**Operation:** Update session with `{ "version": 4, "state": "verifying" }`
**Expected:** DENY (version must be >= existing)

## Test 8: Tamper count cannot decrease

**Setup:** Session exists with `tamperCount: 3`
**Operation:** Update session with `{ "tamperCount": 1 }`
**Expected:** DENY (tamperCount must be >= existing)

## Test 9: Cross-family read is blocked

**Setup:** Auth as user in family A
**Operation:** Read `families/{familyB}/sessions/{sid}`
**Expected:** DENY (isMemberOfFamily fails)

## Test 10: Tamper events are immutable

**Setup:** Auth as child user. Tamper event exists.
**Operation:** Update `families/{fid}/tamperEvents/{eid}` with `{ "severity": "low" }`
**Expected:** DENY (no update rule exists for tamper events)

## Test 11: Child cannot write reviewWindowEndsAt

**Setup:** Auth as child user
**Operation:** Update session with `{ "reviewWindowEndsAt": <far future> }`
**Expected:** DENY (reviewWindowEndsAt is in serverManagedFields)

## Test 12: Session create must start in ringing state

**Setup:** Auth as child user
**Operation:** Create session with `{ "state": "verified", ... }`
**Expected:** DENY (create requires state == 'ringing')

---

## Expected Error Codes

| Result | Firestore Error Code |
|--------|---------------------|
| DENY | 7 (PERMISSION_DENIED) |
| ALLOW | 0 (OK) |

## Automated Testing (Future)

When emulator tests are set up:
```bash
cd functions
firebase emulators:start --only firestore
npm test  # runs rules test suite
```
