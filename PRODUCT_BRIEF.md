# Mom Alarm Clock — Product Brief

> **"The alarm clock that gets kids out of bed — and only bothers you when it matters."**

---

## The Problem

Every morning, millions of parents face the same battle: getting their kids out of bed on time. Traditional alarm clocks get ignored, snoozed, or turned off. Parents resort to yelling from downstairs, walking up multiple times, or accepting chronic lateness.

No existing alarm app solves this because they all work on a single device. The child controls the alarm — they can silence it, delete it, or just ignore it. Parents have zero visibility.

## The Solution

**Mom Alarm Clock** is a two-device family alarm system. The guardian controls the alarm. The child proves they're awake. On good mornings, nobody has to yell.

```
┌─────────────────┐          ┌─────────────────┐
│  GUARDIAN PHONE  │◄────────►│   CHILD PHONE   │
│                  │ Firebase  │                  │
│  • Set alarms    │ real-time │  • Alarm fires   │
│  • Choose method │   sync    │  • Must verify   │
│  • Review proof  │          │  • Can't silence  │
│  • See results   │          │  • Earns rewards  │
└─────────────────┘          └─────────────────┘
```

**Default behavior:** The child verifies, the alarm clears, and the guardian hears nothing. Exception-based parenting — you're only pulled in when something goes wrong.

---

## Key Features (v1.0)

### Verification Methods (4 at launch)
| Method | How it works | Age-aware |
|--------|-------------|-----------|
| **Quiz** | Age-appropriate math questions (easy → medium) | Yes — 2 questions for 5-7yo, 3 for 8+ |
| **Motion** | Step counting via pedometer | Step count adjusts by tier |
| **Photo** | Submit photo for guardian review | Always requires approval |
| **Geofence** | Reach a designated location | Radius adjusts by tier |

### Confirmation Policies
| Policy | Behavior |
|--------|----------|
| **Trust Mode** (default) | Auto-completes on verification. Guardian not notified. |
| **Strict Mode** | Child waits for guardian approval every morning. |
| **Review Window** | Auto-completes, but guardian can override within N minutes. |

### Voice Alarm
Guardian records a personal wake-up message. Cached on child's device for offline playback. Max 30 seconds, 5MB. Falls back to standard alarm sound if removed.

### Age-Aware Content
Quiz difficulty, question count, timer, and encouragement style adapt to the child's age group:
- **5-7:** 2 easy questions, 90s timer, warm encouragement
- **8-10:** 3 easy questions, 60s timer, supportive
- **11-13:** 3 medium questions, 45s timer, direct
- **14+:** 3 medium questions, 30s timer, minimal

Guardian overrides and tomorrow overrides always take priority over age defaults.

### Streaks & Rewards (Server-Authoritative)
- +15 pts on-time first try, +10 retries, +5 late
- +5 no-snooze bonus
- Streak milestones: +25 at 3 days, +75 at 7, +150 at 14
- Calculated by Cloud Function with Firestore transaction (no client tampering)

### Escalation System (4 launch-ready levels)
| Minutes | Action |
|---------|--------|
| 0 | Gentle reminder (alarm is ringing) |
| 10 | Guardian notified (push) |
| 20 | Entertainment apps blocked (FamilyControls) |
| 30 | Full app lock |

### Offline Support
- Alarms fire from local notifications regardless of network
- Verification completes locally and queues for sync
- Offline actions classified on drain: success, rules rejected, auth expired, transient
- Deterministic session IDs prevent duplicates

---

## Technical Architecture

| Component | Technology |
|-----------|-----------|
| iOS client | SwiftUI, @Observable, iOS 17+ |
| Backend | Firebase Firestore (real-time sync) |
| Auth | Firebase Auth (email/password + anonymous) |
| Push | FCM + APNs with action buttons (approve/deny) |
| Storage | Firebase Storage (voice clips, 5MB max) |
| Functions | 7 Cloud Functions (Node.js 18, v2 triggers) |
| Security | App Check (App Attest), role-based Firestore rules |
| Local | JSON files + iOS File Protection, Keychain (PIN) |
| Build | xcodegen (project.yml → Xcode project) |

### Cloud Functions
1. **setReviewWindowDeadline** — server-managed hybrid review window
2. **notifyParentOnPendingReview** — push to guardian (idempotent)
3. **notifyParentOnTamperEvent** — tamper alert push
4. **clearOverridesOnSessionComplete** — auto-clear tomorrow overrides
5. **applyRewardOnVerified** — server-authoritative reward calculation (transaction)
6. **cleanupOldSessions** — retention cap at 500 per child
7. **cleanupOldTamperEvents** — retention cap at 2000 per child

### Firestore Security Highlights
- Family isolation (cross-family access blocked)
- Role enforcement (child vs guardian field-level permissions)
- Server-managed fields blocked from both client roles
- Version monotonic guard (prevents state regression)
- Hybrid window fail-closed (missing field blocks retroaction)
- Tamper count monotonic (can only increase)

---

## Privacy & Compliance

- **No tracking, no ads, no data sales**
- **COPPA compliant:** guardian-only account creation, explicit consent, minimal collection
- **GDPR/CCPA:** in-app deletion cascades entire family, nothing retained
- **Privacy manifest:** 7 data types declared, NSPrivacyTracking: false
- **Data encryption:** Firestore (in transit + at rest), iOS File Protection (local), Keychain (PIN)
- **Age stored as number** (not date of birth), grouped into 4 age bands for content tailoring

---

## Testing

- **45 unit tests** (session determinism, reward engine, config merge, age bands, policy defaults)
- **22 Firestore rules tests** (role isolation, field permissions, state machine, version guards)
- **8 real-device test scenarios** in LAUNCH_CHECKLIST.md

---

## Pricing Model

| Tier | Price | Includes |
|------|-------|---------|
| **Free** | $0 forever | 1 child, all verification methods, voice alarm, streaks, offline, all confirmation modes |
| **Family** | $4.99/month | Up to 4 children, weekly wake-up summaries, tomorrow overrides, escalation system |

The natural paywall is the 2nd child. First child gets the full experience — no artificial restrictions. Parents who see value with one child convert when adding siblings.

---

## What Ships vs. What's Deferred

### Ships in v1.0
All core flows, 4 verification methods, 3 confirmation policies, voice alarm, age-aware quiz, streaks/rewards, offline queue, push with action buttons, escalation (4 levels), account deletion cascade, privacy manifest, COPPA consent, App Check.

### Deferred to v1.1+
- QR code scanner (DataScannerViewController)
- Increased volume escalation (AVAudioSession)
- Parent call escalation (CallKit)
- Sign in with Apple
- Smart auto-escalation policy
- Weekly summary push
- Cloud Function unit tests

### Deferred to v2.0+
- Android companion app
- ML photo verification
- Adaptive difficulty engine
- School/teacher integration

---

## Submission Status

| Item | Status |
|------|--------|
| Code | Ready (build passes, 45 tests pass) |
| Privacy manifest | Complete (7 data types) |
| Privacy policy | Written (PRIVACY_POLICY.md, needs hosting) |
| App Store metadata | Written (APP_STORE_METADATA.md) |
| Reviewer notes | Written (APP_REVIEW_NOTES.md) |
| Screenshot plan | Written (SCREENSHOT_PLAN.md) |
| Release checklist | Written (RELEASE_CHECKLIST.md, 7 phases) |
| Firebase setup | Script ready (scripts/setup-firebase.sh) |
| Apple enrollment | Pending (operational blocker) |
| Entitlement requests | Pending (Critical Alerts, FamilyControls) |
