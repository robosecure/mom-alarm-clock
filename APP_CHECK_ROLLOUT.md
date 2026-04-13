# App Check Enforcement Rollout Plan

## Overview

App Check verifies that requests come from the real Mom Alarm Clock app on a real Apple device. This prevents API abuse from scripts, modified clients, or emulators.

## Providers

| Environment | Provider | How It Works |
|-------------|----------|-------------|
| Production (TestFlight/App Store) | **App Attest** | Uses Apple's App Attest API (Secure Enclave) to prove device + app identity |
| Development (Simulator) | **Debug Provider** | Prints a debug token to Xcode console; register it in Firebase Console |

## Step-by-Step Rollout

### Phase 1: Monitor (No Enforcement)

1. **Firebase Console > App Check > Apps > iOS**
   - Select App Attest as the attestation provider
   - Click "Register"

2. **Register debug tokens** for development:
   - Run the app on a simulator
   - Look for `[AppCheck] Debug token: <token>` in the console
   - Firebase Console > App Check > Apps > Manage debug tokens > Add

3. **Enable monitoring** (not enforcement):
   - Firebase Console > App Check > APIs > Firestore > "Unenforced" (metrics only)
   - Firebase Console > App Check > APIs > Cloud Functions > "Unenforced"

4. **Wait 1-2 weeks** and check the App Check metrics dashboard:
   - What % of requests have valid tokens?
   - Are any legitimate clients failing?

### Phase 2: Enforce for Cloud Functions

5. **Firebase Console > App Check > APIs > Cloud Functions > "Enforced"**
   - This blocks unauthenticated Cloud Function calls
   - Lower risk than Firestore because functions are write-triggered (not client-called)

6. **Verify** by checking:
   - Push notifications still arrive
   - Review window deadline still gets set
   - Retention cleanup still runs

### Phase 3: Enforce for Firestore

7. **Firebase Console > App Check > APIs > Firestore > "Enforced"**
   - This blocks all direct Firestore reads/writes from non-attested clients

8. **Verify on both devices:**
   - Parent: can create alarms, approve/deny sessions
   - Child: alarm fires, verification submits, tamper events create
   - Both: real-time listeners still work

### Rollback Plan

If legitimate clients get blocked after enforcement:

1. **Immediate:** Firebase Console > App Check > APIs > set back to "Unenforced"
2. **Investigate:** Check App Check metrics for failed attestation attempts
3. **Common issues:**
   - Simulator without registered debug token (register it)
   - Old app version without App Check SDK (force update)
   - Jailbroken device (App Attest fails on jailbroken devices — acceptable)
4. **Re-enable** after fixing the issue

## In-App Verification

The Diagnostics screen shows:
- **App Check: Enabled/Disabled** — whether the provider is active
- **Provider:** "appAttest" (prod) or "debug" (dev)
- **Last Result:** token fetch success or error message
- **Launch Readiness:** App Check checkbox

## Cost

App Check itself is free. App Attest attestation calls are free. No additional Firebase billing.
