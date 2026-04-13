# Mom Alarm Clock — iOS App

A SwiftUI app that helps parents ensure their children wake up on time. The parent configures alarms remotely; the child's device enforces wake-up verification with escalating consequences.

## Quick Start

### Opening in Xcode

1. Open Xcode 15.0+ (required for iOS 17 / Swift 5.9 APIs).
2. Create a new Xcode project: **File > New > Project > iOS > App**.
   - Product Name: `MomAlarmClock`
   - Organization Identifier: `com.momclock`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**
3. Delete the auto-generated `ContentView.swift` and `MomAlarmClockApp.swift`.
4. Drag the contents of `MomAlarmClock/` into the Xcode project navigator, replacing the default files.
5. Add `MomAlarmClock.entitlements` and `Info.plist` to the project root.
6. In the project target's **Signing & Capabilities** tab, add:
   - iCloud (enable CloudKit, add container `iCloud.com.momclock.MomAlarmClock`)
   - Push Notifications
   - Background Modes (Background fetch, Remote notifications, Audio)
   - Family Controls (requires separate application — see below)
7. Build and run on a physical device (many features require real hardware).

### Simulator Limitations

The iOS Simulator does not support:
- Critical Alerts
- FamilyControls / ManagedSettings
- CMPedometer (step counting)
- AVCaptureSession (camera)
- Push notifications from CloudKit subscriptions

Use a physical device for integration testing.

## Required Entitlements

These entitlements require separate applications to Apple. Plan for 1-4 weeks of review time.

### 1. Critical Alerts

**What:** Allows alarm sounds to play even when the device is in Do Not Disturb or Silent mode.

**Apply:** https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/

**Justification template:** "Our app is a parental alarm clock that ensures children wake up on time. Critical Alerts are essential because the alarm must sound regardless of the device's focus mode or volume settings, as children may enable DND to avoid the alarm."

### 2. Family Controls (Distribution)

**What:** Enables app-blocking shields on the child's device via ManagedSettings.

**Apply:** https://developer.apple.com/contact/request/family-controls-distribution

**Justification template:** "Our app allows parents to enforce screen time restrictions as a consequence of not waking up on time. We use ManagedSettings to temporarily shield entertainment apps until the child completes their morning verification."

**Note:** The development entitlement (Family Controls for development) can be enabled immediately in Xcode without Apple approval. The distribution entitlement is needed for TestFlight and App Store release.

### 3. CloudKit

No special application required. Enable iCloud with CloudKit in Signing & Capabilities. Create the container `iCloud.com.momclock.MomAlarmClock` in the Apple Developer portal.

## Architecture

### Role Selection

The app uses a single binary with role-based UI:
- **Parent mode:** Configures alarms, monitors child status, views history and tamper events.
- **Child mode:** Receives alarms, completes verification, earns rewards.

Role is selected on first launch and stored in `@AppStorage`. This is simpler than two separate apps for V1 and allows shared CloudKit logic.

### 3-Tier Enforcement Model

Mom Alarm Clock uses three tiers of enforcement, each with different capabilities and requirements:

#### Tier 1: App Store (Standard)
- Local notifications with custom sounds
- In-app alarm UI with verification challenges
- CloudKit sync between parent and child devices
- Tamper detection (volume, permissions, connectivity)
- Reward/streak system

#### Tier 2: Screen Time API (Requires Entitlement)
- FamilyControls authorization for app blocking
- ManagedSettings shields to block entertainment apps
- DeviceActivity monitoring for time-based enforcement
- Escalating consequences (partial block → full lock)

#### Tier 3: MDM (Enterprise/Future)
- Full device management via an MDM profile
- Cannot be circumvented by the child
- Volume enforcement, kiosk mode
- Requires an MDM server (e.g., SimpleMDM, Mosyle)
- Not implemented in V1

### MVVM Pattern

```
Views (SwiftUI)
  ↓ observe
ViewModels (@Observable)
  ↓ call
Services (actors / singletons)
  ↓ persist
CloudKit / UserDefaults / Local Notifications
```

- **Views** are pure SwiftUI with no business logic.
- **ViewModels** use the `@Observable` macro (iOS 17) instead of `ObservableObject`.
- **Services** are actors or `@Observable` singletons that handle CloudKit, notifications, device management, and verification.

### CloudKit Sync

Parent and child devices share data through a private CloudKit database:

```
Parent Device                          CloudKit                         Child Device
─────────────                          ────────                         ────────────
ChildProfile ──── save ──────────→ ChildProfile record ←──── fetch ──── ChildProfile
AlarmSchedule ─── save ──────────→ AlarmSchedule record ←── subscribe ── AlarmSchedule
                                   MorningSession record ←── save ────── MorningSession
              ←── subscribe ─────── TamperEvent record ←──── save ────── TamperEvent
```

- **Parent writes:** ChildProfile, AlarmSchedule
- **Child writes:** MorningSession (state updates), TamperEvent, heartbeat timestamps
- **CKSubscription** delivers silent pushes when records change, triggering background fetch on the other device.
- **Conflict resolution:** Last-write-wins based on `lastModified` timestamp. Parent's alarm config always takes precedence.

### Pairing Flow

1. Parent creates a ChildProfile with a 6-character pairing code.
2. Child enters the code on their device.
3. Child device stores the profile ID locally and subscribes to alarm changes.
4. Parent device subscribes to session/tamper updates for that child.

### Heartbeat System

The child's device periodically updates a `lastHeartbeat` timestamp on its CloudKit profile. The parent's device checks this timestamp and flags the child as "offline" if no heartbeat has been received in 30 minutes. This detects:
- Device powered off
- Airplane mode enabled
- App force-quit
- iCloud sign-out

iOS background execution is limited, so we use `BGAppRefreshTask` (scheduled every ~15 minutes, but iOS controls actual timing). A future enhancement is a Web Audio API heartbeat that plays silent audio to keep the app process alive.

## Key Files

| File | Purpose |
|------|---------|
| `App/MomAlarmClockApp.swift` | Entry point, role-based root view |
| `App/AppDelegate.swift` | Notification setup, background tasks |
| `Models/AlarmSchedule.swift` | Alarm config with time, days, verification, escalation |
| `Models/EscalationProfile.swift` | Multi-level consequence definitions |
| `Services/AlarmService.swift` | Local notification scheduling with backup notifications |
| `Services/CloudSyncService.swift` | CloudKit CRUD and subscriptions |
| `Services/FamilyControlsService.swift` | Screen Time app blocking |
| `Services/TamperDetectionService.swift` | Volume/permission/connectivity monitoring |
| `Services/VerificationService.swift` | QR, motion, quiz, geofence verification logic |

## Limitations and Workarounds

### iOS Background Execution
**Problem:** iOS aggressively suspends background apps. The alarm may not fire if the app is suspended.
**Workaround:** Critical Alerts bypass DND/silent mode. Staggered backup notifications (primary + 3 backups at 1-minute intervals) guard against dropped notifications. BGAppRefreshTask for heartbeats.

### Volume Control
**Problem:** The Screen Time API cannot prevent the child from lowering the device volume.
**Workaround:** Detect volume changes via `AVAudioSession.outputVolume` KVO and report to parent as a tamper event. Tier 3 (MDM) can enforce volume.

### App Force Quit
**Problem:** The child can force-quit the app from the app switcher.
**Workaround:** Heartbeat monitoring detects the absence. The parent receives a "device offline" warning. The next alarm notification still fires (local notifications survive app termination).

### Notification Permission Revocation
**Problem:** The child can disable notifications in Settings.
**Workaround:** Periodic permission checks report revocation as a critical tamper event. The ManagedSettings shield (Tier 2) prevents access to Settings during lock mode.

### Time Zone / Clock Manipulation
**Problem:** The child could change the system clock to skip the alarm.
**Workaround:** CloudKit records use server-side timestamps. The parent's device detects discrepancies between the alarm's expected fire time and the session's actual start time.

## Development Roadmap

- [ ] Create Xcode project and add all source files
- [ ] Apply for Critical Alerts and Family Controls entitlements
- [ ] Set up CloudKit container and record types in the dashboard
- [ ] Implement real camera capture (replace PhotosPicker with UIImagePickerController)
- [ ] Implement DataScannerViewController for QR code scanning
- [ ] Add ShieldConfigurationExtension for custom app-block UI
- [ ] Add DeviceActivityMonitorExtension for time-window callbacks
- [ ] Build Web Audio API heartbeat as a WKWebView companion
- [ ] Add unit tests for models and services
- [ ] Add UI tests for onboarding and verification flows
