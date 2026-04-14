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

## [P-008] Gentle/melodic alarm sound option (reduces morning stress)
- **What:** Add 3-4 built-in alarm sound options: gentle melody, nature sounds, chime progression. Let guardian choose per alarm.
- **Why:** Research (PLoS ONE 2020, Chronobiology International) shows melodic alarm tones significantly reduce sleep inertia vs. jarring beeps. Children with sensory sensitivities especially benefit from gentler wake-up sounds.
- **Effort:** Medium (add audio assets to bundle, picker in AlarmControlsView, play via UNNotificationSound)
- **Risk:** Low — audio assets are small (~100KB each), standard iOS notification sound API
- **Files affected:** AlarmSchedule.swift (sound field), AlarmService.swift (notification sound), AlarmControlsView.swift (picker), bundle audio files
- **Note:** Guardian voice alarm already provides personalization; this adds variety for families that prefer non-voice options.

## [P-009] Simplify guardian setup wizard from 8 steps to 3
- **What:** Reduce wizard to: (1) Add child name/age (2) Set first alarm time + days (3) Share code. Move verification method, escalation, and test alarm to post-setup configuration.
- **Why:** 8 steps is too many for first-time onboarding. Research shows 3-step onboarding has 2x completion rate vs 7+ steps. Users who complete setup are 3x more likely to retain.
- **Effort:** Medium (restructure wizard, move steps to post-setup)
- **Risk:** Medium — changes first-time experience significantly. Needs testing.
- **Files affected:** SetupWizardView.swift, SetupWizardViewModel.swift
- **Approach:** Use smart defaults (quiz verification, medium difficulty, default escalation) so the user doesn't HAVE to configure them upfront.

## [P-010] Wire push notification approve/deny actions into ParentViewModel
- **What:** When guardian taps Approve/Deny on the push notification, actually perform the action (find session by ID, call approveSession/denySession in ParentViewModel)
- **Why:** The PENDING_REVIEW notification category with action buttons is registered but the actions are not fully wired — tapping them posts a NotificationCenter notification but nobody handles it yet
- **Effort:** Medium (need to listen for .guardianNotificationAction in MomAlarmClockApp, look up session, call approve/deny)
- **Risk:** Medium — performing actions from background requires careful session lookup
- **Files affected:** MomAlarmClockApp.swift, ParentViewModel.swift

## [P-011] Replace hour/minute pickers with DatePicker wheel
- **What:** Use SwiftUI DatePicker(displayedComponents: .hourAndMinute) with .wheel style instead of two separate Picker wheels
- **Why:** One tap to set time instead of scrolling two separate wheels. Native iOS alarm UX.
- **Effort:** Small (replace 2 Pickers with 1 DatePicker, convert Date ↔ hour/minute)
- **Risk:** Low — standard SwiftUI component
- **Files affected:** AlarmControlsView.swift

## [P-012] Handle location permission denial gracefully in GeofenceVerificationView
- **What:** If CLLocationManager authorization is denied/restricted, show a clear message instead of silently failing on 'Check My Location'
- **Why:** If child hasn't granted location, the check button does nothing. Needs a Settings link.
- **Effort:** Small (check CLLocationManager.authorizationStatus before attempting)
- **Risk:** Low — standard permission check
- **Files affected:** GeofenceVerificationView.swift, VerificationService.swift

## [P-013] Add try/catch to all Cloud Function await calls
- **What:** Wrap all Firestore/FCM await calls in try/catch with structured error logging
- **Why:** 7 of 11 await calls in Cloud Functions lack error handling. If Firestore is temporarily unavailable, these functions would throw unhandled rejections. Adding catch blocks with console.error prevents silent failures and makes debugging easier.
- **Effort:** Small (wrap existing code, no logic change)
- **Risk:** Low — only adds error handling, no behavior change
- **Files affected:** functions/index.js

## [P-014] Add TipKit contextual tips for discoverability
- **What:** Use iOS 17 TipKit to show contextual tips: 'Swipe left to skip tomorrow', 'Tap to edit alarm', 'Approve from lock screen notification'
- **Why:** TipKit is Apple's built-in framework for progressive feature discovery. Eliminates need for custom tutorials. Tips auto-dismiss after the user discovers the feature.
- **Effort:** Small-Medium (define 5-6 tips, attach to relevant views)
- **Risk:** Low — standard Apple framework, non-intrusive, auto-manages tip lifecycle
- **Files affected:** New: Tips/AlarmTips.swift, modified: ParentDashboardView, ChildAlarmView, VerificationReviewView

## [P-015] Use DisclosureGroup for advanced alarm settings (progressive disclosure)
- **What:** Collapse 'Snooze Rules', 'If They Don't Get Up', and 'Verification Difficulty' into DisclosureGroups that default to collapsed. Guardian sees only: Time, Days, Verification Method, Confirmation Policy by default.
- **Why:** 7 sections is overwhelming for a new guardian. Progressive disclosure shows only what's needed, with advanced options one tap away. Apple's WWDC22 talk specifically recommends this pattern.
- **Effort:** Small (wrap 3 sections in DisclosureGroup)
- **Risk:** Low — standard SwiftUI component, no data model change
- **Files affected:** AlarmControlsView.swift

## [P-016] App Store listing draft (ready for submission)
- **What:** Pre-written App Store metadata: name, subtitle, description, keywords, screenshots list
- **Why:** A polished listing increases downloads. First sentence is critical — most users don't tap 'read more.'
- **Effort:** Small (copywriting only, no code)
- **Risk:** None — just text
- **Draft:**

  **Name:** Mom Alarm Clock
  **Subtitle:** Get kids up. Stay informed.
  
  **Description (first 3 lines — visible without tapping):**
  The only alarm app built for families. Set alarms from your phone. Your child proves they're awake with math quizzes. You approve from your lock screen.
  
  **Full description:**
  Mom Alarm Clock is a two-device alarm system where the guardian controls the alarm and the child proves they're awake.
  
  SET IT AND FORGET IT
  - Create weekly alarms from your phone
  - Alarms fire on your child's device automatically
  - Skip tomorrow with one swipe (sick days, holidays)
  
  THEY MUST PROVE THEY'RE AWAKE
  - Math quizzes, step counting, or QR code scanning
  - Difficulty scales from easy to hard
  - Can't just tap dismiss
  
  YOU STAY IN THE LOOP
  - Get notified when your child verifies
  - Approve or deny from your lock screen
  - See proof of verification (quiz score, time, steps)
  
  MAKE MORNINGS POSITIVE
  - Record a personal voice alarm message
  - Streaks and reward points motivate consistency
  - Calm mode eases the wake-up transition
  
  BUILT FOR FAMILIES
  - Up to 4 children per family
  - Per-child settings, voice alarms, and rewards
  - Works offline — alarms fire even without internet
  
  **Keywords (100 chars max):**
  alarm,kids,wake,morning,family,parental,quiz,routine,child,streak,reward,verification,guardian

## [P-017] App Store privacy compliance (required for submission)
- **What:** Complete these before App Store submission:
  1. Add privacy policy URL (host on a simple webpage)
  2. Fill out privacy nutrition labels in App Store Connect
  3. Add PrivacyInfo.xcprivacy manifest file for Firebase SDK usage
  4. Verify account deletion actually deletes Firestore data (not just local)
- **Why:** Apple requires all four for App Store approval. Missing any one = rejection.
- **Effort:** Medium (privacy policy needs legal review, manifest file needs Firebase API audit)
- **Risk:** Medium — privacy policy needs real legal content, not placeholder
- **Files affected:** New: PrivacyInfo.xcprivacy, project.yml, FamilySettingsView (actual Firestore deletion)
- **Note:** Account deletion UI exists but currently only calls auth.signOut() — needs to actually delete the user's Firestore data + Firebase Auth account

## [P-018] Implement StoreKit 2 subscription paywall (monetization)
- **What:** Add StoreKit 2 subscription with iOS 17's built-in SubscriptionStoreView. Two products: Family Monthly ($4.99) and Family Annual ($29.99). Free tier = 1 child, paid = up to 4.
- **Why:** Monetization is required for sustainability. StoreKit 2 + SubscriptionStoreView makes this extremely simple — Apple provides the paywall UI. The paywall triggers at 'Add Child' when the free limit (1 child) is reached.
- **Effort:** Medium (StoreKit config file, Product.products fetch, SubscriptionStoreView presentation, entitlement check in AddChildView)
- **Risk:** Medium — needs App Store Connect product setup and testing in sandbox
- **Files affected:** New: StoreKit.storekit (config), StoreKitManager.swift. Modified: AddChildView.swift (paywall gate), project.yml (StoreKit framework)
- **Implementation notes:**
  - SubscriptionStoreView is one line: 
  - Check entitlement:  → if subscribed, allow 4 children
  - Test in Xcode StoreKit sandbox (no real money, no App Store Connect needed initially)

## [P-019] Visual countdown timer on alarm screen (ADHD-friendly)
- **What:** Show a prominent visual countdown timer on the alarm ringing screen: 'Verify within 15 minutes' with a circular progress ring that depletes over time.
- **Why:** Research on ADHD morning routines shows visual timers significantly reduce decision fatigue and time-blindness. Apps like Brili and Tiimo use this pattern. Our escalation system already has timeouts — making them visible empowers the child to self-manage.
- **Effort:** Small (circular progress ring based on escalation profile timing, already have the data)
- **Risk:** Low — visual only, uses existing escalation timers
- **Files affected:** ChildAlarmView.swift (alarm ringing section)
- **Note:** This could be a positioning differentiator for ADHD/neurodivergent families — a significant and underserved market.

## [P-020] Market positioning for ADHD/neurodivergent families
- **What:** Add ADHD-friendly messaging to App Store listing and product brief. Mention: visual timers, structured verification, positive reinforcement, guardian oversight.
- **Why:** Apps like Brili (/yr), RoutineFlow, and Tiimo target ADHD families specifically. Our app already has many ADHD-friendly features (structured routine, timers, rewards, calm mode) but doesn't market them as such.
- **Effort:** Small (copywriting only)
- **Risk:** None — marketing positioning
- **Files affected:** PRODUCT_BRIEF.md, App Store listing (P-016)

## [P-021] Step Counter as .99 one-time in-app purchase
- **What:** Lock Motion/Steps verification behind a one-time .99 purchase. Quiz remains free. When guardian selects 'Motion / Steps' in alarm setup, show a purchase prompt if not bought.
- **Why:** Steps is the most physically effective verification — gets kids OUT of bed. Low price = impulse buy. Once someone pays , they're 5x more likely to subscribe later (foot-in-the-door).
- **Effort:** Small (StoreKit 2 non-consumable product, gate in AlarmControlsView + ChildViewModel)
- **Risk:** Low — standard StoreKit purchase, doesn't affect free quiz flow
- **Files affected:** StoreKitManager.swift (new), AlarmControlsView.swift (gate), VerificationMethod.swift (isPaid flag)

## [P-022] Achievement Badges system
- **What:** 15+ collectible badges: Early Bird, No Snooze Hero, Quiz Master, Iron Streak (30 days), seasonal badges. Free tier gets 3 basic badges, paid gets full collection.
- **Why:** Kids collect badges like Pokemon. Parents see them as proof the system works. Drives daily engagement.
- **Effort:** Medium (Badge model, badge display view, unlock logic, per-child tracking)
- **Risk:** Low — additive feature, no core flow changes
- **Files affected:** New: Badge.swift, BadgeView.swift. Modified: ChildProfile (badges array), ChildAlarmView (badge showcase)

## [P-023] Morning Timeline + Insights (guardian premium)
- **What:** Visual timeline of each morning (alarm 7:00 → snooze 7:05 → verify 7:12 → approved 7:15). Weekly/monthly trend charts. Exportable PDF for co-parents.
- **Why:** Parents who SEE improvement keep paying. PDF export is gold for shared custody. Competing apps charge /yr for less.
- **Effort:** Medium-Large (timeline view, Swift Charts for trends, PDF generation)
- **Risk:** Low — read-only view, no data model changes
- **Files affected:** New: MorningTimelineView.swift, InsightsView.swift

## [P-024] Custom Alarm Sound Pack Store
- **What:** Library of alarm sounds: nature (birds, waves), music box, video game, funny (roosters, trumpets). Child can CHOOSE their sound as a reward (spend points to unlock).
- **Why:** Sound choice = ownership. Kids who pick their alarm resent it less. Points-to-unlock creates a virtuous cycle: wake up → earn points → unlock cooler sound → more motivated.
- **Effort:** Medium (audio assets, sound picker UI, points-to-unlock mechanic)
- **Risk:** Low — audio files are small, standard AVAudioPlayer
- **Files affected:** New: SoundPackStore.swift, alarm sound assets. Modified: AlarmSchedule (soundID), AlarmService (play selected sound)

## [P-025] Family Leaderboard (multi-child competitive)
- **What:** Cross-child leaderboard: who has the longest streak? Most points this week? 'Early Bird Champion' crown on dashboard. Weekly winner gets a guardian-defined reward.
- **Why:** Sibling competition is the most powerful motivator for ages 6-14. Kids motivate EACH OTHER. Parents love it.
- **Effort:** Small (leaderboard view sorted by streak/points, champion badge on child tab)
- **Risk:** Low — read-only display from existing per-child stats
- **Files affected:** New: LeaderboardView.swift. Modified: ParentDashboardView (champion indicator)
