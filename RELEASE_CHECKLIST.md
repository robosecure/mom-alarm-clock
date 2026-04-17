# Mom Alarm Clock — Final Release Checklist

Last updated: 2026-04-17

---

## Phase 1: Accounts & Infrastructure

### Apple Developer Program
- [x] Enrolled in Apple Developer Program (Team ID: U474UU36TW)
- [x] Team ID set in `ios/project.yml`
- [x] Bundle ID registered: `com.momclock.MomAlarmClock`
- [x] App created in App Store Connect
- [ ] Sign Xcode into Apple ID (required for archiving — blocker)
- [ ] Request Critical Alerts entitlement: https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/
- [ ] Request Family Controls entitlement (if not auto-approved): https://developer.apple.com/contact/request/family-controls-distribution

### Firebase Project
- [x] Firebase project created (`mom-alarm-clock`, Blaze plan)
- [x] GoogleService-Info.plist in place (real API key)
- [x] Firebase Auth: Email/Password enabled
- [x] Firebase Auth: Anonymous enabled
- [ ] APNS .p8 key uploaded to Firebase Console > Cloud Messaging (needs Apple Developer portal access)

### Firebase Deploy
- [x] Firestore rules + indexes deployed
- [x] Storage rules deployed
- [x] 8 Cloud Functions deployed (Node 20): applyRewardOnVerified, cleanupOldSessions, cleanupOldTamperEvents, clearOverridesOnSessionComplete, notifyParentOnPendingReview, notifyParentOnTamperEvent, setReviewWindowDeadline, weeklySummary

### App Check
- [x] iOS app registered in Firebase Console > App Check
- [x] App Attest selected as provider
- [ ] Start in "Unenforced" (monitor mode) — enforce after beta stabilizes

---

## Phase 2: Build & Sign

- [x] `xcodegen generate` runs cleanly
- [x] Debug build succeeds (zero errors)
- [x] Release build succeeds (unsigned — full signing blocked on Xcode Apple ID sign-in)
- [x] All 90 unit tests pass
- [x] `aps-environment` is `production` in entitlements
- [x] Bundle ID: `com.momclock.MomAlarmClock`
- [x] Version: 1.0, Build: 1

---

## Phase 3: App Store Connect

### App Listing
- [ ] Create app in App Store Connect
- [ ] App name: "Mom Alarm Clock"
- [ ] Subtitle: "Wake-up accountability for families"
- [ ] Category: Lifestyle (primary), Utilities (secondary)
- [ ] Age rating: 4+
- [ ] Description: see APP_STORE_METADATA.md
- [ ] Keywords: see APP_STORE_METADATA.md
- [ ] Promotional text: see APP_STORE_METADATA.md

### Privacy
- [x] Privacy policy hosted: https://robosecure.github.io/mom-alarm-clock-legal/privacy.html
- [ ] Privacy policy URL entered in App Store Connect (needs portal access)
- [x] `FamilySettingsView.privacyPolicyURL` configured and live
- [x] Privacy nutrition labels documented (see PRIVACY_SUBMISSION_REFERENCE.md)
- [x] PrivacyInfo.xcprivacy included in build (7 data types declared)

### Support
- [x] Support URL: https://robosecure.github.io/mom-alarm-clock-legal/
- [x] Support email: rmathews0707@gmail.com (TEMP — migrate before public launch)

### Screenshots
- [ ] 6-8 screenshots per required device size (see SCREENSHOT_PLAN.md)

### Review Notes
- [ ] App Review Notes pasted (see APP_REVIEW_NOTES.md)
- [ ] Demo account credentials provided (if applicable)

---

## Phase 4: Archive & Upload

- [ ] Select "Any iOS Device (arm64)" destination
- [ ] Product > Archive
- [ ] Distribute App > App Store Connect > Upload
- [ ] Wait for processing (5-15 min)
- [ ] Verify build appears in TestFlight

---

## Phase 5: TestFlight Smoke Test

### Guardian Device
- [ ] Install from TestFlight
- [ ] Create account + note join code
- [ ] Create alarm for 2-3 minutes from now (Quiz, Trust Mode)
- [ ] Record a voice alarm clip (optional)
- [ ] Settings > Diagnostics > Reviewer/Tester Checklist > all green

### Child Device
- [ ] Install from TestFlight
- [ ] Enter join code + grant permissions
- [ ] Alarm fires on time
- [ ] Complete quiz verification
- [ ] Session marked as verified

### Cross-Device
- [ ] Guardian sees result in History
- [ ] Test Strict Mode: alarm → verify → guardian approve → child sees result
- [ ] Test deny: guardian deny → child sees reason + "Verify Again"
- [ ] Test offline: child airplane mode → verify → reconnect → state converges

---

## Phase 6: Submit for Review

- [ ] Select build in App Store Connect
- [ ] Submit for review
- [ ] Monitor for reviewer questions (check email daily)

---

## Phase 7: Post-Approval

### App Check Enforcement (staged)
1. [ ] Functions > set to "Enforced" — wait 1 week
2. [ ] Firestore > set to "Enforced" — wait 1 week
3. [ ] Monitor for legitimate client rejections
4. [ ] Rollback: set back to "Unenforced" if issues arise

### Monitoring
- [ ] Firebase Console > Crashlytics > monitor crash-free rate
- [ ] Firebase Console > Analytics > verify events flowing
- [ ] Check Cloud Functions logs for errors

---

## Quick Reference: What the App Does Without Entitlements

| Without | Behavior |
|---------|----------|
| Critical Alerts | Alarms fire with standard sound (may be silenced by DND) |
| FamilyControls | App lock escalation levels are skipped; reminders + notifications still work |
| Push permission | Alarms fire but guardian doesn't receive pending review notifications |
| Location permission | Geofence verification unavailable; quiz/motion/photo still work |
| Microphone permission | Voice alarm recording unavailable; standard alarm sound plays |

The app functions fully without Critical Alerts and FamilyControls. These are enhancement entitlements, not requirements.
