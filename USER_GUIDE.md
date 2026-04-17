# Mom Alarm Clock — User Guide

**Version:** 1.0
**Last updated:** April 16, 2026
**Backend:** Firebase (Auth, Firestore, Storage, 8 Cloud Functions)

---

## Part 1: Guardian Guide

### Getting Started

#### Step 1: Create Your Account

1. Open Mom Alarm Clock and tap **"I'm the Guardian"**
2. You have two options:
   - **Sign in with Apple** (recommended) — one tap, no password needed
   - **Email + Password** — enter your first name, email, and a strong password
3. Password requirements:
   - At least 8 characters
   - At least one uppercase letter (A-Z)
   - At least one lowercase letter (a-z)
   - At least one number (0-9)
   - A strength indicator (Weak / Medium / Strong) shows as you type, along with specific requirement feedback
4. If using email, you may receive a **verification email** — click the link to activate your account (required when Firebase is configured)
5. Once complete, you'll land on the **Dashboard**

#### Step 2: Add Your Child

1. On the Dashboard, tap the **"Add Child"** button (or the **+** icon if you already have children)
2. Enter the child's **first name** and **age** (4-18)
3. Tap **"Add Child"**
4. You'll see a **Pair Device** screen with:
   - A **10-character join code** in large monospaced text
   - **Copy** and **Share** buttons to send the code to the child's device
   - Step-by-step instructions for the child
5. Keep this screen open or share the code — you'll need it for the child's phone

**Important:** 
- The code expires after 24 hours and can only be used once
- You can find the code later in **Settings > Join Code**
- You can add up to **4 children** per family

#### Step 3: Create an Alarm

1. After adding a child, tap **"+"** on the Dashboard to create a new alarm
2. Set the **wake-up time** using the wheel picker
3. Choose **active days** by tapping the day circles (Mon-Fri is the default)
4. Choose a **verification method**:
   - **Wake-Up Quiz** (default) — age-appropriate math questions your child must solve
   - **Motion / Steps** — your child must physically walk a set number of steps
5. Choose what happens **after verification**:
   - **Trust Mode** (recommended) — alarm clears automatically when your child verifies. You're only notified if something goes wrong.
   - **Strict Mode** — your child waits for your approval every morning. You review their verification proof and approve or deny.
   - **Review Window** — alarm clears automatically, but you can override within a set time window.
6. Tap **"Create Alarm"**

**Advanced settings** (tap "Advanced" to expand):
- **Difficulty** — Easy / Medium / Hard. Automatically set based on your child's age. Override here if needed.
- **Snooze** — allow or disable snoozing, set max snoozes and duration.
- **If They Don't Get Up** — escalation levels that activate over time if the alarm is ignored.

---

### Daily Use

#### Good Mornings (Trust Mode)

If your child wakes up and verifies on time, **nothing happens on your end**. The alarm clears automatically. You can check the result anytime in **History**, but you won't receive a notification. This is by design — you're only pulled in when something needs your attention.

#### When Something Needs Attention

You'll receive a **push notification** when:
- Your child's verification is **pending your review** (Strict Mode)
- A **tamper event** is detected (volume lowered, permissions revoked)

From the notification, you can:
- **Approve** — clears the alarm, child sees "Approved!"
- **Deny** — sends the child back to verify again, with your reason

#### Reviewing Verification (Strict Mode)

1. Open the app or tap the push notification
2. You'll see the **verification proof**:
   - Method used (quiz, motion)
   - Score or step count
   - Time taken
   - Number of attempts
3. Tap **Approve**, **Deny** (with reason), or **Escalate**
   - Escalate: streak may reset, points adjusted, difficulty increased for next attempt

#### Skip Tomorrow

Swipe left on any alarm to **skip it for one day** (sick days, holidays, weekends). The alarm automatically resets the following day.

#### Tomorrow Overrides

Want to change the difficulty or method for just tomorrow? Go to **your child's profile > Tomorrow Settings** to set a one-time override. It auto-clears after one completed session.

#### Voice Alarm

Record a personal wake-up message for your child:
1. Go to **your child's profile > Voice Alarm**
2. Tap **Record** and speak your message (max 30 seconds)
3. Preview it, then tap **Save**
4. The clip is cached on your child's device for offline playback
5. If the clip is ever removed, the alarm falls back to the standard sound

---

### Settings & Management

#### Dashboard Overview

Your dashboard shows:
- **Child selector** at the top (tap to switch between children)
- **Live status** — current alarm state, streak, online status
- **Stats** — streak count, on-time percentage, reward points, best streak
- **Quick Actions** — Tomorrow overrides, Voice Alarm, Rewards, Settings

#### Family Settings (gear icon)

- **Family** — Family ID, your role, number of children
- **Join Code** — current code with copy/share buttons
- **Children** — list of all children with pairing status
- **Account** — Sign Out, Delete Account
- **How It Works** — quick explanation of the app
- **Privacy & Data** — what data is collected, tracking status (None), ads (None)
- **About** — version, build, diagnostics link

#### Streaks & Rewards

Your child earns points for waking up on time:
- **+15 points** — on time, first try
- **+10 points** — on time with retries
- **+5 points** — verified but late
- **+5 bonus** — no snooze used
- **Streak milestones:** +25 at 3 days, +75 at 7 days, +150 at 14 days

Points are calculated by the server and cannot be tampered with.

#### Configuring Rewards (NEW)

Tap **Rewards** from the Dashboard Quick Actions to manage what your child can redeem with points.

**Default rewards** (loaded automatically for every new child):
- Extra 30 min Screen Time (50 pts)
- Pick Dinner Tonight (100 pts)
- Stay Up 30 min Later (150 pts)
- Movie Night Pick (200 pts)
- Weekend Outing Choice (500 pts)

**To customize:**
- **Edit a reward** — Tap any reward → edit name, points (10-1000), or icon → Save
- **Add a reward** — Tap "+ Add Reward" at the bottom → enter name, points, pick an icon
- **Delete a reward** — Swipe left on any reward

When your child earns enough points, they can tap **Redeem** next to any reward. A confirmation dialog appears. When you confirm, the points are deducted. **You give the actual reward to your child in person** — the app tracks the points but doesn't enforce real-world delivery.

#### Weekly Summary (NEW)

Every Sunday at 6 PM, you'll receive a push notification summarizing the week:
> "Emma: on time 5/7 · 12-day streak"

This runs automatically via Cloud Functions. No setup needed.

#### Escalation System

If your child ignores the alarm, consequences increase over time:

| Time | What Happens |
|------|-------------|
| 0 min | Gentle reminder (alarm is already ringing) |
| 10 min | You receive a push notification |
| 20 min | Entertainment apps blocked on child's device* |
| 30 min | All apps blocked except Phone & Emergency* |

*App lock requires the child to grant Screen Time permission on their device. If unavailable, these steps are skipped and notification-based reminders continue.

#### Account Deletion

1. Go to **Settings > Delete Account**
2. Read the confirmation carefully
3. Tap **"Delete Everything"**

This permanently deletes:
- Your guardian account
- Your family
- All child profiles
- All alarm history and sessions
- All voice recordings
- All join codes
- Paired child devices will be signed out

**This cannot be undone.**

---

### Troubleshooting (Guardian)

| Problem | Solution |
|---------|----------|
| Child's alarm didn't fire | Check that notifications are enabled on the child's device. Go to child's Settings > Notifications > Mom Alarm Clock > Allow. |
| Can't find the join code | Go to Settings (gear icon) > Join Code section. |
| Push notifications not arriving | Check Settings > Diagnostics > Push Notifications. Ensure FCM Token is registered. |
| Child shows "Not paired" | The child needs to enter the join code on their device. Generate a new code if the old one expired. |
| Strict Mode is too much work | Switch to Trust Mode in alarm settings. You'll only be notified when something goes wrong. |
| Points seem wrong | Points are calculated by the server. Check History for the detailed breakdown per session. |
| Child shows "Last seen: Never connected" | The child's device hasn't sent a heartbeat yet. This is normal before the first alarm fires. Once the child opens the app and it syncs, the status will update. |

---

## Part 2: Child Guide

### Getting Started

#### Step 1: Pair Your Device

1. Open Mom Alarm Clock and tap **"I'm the Child"**
2. Enter your **name**
3. Enter the **10-character family code** your guardian gave you
   - The code is letters and numbers only (like `NSDGQ6XLJ5`)
   - It auto-capitalizes as you type
4. Tap **"Join Family"**
5. When prompted, **allow notifications** — this is how your alarm fires!

#### Step 2: Wait for Your Guardian

After pairing, you'll see the **"No Alarm Set"** screen with a "How It Works" guide:
- Your alarm will ring at the time your guardian sets
- Solve a quick quiz or complete a task to prove you're up
- Earn points and build your streak every morning
- Bonus points at 3, 7, and 14 days!

Your guardian will set your alarm from their phone. Once they do, you'll see the alarm time on your home screen.

---

### When the Alarm Rings

1. Your phone will ring and show **"Wake Up!"** with a motivational message
2. You have two options:
   - **"I'm Awake — Verify"** — start the verification challenge
   - **"Snooze"** — if your guardian allows it (limited number of snoozes)

#### Quiz Verification

- You'll see math questions one at a time
- Answer each one correctly to proceed
- A timer counts down for each question
- The difficulty matches your age:
  - **Ages 5-7:** Simple addition (like 3 + 4), 2 questions, 90 seconds each
  - **Ages 8-10:** Addition with bigger numbers, 3 questions, 60 seconds each
  - **Ages 11-13:** Addition and multiplication, 3 questions, 45 seconds each
  - **Ages 14+:** Harder math with multiplication, 3 questions, 30 seconds each

#### Motion / Steps Verification

- Walk the required number of steps
- A progress bar shows how many steps you've completed
- You need to physically move — the phone's pedometer counts real steps

---

### After Verification

#### Trust Mode (most families)

- You'll see **"Approved!"** with a green checkmark
- Your points and streak update immediately
- The screen returns to the idle view after a few seconds
- Your guardian doesn't need to do anything

#### Strict Mode

- You'll see **"Waiting for Guardian"** with a spinning indicator
- Your guardian reviews your verification on their phone
- When they approve, you'll see **"Approved!"**
- If they deny, you'll see the reason and a **"Verify Again"** button

---

### Your Stats

On your home screen, you can see:
- **Current streak** — consecutive days of on-time wake-ups
- **Reward points** — earned from verifying on time
- **Next alarm time** — when your alarm will ring

---

### Tips for Success

1. **Don't snooze** — you get +5 bonus points for not snoozing
2. **Verify quickly** — first-try verification earns the most points (+15 vs +10)
3. **Build your streak** — bonus points at 3 days (+25), 7 days (+75), and 14 days (+150)
4. **Keep notifications on** — if you turn them off, your alarm won't ring properly
5. **Don't tamper** — lowering volume or revoking permissions triggers tamper alerts to your guardian

---

### Troubleshooting (Child)

| Problem | Solution |
|---------|----------|
| Alarm didn't ring | Make sure notifications are enabled. Go to your phone's Settings > Notifications > Mom Alarm Clock > Allow Notifications. |
| "No Alarm Set" showing | Your guardian hasn't set an alarm yet. Ask them to create one from their phone. |
| Quiz is too hard | Your guardian can lower the difficulty in alarm settings, or it adjusts automatically based on your age. |
| "Waiting for Guardian" stuck | Your guardian needs to open their app and approve. If they're busy, the alarm may auto-approve after a set time (depends on the policy your guardian chose). |
| Points didn't update | Points are calculated by the server. They may take a moment to appear. Pull down to refresh. |
| Join code didn't work | Make sure the code is exactly 10 characters. Ask your guardian for the code — they can find it in Settings > Join Code. |

---

## Quick Reference

### Verification Methods

| Method | What You Do | Best For |
|--------|------------|----------|
| **Quiz** | Solve math questions | Everyone (default) |
| **Motion / Steps** | Walk a number of steps | Getting physically out of bed |

### Confirmation Policies

| Policy | What Happens | Best For |
|--------|-------------|----------|
| **Trust Mode** | Alarm clears when child verifies | Most families (default) |
| **Strict Mode** | Guardian must approve | Building the habit initially |
| **Review Window** | Auto-clears, guardian can override within N minutes | Middle ground |

### Points System

| Action | Points |
|--------|--------|
| On time, first try | +15 |
| On time, with retries | +10 |
| Late but verified | +5 |
| No snooze bonus | +5 |
| 3-day streak milestone | +25 |
| 7-day streak milestone | +75 |
| 14-day streak milestone | +150 |

### Age Groups

| Age Band | Quiz Difficulty | Questions | Timer |
|----------|----------------|-----------|-------|
| 5-7 | Easy (addition 1-10) | 2 | 90 sec |
| 8-10 | Easy (addition 1-20) | 3 | 60 sec |
| 11-13 | Medium (addition + multiplication) | 3 | 45 sec |
| 14+ | Medium (multiplication + multi-step) | 3 | 30 sec |
