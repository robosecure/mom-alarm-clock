# Mom Alarm Clock — Release Checklist

## Pre-Release (Before Archive)

### Firebase Setup
- [ ] GoogleService-Info.plist in ios/MomAlarmClock/
- [ ] Firebase Auth: Email/Password + Anonymous enabled
- [ ] Firestore database created (production mode)
- [ ] `firebase deploy --only firestore:rules,firestore:indexes`
- [ ] `firebase deploy --only storage`
- [ ] `firebase deploy --only functions` (7 functions should deploy)
- [ ] APNS .p8 key uploaded to Firebase Console > Cloud Messaging

### App Check
- [ ] Firebase Console > App Check > register iOS app
- [ ] App Attest selected as provider
- [ ] Debug tokens registered for dev simulators
- [ ] Enforcement: start in "Unenforced" (monitor mode)

### Xcode
- [ ] DEVELOPMENT_TEAM set in ios/project.yml (not TEAM_ID_HERE)
- [ ] Bundle ID: com.momclock.MomAlarmClock
- [ ] `xcodegen generate` runs cleanly
- [ ] Build succeeds (Debug + Release)
- [ ] All unit tests pass (32 tests, 0 failures)
- [ ] No new warnings vs baseline

### Code Quality
- [ ] No #if DEBUG fallbacks in Release auth paths
- [ ] Firestore rules match Swift model field names (14 security elements verified)
- [ ] Storage rules enforce guardian-only write, family-scoped read
- [ ] Cloud Functions have re-entrant guards on all session-update triggers

## Archive + Upload

- [ ] Select "Any iOS Device (arm64)" as destination
- [ ] Product > Archive
- [ ] Distribute App > App Store Connect > Upload
- [ ] Wait for processing (5-15 min)

## TestFlight

- [ ] App Store Connect > TestFlight > select build
- [ ] Add internal testers
- [ ] Install on 2 devices (guardian + child)

## Post-Upload Verification

### Guardian Device
- [ ] Create account + note join code
- [ ] Create alarm (1 min from now, Math, Require Approval)
- [ ] Record a voice alarm clip
- [ ] Diagnostics > Run Beta Proof Checks > all green

### Child Device
- [ ] Enter join code + grant permissions
- [ ] Alarm fires > verify > "Waiting for Guardian"
- [ ] Voice clip plays on alarm fire
- [ ] Diagnostics > check push + sync health

### Cross-Device
- [ ] Guardian approves > child sees "Approved!"
- [ ] Guardian denies > child sees reason + "Verify Again"
- [ ] Offline: child airplane mode > verify > reconnect > converges

## Production Enforcement (After Beta Stabilizes)

- [ ] App Check > Functions > set to "Enforced"
- [ ] Wait 1 week, check metrics
- [ ] App Check > Firestore > set to "Enforced"
- [ ] Monitor for legitimate client rejections
- [ ] Rollback: set back to "Unenforced" if issues arise

## Known Limitations (Document in App)

- Tamper detection is best-effort (foreground only for volume/timezone)
- Device lock is visual only (FamilyControls requires Apple entitlement)
- Push requires APNS certificate; shows fallback banner if disabled
- Critical Alerts require separate Apple entitlement approval
- Voice alarm plays in foreground; background is system notification sound
