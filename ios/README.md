# Mom Alarm Clock -- iOS App

> **The alarm clock that gets kids up -- and keeps guardians informed.**

A two-device alarm system where the guardian controls the alarm and the child proves they're awake.

## Quick Links

- **Setup Guide** -- see SETUP_GUIDE.md in repo root
- **Product Brief** -- see PRODUCT_BRIEF.md in repo root
- **Release Checklist** -- see RELEASE_CHECKLIST.md in repo root
- **Proposals** -- see PROPOSALS.md in repo root

## Tech Stack

- SwiftUI (iOS 17+) with @Observable pattern
- Firebase (Auth, Firestore, Cloud Functions, Storage, Messaging, Crashlytics, Analytics, App Check)
- xcodegen for project generation from project.yml

## Build

    cd ios
    xcodegen generate
    xcodebuild build -project MomAlarmClock.xcodeproj -scheme MomAlarmClock -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

## Test

    xcodebuild test -project MomAlarmClock.xcodeproj -scheme MomAlarmClock -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

## Project Structure

    MomAlarmClock/
    App/                    AppDelegate, MomAlarmClockApp
    Models/                 MorningSession, AlarmSchedule, ChildProfile, etc.
    ViewModels/             ChildViewModel, ParentViewModel
    Views/
      Auth/                 AuthGate, ParentAuth, ChildPairing
      Child/                Alarm, Quiz, Motion, Pending, Result
      Parent/               Dashboard, AlarmControls, Review, Settings
    Services/
      Auth/                 AuthService (Firebase Auth)
      Sync/                 FirestoreSyncService, LocalSyncService
      AlarmService          Local notification scheduling
      RewardEngine          Server-authoritative reward calculation
      VoiceAlarmCache       Downloads guardian voice clips
      NetworkMonitor        Offline queue + drain
    Persistence/            LocalStore (offline data)
    Extensions/             Collection+Safe, Date+Helpers

## Key Flows

1. Guardian signs up -- creates family -- gets join code
2. Child pairs -- enters code -- anonymous auth -- joins family
3. Guardian creates alarm -- synced to child via Firestore
4. Alarm fires -- MorningSession created (idempotent) -- child verifies
5. Guardian notified -- reviews proof -- approves/denies -- child sees result
6. Rewards calculated -- server-authoritative via Cloud Function

## Security

- Firestore rules enforce field-level permissions per role
- Child cannot write guardian-only fields or approve/deny sessions
- Server timestamps + version guards prevent state regression
- App Check (App Attest) attests device identity in production
