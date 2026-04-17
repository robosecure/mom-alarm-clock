# Mom Alarm Clock — App Store Screenshot Plan

Screenshots needed: 6-10 per device size (iPhone 6.7", iPhone 6.1", iPad if targeting)

---

## Screenshot Plan (Priority Order)

### 1. Guardian Dashboard (Hero Shot)
**Screen:** ParentDashboardView with one child selected, one alarm active
**Caption:** "Set alarms. See results. Stay hands-off."
**What to show:** Child selector at top, alarm card with time and verification method, streak/points visible
**Why:** Establishes the product — guardian is in control but not micromanaging

### 2. Child Alarm Firing
**Screen:** ChildAlarmView in active alarm state (pulsing alarm icon, "Wake Up!" heading)
**Caption:** "Your child's alarm. Their responsibility."
**What to show:** Alarm icon pulsing, "I'm Awake — Verify" button, motivational message
**Why:** Shows the child's experience — they own the morning

### 3. Quiz Verification
**Screen:** QuizVerificationView with an age-appropriate math question
**Caption:** "Prove you're awake. Solve a quick quiz."
**What to show:** Math question, answer field, timer countdown, question counter
**Why:** Core differentiator — verification is what makes this more than a regular alarm

### 4. Guardian Trust Mode Result
**Screen:** ChildAlarmView idle state showing streak and points after verification
**Caption:** "Good mornings run themselves. You'll only hear from us when it matters."
**What to show:** Greeting, next alarm time, streak badge, points badge
**Why:** Sells the "exception-based parenting" value prop

### 5. Voice Alarm Recording
**Screen:** VoiceRecorderView with waveform and record/preview buttons
**Caption:** "Record a personal wake-up message for your child."
**What to show:** Record button, waveform visualization, preview playback
**Why:** Emotional differentiator — personalization parents care about

### 6. Privacy & Data
**Screen:** FamilySettingsView showing Privacy & Data section + How It Works
**Caption:** "No tracking. No ads. You control the data."
**What to show:** Lock shield icon, "Tracking: None", "Ads: None", How It Works bullets
**Why:** Addresses parent privacy concerns head-on

### 7. Alarm Settings (Advanced)
**Screen:** AlarmControlsView showing DatePicker, verification method, Trust Mode with Recommended badge
**Caption:** "Customize verification, difficulty, and what happens if they don't get up."
**What to show:** DatePicker wheel, "Trust Mode (Recommended)" badge, DisclosureGroup for advanced
**Why:** Shows depth of guardian control without overwhelming

### 8. Pending Review (Strict Mode)
**Screen:** VerificationReviewView showing verification proof and Approve/Deny buttons
**Caption:** "When you want to be involved, review every morning."
**What to show:** Verification proof summary, Approve button, Deny button
**Why:** Shows the strict mode for families that want it

---

## Screenshot Capture Tips

- Use a clean simulator with no status bar clutter (or use Xcode's screenshot tool)
- Set the child's name to something relatable ("Emma", "Alex")
- Set streak to 5+ days and points to 75+ for visual impact
- Use morning time (7:00 AM) in all alarm screenshots
- For quiz screenshot, use a simple age-appropriate question (e.g., "7 + 5 = ?")
- Ensure Privacy & Data section shows "None" in green for tracking and ads

## Device Sizes Required

| Device | Size | Required |
|--------|------|----------|
| iPhone 16 Pro Max | 6.7" | Yes (required) |
| iPhone 16 Pro | 6.1" | Yes (required) |
| iPad Pro 13" | 12.9" | Only if iPad is targeted |
