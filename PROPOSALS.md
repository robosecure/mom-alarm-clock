# PROPOSALS.md — Product Backlog

Status key: **SHIPPED** = in v1.0, **NEXT** = v1.1, **PLANNED** = on roadmap, **IDEA** = needs evaluation

---

## Shipped in v1.0

### [P-002] First-verification celebration animation — SHIPPED
- Confetti overlay + "First Wake-Up Complete!" banner on child's first-ever approved verification
- Uses @AppStorage to fire once only, auto-dismisses after 4 seconds

### [P-007] Share family code via iOS share sheet — SHIPPED
- ShareLink next to copy button in ParentAuthView + FamilySettingsView

### [P-009] Simplify guardian setup wizard — SHIPPED
- Reduced from 8 steps to 6 (removed verification + escalation steps)
- Smart defaults: quiz, medium, Trust Mode, weekdays
- "Under 2 minutes" setup with COPPA consent acknowledgment

### [P-010] Wire push notification approve/deny actions — SHIPPED
- .guardianNotificationAction wired in MomAlarmClockApp
- Routes to ParentViewModel.approveSession / denySession

### [P-011] Replace hour/minute pickers with DatePicker wheel — SHIPPED
- Both AlarmControlsView and SetupWizardView use DatePicker(.hourAndMinute)

### [P-013] Add try/catch to all Cloud Function await calls — SHIPPED
- All 7 functions wrapped with structured logError() helper

### [P-015] Use DisclosureGroup for advanced alarm settings — SHIPPED
- Snooze + escalation wrapped in DisclosureGroup under "Advanced" header

### [P-016] App Store listing draft — SHIPPED
- APP_STORE_METADATA.md with name, subtitle, description, keywords

### [P-017] App Store privacy compliance — SHIPPED
- PrivacyInfo.xcprivacy (7 data types), PRIVACY_POLICY.md, COPPA consent in AddChildView + wizard
- Account deletion cascades entire family (auth + Firestore + Storage)
- ENTITLEMENT_JUSTIFICATIONS.md for Critical Alerts + FamilyControls

---

## Next (v1.1)

### [P-001] Sign in with Apple for guardian signup — NEXT
- **What:** Add "Sign in with Apple" alongside email/password
- **Why:** One-tap signup eliminates biggest onboarding friction
- **Effort:** Medium
- **Files:** AuthService.swift, ParentAuthView.swift, project.yml

### [P-004] Weekly summary push notification — NEXT
- **What:** Sunday evening push: "Emma: 4/5 on-time, 3-day streak, +45 pts"
- **Why:** Parents who see progress keep using the app
- **Effort:** Medium (new Cloud Function)
- **Files:** functions/index.js

### [P-012] Handle location permission denial gracefully — NEXT
- **What:** Show clear message + Settings link if location denied for geofence
- **Effort:** Small
- **Files:** GeofenceVerificationView.swift

### [P-014] TipKit contextual tips — NEXT
- **What:** iOS 17 TipKit for feature discovery ("Swipe left to skip tomorrow")
- **Effort:** Small-Medium
- **Files:** New Tips/ directory, ParentDashboardView, ChildAlarmView

### [P-026] QR code real scanner — NEXT
- **What:** Replace simulated scan with DataScannerViewController
- **Why:** QR is currently hidden from launch; real scanner enables it
- **Effort:** Medium
- **Files:** QRVerificationView.swift

### [P-027] Increased volume escalation — NEXT
- **What:** AVAudioSession volume escalation for alarm
- **Effort:** Medium
- **Files:** VoiceAlarmPlayerService.swift, EscalationProfile.swift

---

## Planned (v1.2)

### [P-005] Bedtime reminder for child — PLANNED
- **What:** Optional notification at guardian-set time to wind down
- **Effort:** Small
- **Files:** AlarmSchedule.swift, AlarmService.swift

### [P-006] Morning checklist after verification — PLANNED
- **What:** "Brush teeth, Get dressed, Pack backpack" after alarm clears
- **Why:** Extends value from "wake up" to "get ready"
- **Effort:** Medium
- **Files:** New MorningChecklist model + ChecklistView

### [P-008] Gentle/melodic alarm sound options — PLANNED
- **What:** 3-4 built-in sound options (melody, nature, chime)
- **Effort:** Medium
- **Files:** AlarmSchedule.swift, AlarmService.swift, audio assets

### [P-018] StoreKit 2 subscription paywall — PLANNED
- **What:** Family Monthly ($4.99) / Annual ($29.99). Free = 1 child, paid = 4.
- **Effort:** Medium
- **Files:** New StoreKitManager.swift, AddChildView.swift

### [P-019] Visual countdown timer (ADHD-friendly) — PLANNED
- **What:** Circular progress ring on alarm screen showing time remaining
- **Effort:** Small
- **Files:** ChildAlarmView.swift

### [P-021] Step Counter as $1.99 one-time IAP — PLANNED
- **What:** Lock motion/steps behind one-time purchase
- **Effort:** Small
- **Files:** StoreKitManager.swift, AlarmControlsView.swift

### [P-022] Achievement Badges — PLANNED
- **What:** 15+ collectible badges (Early Bird, No Snooze Hero, etc.)
- **Effort:** Medium
- **Files:** New Badge.swift, BadgeView.swift

### [P-025] Family Leaderboard — PLANNED
- **What:** Cross-child competition: longest streak, most points
- **Effort:** Small
- **Files:** New LeaderboardView.swift

---

## Future (v2.0+)

### [P-003] Home screen widget — FUTURE
- **What:** WidgetKit widget showing next alarm + streak
- **Effort:** Large (new target)

### [P-020] ADHD/neurodivergent positioning — FUTURE
- **What:** Market positioning for ADHD families
- **Effort:** Small (copywriting)

### [P-023] Morning Timeline + Insights — FUTURE
- **What:** Visual timeline + trend charts + PDF export
- **Effort:** Medium-Large

### [P-024] Custom Alarm Sound Pack Store — FUTURE
- **What:** Spend points to unlock sounds
- **Effort:** Medium

### [P-028] Android companion app — FUTURE
### [P-029] Parent call escalation (CallKit) — FUTURE
### [P-030] ML photo verification — FUTURE
### [P-031] Adaptive difficulty engine — FUTURE
### [P-032] School/teacher integration — FUTURE
