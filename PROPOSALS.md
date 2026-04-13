# PROPOSALS.md — Ideas for Morning Review

These are improvements identified during overnight sessions that need human review before implementation.

## [P-001] Sign in with Apple for guardian signup
- **What:** Add "Sign in with Apple" button alongside email/password on the guardian auth screen
- **Why:** Eliminates typing email+password (biggest onboarding friction). One tap to create account.
- **Effort:** Medium (requires Apple Developer capability + ASAuthorizationController)
- **Risk:** Low — standard Apple API, no security model change. Firebase supports Apple auth natively.
- **Files affected:** AuthService.swift, ParentAuthView.swift, project.yml (add AuthenticationServices)

## [P-002] First-verification celebration animation
- **What:** When child completes their very first verification ever, show a brief confetti/star animation + "First wake-up complete! 🎉"
- **Why:** Onboarding research shows celebrating first success is the strongest predictor of retention
- **Effort:** Small (track firstVerification bool on profile, show animation once)
- **Risk:** Low — visual only, no data model change
- **Files affected:** ChildAlarmView.swift, PendingReviewView.swift, ChildProfile.swift

## [P-003] Home screen widget (child) — next alarm countdown
- **What:** WidgetKit widget showing next alarm time + current streak on child home screen
- **Why:** Keeps the alarm visible without opening the app; reduces "I forgot to check" excuses
- **Effort:** Large (new WidgetKit target, shared data via App Groups)
- **Risk:** Low — read-only widget, no security impact
- **Files affected:** New target: MomAlarmWidget/

## [P-004] Weekly summary push notification to guardian
- **What:** Every Sunday evening, send a push summarizing the week: "Emma: 4/5 on-time, 3-day streak, +45 pts"
- **Why:** Parents who see progress keep using the app; parents who don't, uninstall
- **Effort:** Medium (new Cloud Function on a schedule, or client-triggered)
- **Risk:** Low — read-only summary, no sensitive data
- **Files affected:** functions/index.js (new scheduled function), NotificationService

## [P-005] Bedtime reminder for child
- **What:** Optional notification at guardian-set time: "Time to wind down — alarm set for 7:00 AM"
- **Why:** Getting up is easier when you go to bed on time. Completes the morning routine loop.
- **Effort:** Small (add bedtimeReminder time to AlarmSchedule, schedule one more notification)
- **Risk:** Low — just another local notification
- **Files affected:** AlarmSchedule.swift, AlarmService.swift, AlarmControlsView.swift

## [P-006] Morning checklist after verification (reduces nagging)
- **What:** After alarm is verified/approved, show a simple checklist: "Brush teeth, Get dressed, Pack backpack, Eat breakfast." Guardian configures the list.
- **Why:** Research shows the #1 parent pain point is nagging kids through morning tasks AFTER they wake up. This extends the app's value from "wake up" to "get ready." Parents of ADHD kids especially need this.
- **Effort:** Medium (new model for checklist items, new view, per-child configuration)
- **Risk:** Medium — adds a new data model and screen. But it's the natural next step after wake-up.
- **Files affected:** New: MorningChecklist model, ChecklistView, AlarmSchedule gets checklist items
- **Mockup:** After "Approved!" screen, transition to a simple vertical checklist with checkboxes. Guardian sees completion status. No enforcement — just visibility.

## [P-007] Share family code via iOS share sheet (Messages, AirDrop)
- **What:** Add a share button next to the copy button on the join code screen. Opens the iOS share sheet so guardian can text/AirDrop the code directly.
- **Why:** Copy-paste requires switching apps. Share sheet is one tap to send via Messages.
- **Effort:** Small (UIActivityViewController / ShareLink in SwiftUI)
- **Risk:** Low — standard iOS API
- **Files affected:** ParentAuthView.swift, FamilySettingsView.swift
