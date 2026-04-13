# Mom Alarm Clock — TestFlight Setup Guide

Follow these steps exactly to get a working build on real devices.

## Prerequisites

- Xcode 15+ with iOS 17 SDK
- Apple Developer account (paid, for TestFlight)
- Firebase project created at https://console.firebase.google.com
- Node.js 18+ (for Cloud Functions)
- `firebase-tools` CLI: `npm install -g firebase-tools`

## Step 1: Firebase Project Setup

1. Go to Firebase Console > Create Project (or use existing)
2. Add an iOS app:
   - Bundle ID: `com.momclock.MomAlarmClock`
   - App nickname: "Mom Alarm Clock"
3. Download `GoogleService-Info.plist`
4. Place it at: `ios/MomAlarmClock/GoogleService-Info.plist`

**Verify:** The file must be in the same directory as `App/AppDelegate.swift`. The build will log `[Firebase] Not configured` if missing.

## Step 2: Xcode Signing

1. Open `ios/project.yml`
2. Replace `TEAM_ID_HERE` with your Apple Developer Team ID
3. Run: `cd ios && xcodegen generate`
4. Open `MomAlarmClock.xcodeproj` in Xcode
5. Select the target > Signing & Capabilities > check "Automatically manage signing"
6. Select your team

## Step 3: Firebase Auth

1. Firebase Console > Authentication > Sign-in method
2. Enable **Email/Password**
3. Enable **Anonymous** (for child devices)

## Step 4: Firestore

1. Firebase Console > Firestore Database > Create database
2. Choose production mode (rules will be deployed next)
3. Select a region close to your users

## Step 5: Deploy Rules + Functions

```bash
cd /path/to/mom-alarm-clock

# Login to Firebase CLI
firebase login

# Set your project
firebase use --add  # select your project

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# Deploy Storage rules (for Voice Alarm)
firebase deploy --only storage

# Deploy Cloud Functions
cd functions && npm install && cd ..
firebase deploy --only functions
```

**Verify:** Firebase Console > Firestore > Rules should show the deployed rules. Functions tab should show 5 functions.

## Step 6: Push Notifications (APNS)

1. Apple Developer Portal > Certificates, Identifiers & Profiles > Keys
2. Create a new key with "Apple Push Notifications service (APNs)" enabled
3. Download the .p8 file
4. Firebase Console > Project Settings > Cloud Messaging
5. Under "Apple app configuration", upload the .p8 key
6. Enter the Key ID and Team ID

**Verify:** Run the app on a real device. Check Diagnostics > Push Notifications > "FCM Token" should show a value.

## Step 7: App Check (Optional but Recommended)

1. Firebase Console > App Check > Apps > register your iOS app
2. Select "App Attest" as the attestation provider
3. For simulators: run the app, find the debug token in console logs (`[AppCheck] Debug token:`), register it in Console > App Check > Manage debug tokens

## Step 8: Build and Archive

```bash
cd ios
xcodegen generate
```

Then in Xcode:
1. Select "Any iOS Device (arm64)" as destination
2. Product > Archive
3. Distribute App > TestFlight (App Store Connect)
4. Upload

## Step 9: TestFlight

1. App Store Connect > TestFlight > select the build
2. Add internal testers (your devices)
3. Install on both parent and child devices

## Step 10: First Run Verification

### Parent Device:
1. Launch > "I'm the Parent / Guardian" > Create account
2. Note the 10-character join code
3. Go to Dashboard > "+" > Create alarm for 1 min from now
4. Choose "Math" verification + "Require Approval" policy

### Child Device:
1. Launch > "I'm the Child" > Enter join code
2. Grant all permission prompts
3. Wait for alarm > "I'm Awake — Verify" > Complete math
4. Wait for guardian approval

### Parent Device:
5. Push notification arrives > Tap > Review > Approve
6. Child device shows "Approved!"

### Diagnostics Check:
7. Parent > Diagnostics (wrench icon) > "Run Beta Proof Checks"
8. All items should show PASS (green)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `[Firebase] Not configured` in console | GoogleService-Info.plist missing or has placeholder API key |
| No push notifications | Check APNS key uploaded in Firebase Console; check Diagnostics > Push Notifications |
| `PERMISSION_DENIED` on Firestore writes | Rules not deployed; run `firebase deploy --only firestore:rules` |
| Alarm doesn't fire | Check Settings > Notifications > Mom Alarm Clock > enabled |
| Alarm fires but no sound | Check device is not on silent (Ring/Silent switch). Check volume is up. Check Focus mode is off or allows Mom Alarm Clock. This is a known iOS bug affecting all alarm apps (2024-2025). |
| Archive fails with signing error | Set DEVELOPMENT_TEAM in project.yml and re-run xcodegen |
| Child can't join family | Code expired (24h) or already used; parent generates new code |
