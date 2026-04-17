# Mom Alarm Clock — Privacy Submission Reference

Use this when answering App Store Connect privacy questions and filling out the privacy nutrition label.

---

## App Store Connect: App Privacy

### Does your app collect data?
**Yes**

### Data Collected (Privacy Nutrition Label)

| Data Type | Collected | Linked to Identity | Used for Tracking | Purpose |
|-----------|-----------|-------------------|-------------------|---------|
| Email Address | Yes | Yes | No | App Functionality (guardian sign-in) |
| Name | Yes | Yes | No | App Functionality (guardian + child display names) |
| Audio Data | Yes | Yes | No | App Functionality (voice alarm recordings) |
| Coarse Location | Yes | No | No | App Functionality (geofence verification) |
| Photos or Videos | Yes | No | No | App Functionality (photo verification) |
| Crash Data | Yes | No | No | App Functionality (Firebase Crashlytics) |
| Device ID | Yes | No | No | App Functionality (Firebase anonymous auth, App Check) |

### Does your app use data for tracking?
**No.** The app does not use any data for tracking purposes. `NSPrivacyTracking` is set to `false`. No advertising identifiers are collected. No ATT (App Tracking Transparency) framework is used.

### Does your app use third-party analytics?
**Firebase Analytics** is imported but configured for minimal, privacy-safe event logging only. Events contain no personally identifiable information. Examples: `alarmFired(method: "quiz", tier: "medium")`, `verificationSubmitted(passed: true)`. No user identifiers, names, or content are included in analytics events.

**Firebase Crashlytics** collects crash reports containing no PII — only stack traces, device model, and OS version.

### Data linked to the user's identity
Only **email address** and **name** are linked to identity (used for the guardian's account and display name). All other data types are collected but not linked to identity.

---

## Children's Privacy (COPPA)

### Is this app directed at children under 13?
The app is used by children (ages 5-18) but is **managed by a guardian**. Children cannot create accounts independently. The guardian creates the family, adds children, and controls all settings.

### How is parental consent obtained?
1. Guardian creates an account (email + password)
2. Guardian adds a child by name and age
3. A consent acknowledgment is shown: "By adding a child, you confirm you are their parent or legal guardian and consent to the collection of their data as described in our Privacy Policy."
4. Guardian generates a join code and enters it on the child's device

### What data is collected from children?
- **Name** — set by the guardian, displayed in-app
- **Age** — set by the guardian, used to tailor quiz difficulty (stored as number, not DOB)
- **Verification data** — step count, quiz answers, photo (during active verification only)
- **Session data** — alarm times, verification results, streak/points

### Is children's data used for advertising?
**No.** No ads are served. No data is used for advertising or marketing.

### Can the guardian delete children's data?
**Yes.** Deleting the guardian account deletes all family data including all child profiles, sessions, and voice recordings. Individual child profiles can also be removed from the guardian's dashboard.

---

## Account Deletion

### Is account deletion available in-app?
**Yes.** Settings > Delete Account.

### What is deleted?
- Guardian's Firebase Auth account
- Guardian's Firestore user document
- All family data: child profiles, sessions, tamper events, push logs
- All join codes associated with the family
- Voice alarm recordings in Firebase Storage
- All local data on the guardian's device

### What is retained?
**Nothing.** Account deletion is a complete cascade. No data is retained after deletion.

### Is the user warned?
**Yes.** Confirmation dialog states: "This permanently deletes your guardian account, your family, all child profiles, alarm history, and voice recordings. Paired child devices will be signed out. This cannot be undone."

---

## Data Processing

### Who processes the data?
- **Google Firebase** (Firestore, Auth, Storage, Messaging, Crashlytics, Analytics) — Google Cloud infrastructure
- **Apple Push Notification service (APNs)** — push notification delivery

### Is data sold to third parties?
**No.**

### Is data shared with third parties for purposes other than app functionality?
**No.**

---

## Quick Reference: Privacy Policy URL

**Status:** LIVE at https://robosecure.github.io/mom-alarm-clock-legal/privacy.html
**In-app plumbing:** `FamilySettingsView.privacyPolicyURL` — configured and live
