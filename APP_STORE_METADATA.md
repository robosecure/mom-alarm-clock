# Mom Alarm Clock — App Store Metadata

Use this document when filling out App Store Connect fields.

---

## App Identity

| Field | Value |
|-------|-------|
| App Name | **Mom Alarm Clock** |
| Subtitle | **Wake-up accountability for families** |
| Bundle ID | `com.momclock.MomAlarmClock` |
| Primary Category | Lifestyle |
| Secondary Category | Utilities |
| Age Rating | 4+ (no objectionable content) |
| Price | Free |

---

## Promotional Text (170 chars, can be updated without review)

> The alarm clock that gets your kids out of bed — and only bothers you when it matters.

---

## Description (4000 chars max)

Mom Alarm Clock is a two-device family alarm app. A guardian sets the alarm. The child proves they're awake. On good mornings, nobody has to yell.

**How it works:**
- Guardian creates a family account and adds up to 4 children
- Each child pairs their own device with a one-time join code
- Guardian sets wake-up times, verification method, and difficulty
- When the alarm fires, the child completes a short challenge (quiz, step counting, or photo) to prove they're up
- By default, the alarm clears automatically. The guardian is only notified when something needs attention

**Verification methods:**
- Quiz — age-appropriate math questions (difficulty adapts to the child's age group)
- Motion — step counting to confirm they're out of bed
- Photo — submit a photo for guardian review
- Geofence — confirm they've reached a specific location

**Guardian controls:**
- Trust Mode (default) — child verifies, alarm clears, guardian stays out of it
- Strict Mode — child waits for guardian approval every morning
- Review Window — alarm clears, but guardian can override within a time window
- Tomorrow Overrides — adjust difficulty or method for just the next morning
- Escalation — if the child ignores the alarm, consequences increase over time (notifications, optional app restrictions)

**Voice Alarm:**
Record a personal wake-up message for your child. The clip is cached on their device and plays when the alarm fires — even without an internet connection.

**Age-aware content:**
Quiz difficulty, question count, and wording adapt to the child's age group (5-7, 8-10, 11-13, 14+). Younger children see simpler problems with more encouragement. Older children get more direct prompts.

**Streaks and rewards:**
Children earn points for waking up on time. Streak bonuses at 3, 7, and 14 days. Points are calculated by the server to prevent tampering.

**Privacy-first design:**
- No tracking, no ads, no data sales
- Children cannot create accounts — only guardians can add children
- Age is stored as a number, not a date of birth
- All data is encrypted in transit and at rest
- Account deletion removes all family data permanently
- Full privacy policy available in-app and online

**Built for real mornings:**
- Alarms fire even without internet (local notifications with offline persistence)
- Offline verification actions queue and sync when connectivity returns
- Deterministic session IDs prevent duplicate alarms
- Push notifications only arrive when something actually needs your attention

---

## Keywords (100 chars max, comma-separated)

```
alarm,kids,wake up,morning routine,family,parental control,quiz alarm,child alarm,accountability
```

---

## What's New in This Version

```
First release. Set alarms, verify wake-ups, earn streaks.
```

---

## Support URL

https://robosecure.github.io/mom-alarm-clock-legal/

Support email: rmathews0707@gmail.com

---

## Privacy Policy URL

https://robosecure.github.io/mom-alarm-clock-legal/privacy.html

---

## App Review Notes

See APP_REVIEW_NOTES.md for the full reviewer note.
