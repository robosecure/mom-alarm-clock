# Mom Alarm Clock — Product Brief

> **"The alarm clock that gets kids up — and keeps parents informed."**

---

## The Problem

Every morning, millions of parents face the same battle: getting their kids out of bed on time. Traditional alarm clocks get ignored, snoozed, or turned off. Parents resort to yelling from downstairs, walking up multiple times, or accepting chronic lateness.

**The result:**
- Stressful mornings for the whole family
- Kids who never learn to self-manage their wake-up routine
- Parents who can't trust that their child is actually awake and moving

No existing alarm app solves this because they all work on a single device. The child controls the alarm — they can silence it, delete it, or just ignore it. Parents have zero visibility.

## The Solution

**Mom Alarm Clock** is a two-device alarm system where the parent/guardian controls the alarm and the child proves they're awake.

```
┌─────────────────┐          ┌─────────────────┐
│  GUARDIAN PHONE  │◄────────►│   CHILD PHONE   │
│                  │  Firebase │                  │
│  • Set alarms    │  real-    │  • Alarm rings   │
│  • Choose verify │  time     │  • Must verify   │
│  • Review proof  │  sync     │  • Can't silence │
│  • Approve/deny  │          │  • Sees result   │
└─────────────────┘          └─────────────────┘
```

**How it works:**
1. **Guardian** creates an alarm and chooses how the child must verify they're awake (math problems, step counting, etc.)
2. **Alarm fires** on the child's device at the scheduled time
3. **Child must verify** — solve math problems, take steps, or complete a quiz. They can't just tap "dismiss."
4. **Guardian gets notified** — sees the proof, can approve or send back for re-verification
5. **Child sees the result** — "Approved! Great job!" or "Try again."
6. **Rewards build over time** — streaks, points, and positive reinforcement for consistent wake-ups

---

## Who It's For

### Primary Users

**Parents / Guardians**
- Parents of kids ages 6-16
- Especially helpful for:
  - Working parents who leave before kids wake up
  - Families where mornings are a consistent struggle
  - Parents of teens who sleep through traditional alarms
  - Co-parenting situations where both parents want visibility

**Children**
- Ages 6-16 (age-appropriate quiz difficulty scales automatically)
- Kids who need external accountability to wake up
- Kids who respond well to positive reinforcement (streaks, points)

### Use Cases
- **School mornings** — ensure kids are up and moving by 7 AM
- **Summer schedule** — maintain routine even without school
- **Shared custody** — both parents can monitor wake-up from their own device
- **Teens** — accountability without constant nagging

---

## Key Features

### 1. Cross-Device Alarm Management
The guardian sets alarms from their phone. Alarms fire on the child's phone. Both devices stay synced in real-time via Firebase.

- **Repeating weekly schedules** (Mon-Fri, weekends, custom)
- **Multiple children** (up to 4 per family)
- **Snooze limits** (configurable: 0-3 snoozes)
- **Backup reminders** (automatic 2-minute follow-up)

### 2. Wake-Up Verification
The child can't just tap "dismiss." They must prove they're awake:

| Method | How It Works | Best For |
|--------|-------------|----------|
| **Math Quiz** | Solve randomized math problems (difficulty scales by tier) | All ages |
| **Step Counter** | Walk a minimum number of steps (30/50/100) | Kids who need to physically get moving |
| **QR Code** | Scan a QR code placed in the bathroom/kitchen | Ensuring they leave the bedroom |
| **Photo** | Take a photo (guardian reviews) | Visual proof of being up |
| **Geofence** | Be within a GPS radius of a target location | Older kids / specific location requirement |

### 3. Two-Way Confirmation Protocol
Three policy modes let the guardian choose the right level of oversight:

| Policy | What Happens |
|--------|-------------|
| **Auto-Acknowledge** | Alarm clears as soon as verification passes. Guardian is notified but doesn't need to act. |
| **Require Approval** | Child's device stays "pending" until guardian explicitly approves or denies. |
| **Hybrid** | Auto-clears, but guardian has a review window (default 30 min) to retroactively deny or escalate. |

### 4. Guardian Voice Alarm
Guardian records a personal wake-up message (up to 30 seconds) that plays when the alarm fires. "Good morning sweetie, time for school!" instead of a generic beep.

- Record, preview, and re-record from the guardian's phone
- Cached on child device for offline playback
- Falls back to system sound if no voice clip is set

### 5. Rewards & Streaks
Positive reinforcement keeps kids motivated:

- **Points** for on-time wake-ups (+15 first try, +10 retries, +5 late)
- **No-snooze bonus** (+5 for not hitting snooze)
- **Streak milestones** (+25 at 3 days, +75 at 7, +150 at 14)
- **Reward store** where kids can "spend" points (guardian configures rewards)

### 6. Tomorrow Overrides
Guardian can adjust next morning's settings with one tap:
- Verification method (switch to easier quiz)
- Difficulty tier (easy / medium / hard)
- Max attempts per question
- Timer duration
- "Calm mode" (brief breathing interstitial before verification)

Overrides auto-clear after one session — no permanent changes.

### 7. Tamper Detection (Best-Effort)
The app monitors for attempts to circumvent the alarm:

| Detection | How | Reliability |
|-----------|-----|-------------|
| Volume lowered | AVAudioSession KVO | Foreground only |
| Notifications disabled | Permission polling | While app runs |
| Network lost | NWPathMonitor | Reliable |
| Timezone changed | NSSystemTimeZoneDidChange | Foreground only |
| Device offline | Heartbeat gap (parent-side) | UX indicator |

**Honest limitation:** iOS does not allow apps to prevent the user from closing them or changing system settings. Tamper detection is *accountability* (guardian is informed), not *enforcement* (child is blocked). We are transparent about this.

### 8. Offline-First Reliability
Alarms fire even without internet. All actions queue locally and sync when connectivity returns.

- Local notification scheduling survives app restart
- Offline actions replay idempotently (no duplicates)
- UI converges cleanly with conflict banners

### 9. Diagnostics & Support
Built-in tools for troubleshooting:
- **Beta Proof Script** — one-tap validation of all system components
- **Push health panel** — token status, delivery timestamps
- **Sync health panel** — queue length, rejection reasons
- **Diagnostics export** — copy-to-clipboard JSON for support tickets

---

## Technical Architecture

### Stack
- **iOS:** SwiftUI (iOS 17+), @Observable pattern
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, Storage, Messaging, Crashlytics, Analytics, App Check)
- **Sync:** Real-time Firestore listeners with offline queue + server timestamps
- **Security:** Firestore Security Rules with field-level permissions, state machine enforcement, server-managed review windows

### Security Model

```
┌──────────────────────────────────────────────────┐
│                  FIRESTORE RULES                  │
│                                                   │
│  Guardian can:                                    │
│    ✓ Create/edit alarms                          │
│    ✓ Approve/deny/escalate sessions              │
│    ✓ Modify child profile + stats                │
│    ✓ Create join codes                           │
│    ✗ Cannot write verification fields            │
│                                                   │
│  Child can:                                       │
│    ✓ Create sessions (state=ringing only)        │
│    ✓ Submit verification + update state          │
│    ✓ Send messages                               │
│    ✓ Update heartbeat                            │
│    ✗ Cannot write parentAction fields            │
│    ✗ Cannot approve/deny/escalate                │
│    ✗ Cannot change role or family membership     │
│    ✗ Cannot modify review window deadline        │
│                                                   │
│  Server (Cloud Functions) manages:                │
│    • Review window deadlines                     │
│    • Reward point calculations                   │
│    • Override auto-clear                         │
│    • Push notifications                          │
│    • Data retention cleanup                      │
│                                                   │
│  App Check: Device attestation (App Attest)       │
│  Auth: Guardian email/password, Child anonymous   │
└──────────────────────────────────────────────────┘
```

### Data Flow

```
Guardian sets alarm
    ↓
Firestore: families/{fid}/alarms/{aid}
    ↓
Child device: real-time listener → LocalStore cache → UNCalendarNotificationTrigger (repeats: true)
    ↓
Alarm fires (even offline)
    ↓
MorningSession created (deterministic ID — no duplicates)
    ↓
Child verifies (math/quiz/motion)
    ↓
Session → pendingParentReview (strict) OR verified (auto/hybrid)
    ↓
Cloud Function: push notification → guardian device
    ↓
Guardian reviews → approve/deny/escalate
    ↓
Cloud Function: apply reward points (server-authoritative, exactly-once)
Cloud Function: clear tomorrow overrides
    ↓
Child sees result → session complete
```

### Cloud Functions (7 total)

| Function | Trigger | Purpose |
|----------|---------|---------|
| `setReviewWindowDeadline` | Session → verified | Sets server-managed review window |
| `notifyParentOnPendingReview` | Session → pendingParentReview | Push to guardian |
| `notifyParentOnTamperEvent` | Tamper event created | Push to guardian |
| `clearOverridesOnSessionComplete` | Session terminal state | Auto-clear tomorrow overrides |
| `applyRewardOnVerified` | Session → verified | Server-authoritative reward points |
| `cleanupOldSessions` | Session created | Retention cap (500/child) |
| `cleanupOldTamperEvents` | Tamper event created | Retention cap (2000/child) |

---

## Screen-by-Screen Design

### Guardian Screens

#### 1. Landing / Role Selection
```
┌────────────────────────────┐
│                            │
│      🔔 Mom Alarm Clock    │
│                            │
│   Who is using this device? │
│                            │
│  ┌──────────────────────┐  │
│  │ 🛡 I'm the Parent /  │  │
│  │    Guardian           │  │
│  │ Create account, set   │  │
│  │ alarms, monitor       │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │ 👤 I'm the Child     │  │
│  │ Enter family code to  │  │
│  │ pair with guardian    │  │
│  └──────────────────────┘  │
│                            │
└────────────────────────────┘
```

#### 2. Guardian Dashboard
```
┌────────────────────────────┐
│ ← History    Dashboard  + →│
│────────────────────────────│
│                            │
│  [Emma ▾]  [Jake]  [Lily] │  ← Child selector tabs
│                            │
│  ┌──────────────────────┐  │
│  │ 🟢 LIVE STATUS       │  │
│  │ Last seen: Just now   │  │
│  │ Next alarm: 7:00 AM   │  │
│  │ Streak: 🔥 5 days    │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │ ⏰ ALARMS            │  │
│  │ School Days  7:00 AM  │  │  ← Toggle on/off
│  │ Weekends    8:30 AM   │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │ 📊 STATS             │  │
│  │ On-time: 85%  Points: │  │
│  │ 245  Best: 12 days   │  │
│  └──────────────────────┘  │
│                            │
│  ┌────┐ ┌────┐ ┌────┐     │
│  │☀️  │ │🎤  │ │🎁  │     │
│  │Tmrw│ │Voic│ │Rwrd│     │  ← Quick actions
│  └────┘ └────┘ └────┘     │
│                            │
└────────────────────────────┘
```

#### 3. Alarm Setup
```
┌────────────────────────────┐
│ Cancel    New Alarm    Save│
│────────────────────────────│
│                            │
│  Time:     [ 7 : 00  AM ] │
│  Label:    [ School Days ] │
│                            │
│  Days:                     │
│  [M] [T] [W] [T] [F] [ ] [ ]│
│   ●   ●   ●   ●   ●       │
│                            │
│  Verification:             │
│  [Math Quiz ▾]             │
│  Difficulty: [Easy|Med|Hard]│
│                            │
│  Policy:                   │
│  ( ) Auto-acknowledge      │
│  (●) Require my approval   │
│  ( ) Hybrid (30min window) │
│                            │
│  Snooze: [Allowed ▾]      │
│  Max: [2 times]            │
│                            │
└────────────────────────────┘
```

#### 4. Verification Review (Push brings guardian here)
```
┌────────────────────────────┐
│    Review Verification     │
│────────────────────────────│
│                            │
│        ⏳ Awaiting         │
│      Your Review           │
│  Apr 13, 2026 at 7:12 AM  │
│                            │
│  ┌──────────────────────┐  │
│  │ ✅ Verification Proof │  │
│  │ Method: Math Quiz     │  │
│  │ Tier: Medium          │  │
│  │ Completed: 7:12 AM    │  │
│  │ Result: Passed        │  │
│  │ 3/3 correct, avg 8s   │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │ Wake-up time: 12 min  │  │
│  │ Snoozes used: 1       │  │
│  └──────────────────────┘  │
│                            │
│  Add a note: [Great job!] │
│                            │
│  [██ Approve ██████████]   │  ← Green
│  [ Deny — Re-verify    ]  │  ← Bordered
│  [ Escalate             ]  │  ← Red bordered
│                            │
└────────────────────────────┘
```

### Child Screens

#### 5. Child Idle (No Active Alarm)
```
┌────────────────────────────┐
│                            │
│                            │
│         🌙 zzz             │
│                            │
│        7:00 AM             │  ← Large, readable
│                            │
│      tomorrow morning      │
│      School Days           │
│                            │
│                            │
│                            │
│    🔥 5-day streak!        │
│                            │
│                            │
└────────────────────────────┘
```

#### 6. Child Alarm Ringing
```
┌────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  ← Red gradient
│                            │
│         🔔                 │  ← Pulsing
│      Wake Up!              │
│                            │
│    12 min elapsed          │
│                            │
│  ⚠️ Next level in 3 min   │
│                            │
│  💬 "Time to get up!"     │  ← Guardian message
│                            │
│                            │
│  [████ I'm Awake ████████] │  ← Large, prominent
│  [    Verify Now    ]      │
│                            │
│  [  Snooze (1/2)  ]       │
│                            │
│  💬 Message Guardian       │
│                            │
└────────────────────────────┘
```

#### 7. Child Math Verification
```
┌────────────────────────────┐
│       Wake-Up Quiz         │
│────────────────────────────│
│                            │
│       🧠                   │
│                            │
│   ⏱ 42s    # Attempt 1/3  │
│                            │
│  ┌──────────────────────┐  │
│  │                      │  │
│  │     24 + 37 = ?      │  │  ← Large, clear
│  │                      │  │
│  └──────────────────────┘  │
│                            │
│       [ 61 ]               │  ← Number input
│                            │
│  ┌────────┐ ┌────────────┐ │
│  │ 👋     │ │  Submit    │ │
│  │I'm     │ │            │ │
│  │trying! │ │            │ │
│  └────────┘ └────────────┘ │
│                            │
│   ● ● ○   (2 of 3)        │  ← Progress dots
│                            │
└────────────────────────────┘
```

#### 8. Child Waiting for Guardian
```
┌────────────────────────────┐
│    Verification Submitted  │
│────────────────────────────│
│                            │
│                            │
│         ⏳                  │
│                            │
│   Waiting for Guardian     │
│                            │
│  Your verification has     │
│  been submitted. Your      │
│  guardian will review it   │
│  shortly.                  │
│                            │
│  ┌──────────────────────┐  │
│  │ 🧮 Math Quiz         │  │
│  │ 3/3 correct          │  │
│  └──────────────────────┘  │
│                            │
│                            │
└────────────────────────────┘
```

#### 9. Child Result — Approved
```
┌────────────────────────────┐
│                            │
│                            │
│         ✅                  │
│                            │
│      Approved!             │
│                            │
│  Great job getting up!     │
│  Your device is unlocked.  │
│                            │
│  💬 "Great job!" — Guardian│
│                            │
│                            │
└────────────────────────────┘
```

#### 10. Child Result — Denied
```
┌────────────────────────────┐
│                            │
│         ❌                  │
│                            │
│   Verification Denied      │
│                            │
│  ┌──────────────────────┐  │
│  │ Your guardian wants   │  │
│  │ you to verify again.  │  │
│  │                      │  │
│  │ Reason: "Not up yet" │  │
│  └──────────────────────┘  │
│                            │
│  [██ Verify Again ██████]  │
│                            │
└────────────────────────────┘
```

---

## Color Palette & Visual Language

### Colors
| Role | Color | Usage |
|------|-------|-------|
| Primary (Guardian) | `#007AFF` (System Blue) | Navigation, CTAs on guardian screens |
| Alarm Active | `#FF3B30` (System Red) | Ringing state, urgent actions |
| Success | `#34C759` (System Green) | Approved, verification passed |
| Warning | `#FF9500` (System Orange) | Pending review, denial |
| Child Calm | `#AF52DE` (System Purple) | Quiz, idle state |
| Streak | `#FF9500` (Orange) | Fire emoji, streak badges |

### Typography
- **Large numbers** (alarm time, countdown): SF Rounded, 64pt
- **Headings**: SF Pro Bold, title size
- **Body**: SF Pro Regular, body size
- **Monospace** (codes, diagnostics): SF Mono

### Design Principles
1. **Calm over urgent** — even alarms should feel firm, not panicky
2. **Large and touchable** — minimum 56pt buttons, designed for bleary-eyed kids
3. **Progress is visible** — streaks, quiz dots, countdown timers
4. **Guardian language is warm** — "guardian" not "parent," encouragement not punishment
5. **Honest about limitations** — we say "best-effort detection" not "tamper-proof"

---

## Competitive Landscape

| Feature | Mom Alarm | Alarmy | Sleep Cycle | Stock iOS |
|---------|:---------:|:------:|:-----------:|:---------:|
| Cross-device control | ✅ | ❌ | ❌ | ❌ |
| Guardian approval | ✅ | ❌ | ❌ | ❌ |
| Verification required | ✅ | ✅ | ❌ | ❌ |
| Voice alarm | ✅ | ❌ | ❌ | ❌ |
| Streaks/rewards | ✅ | ❌ | ❌ | ❌ |
| Family/multi-child | ✅ | ❌ | ❌ | ❌ |
| Offline reliable | ✅ | ✅ | ✅ | ✅ |
| Push to guardian | ✅ | ❌ | ❌ | ❌ |
| Free to use | ✅ | Freemium | Freemium | ✅ |

**Our differentiation:** We're the only alarm app designed as a *two-device system* for families. Every competitor is single-device. That's the fundamental difference.

---

## Business Model

### Free Tier (1 Child)
- All verification methods (math, quiz, motion, QR, photo, geofence)
- All confirmation policies (auto, strict, hybrid)
- Voice alarm
- Streaks and rewards
- Push notifications
- Offline reliability
- Full diagnostics

### Family Plan ($4.99/month)
- **Up to 4 children** with per-child everything:
  - Individual alarms, schedules, and verification settings
  - Per-child voice alarm recordings
  - Per-child streaks, rewards, and stats
  - Tomorrow overrides per child
- Weekly summary reports
- Priority support

### Annual Plan ($29.99/year — save 50%)
- Everything in Family
- Family leaderboard (kids compete on streaks)
- Achievement badges
- Custom reward store items
- Early access to new features

### Paywall Placement
The paywall appears at the natural friction point: the "Add Child" button. When a free user taps "+" to add a second child, they see the upgrade prompt. Everything else works fully — we never cripple features to upsell.

---

## Technical Specifications

### Requirements
- iOS 17.0+
- iPhone only (not iPad — alarm apps need to be on the bedside device)
- Firebase project (Blaze plan for Cloud Functions)
- APNS certificate for push notifications

### Privacy
- **No tracking of children** — no advertising SDKs, no third-party analytics on child screens
- **Firebase Analytics** on guardian screens only (privacy-safe events: no PII, no messages, no photos)
- **Voice clips** stored in family-scoped Firebase Storage (encrypted at rest)
- **Session data** retained 90 days locally, 500 sessions server-side per child
- **No data sold** to third parties, ever

### Performance
- App launch to alarm-ready: < 2 seconds
- Alarm fire to session created: < 500ms
- Push notification delivery: < 5 seconds (Firebase → APNS)
- Offline → online convergence: < 10 seconds after reconnect

---

## Roadmap

### v1.0 — MVP (Current State)
- ✅ Cross-device pairing
- ✅ Alarm scheduling (repeating, weekly)
- ✅ Math/quiz verification
- ✅ Guardian approve/deny/escalate
- ✅ Voice alarm
- ✅ Rewards/streaks
- ✅ Tomorrow overrides
- ✅ Offline-first with queue convergence
- ✅ Push notifications
- ✅ Diagnostics + proof checks

### v1.1 — Polish
- Better onboarding flow (fewer steps)
- Improved quiz difficulty scaling
- Haptic feedback throughout
- Widget for child's idle screen (next alarm countdown)

### v1.2 — Engagement
- Achievement badges (not just points)
- Weekly summary for guardian
- Customizable reward store items
- Family leaderboard (multiple children)

### v2.0 — Platform
- Android app (same Firebase backend)
- Web dashboard for guardian
- Alexa/Google Home integration ("Alexa, did my kid wake up?")

### Future
- AI-powered wake-up difficulty (adapts to how fast the child solves)
- Sleep tracking integration
- School calendar integration (auto-adjust for holidays)
- FamilyControls / Screen Time enforcement (requires Apple entitlement)

---

## How to Share This App

### For Friends to Try (TestFlight)
1. Build and upload to TestFlight (see SETUP_GUIDE.md)
2. Add friends as internal testers in App Store Connect
3. They install via TestFlight link
4. They need TWO devices: one as guardian, one as child

### For Investors / Partners
Share this document + the interactive demo at `demo.html` in the repo root.

### For App Store Submission
- App name: "Mom Alarm Clock"
- Subtitle: "Get kids up. Stay informed."
- Category: Utilities > Productivity
- Age rating: 4+ (no objectionable content)
- Privacy nutrition labels: see Privacy section above

---

*Built with SwiftUI, Firebase, and a lot of early mornings.*
