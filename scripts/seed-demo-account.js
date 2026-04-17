#!/usr/bin/env node
/**
 * seed-demo-account.js
 *
 * Creates a reviewer (App Review) demo family in Firebase.
 *
 *   1. Creates two Firebase Auth users:
 *        - Guardian:  demo-guardian@momclock.app  /  DemoGuardian2026!
 *        - Child:     demo-child@momclock.app     /  DemoChild2026!
 *   2. Writes a family document with both users linked.
 *   3. Seeds:
 *        - one child profile ("Alex", age 9, streak 6, 175 points)
 *        - one school-day alarm (7:00 AM Mon-Fri, quiz verification, Trust Mode)
 *        - 7 days of completed session history
 *        - one reward entry ready to redeem
 *   4. Prints the credentials + family code for the App Review Notes.
 *
 * Requires the service-account key for the project. Set:
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
 *
 * Usage:
 *   # One-time install — firebase-admin lives in functions/:
 *   cd functions && npm install && cd ..
 *
 *   # Run:
 *   node --preserve-symlinks -e "require('./functions/node_modules/firebase-admin'); require('./scripts/seed-demo-account.js')"
 *
 *   # Simpler: cd into functions/ so node's module resolver finds firebase-admin.
 *   cd functions && node ../scripts/seed-demo-account.js [--reset]
 *
 * Safe to re-run: looks up existing users by email and reuses their UIDs.
 * Pass --reset to wipe existing demo users+family before re-seeding.
 *
 * NOTE: Does NOT create production trades or move money. Only writes app state.
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

// ─── Config ────────────────────────────────────────────────────────
const DEMO = {
  guardian: {
    email: 'demo-guardian@momclock.app',
    password: 'DemoGuardian2026!',
    displayName: 'Demo Guardian',
  },
  child: {
    email: 'demo-child@momclock.app',
    password: 'DemoChild2026!',
    displayName: 'Alex',
  },
  family: {
    // Stable ID so reruns overwrite instead of proliferating families.
    id: 'demo-family-appreview',
    name: 'Demo Family',
    joinCode: 'DEMO2026XY',
  },
  child_profile: {
    id: 'demo-child-alex',
    name: 'Alex',
    age: 9,
    streak: 6,
    bestStreak: 14,
    onTimeCount: 42,
    lateCount: 5,
    rewardPoints: 175,
  },
  alarm: {
    id: 'demo-alarm-schooldays',
    hour: 7,
    minute: 0,
    // 2 = Mon, 3 = Tue, 4 = Wed, 5 = Thu, 6 = Fri (matches Calendar.current.component(.weekday))
    activeDays: [2, 3, 4, 5, 6],
    primaryVerification: 'quiz',
    verificationTier: 'medium',
    confirmationPolicy: 'autoAcknowledge',
    label: 'School Days',
  },
};

// ─── Main ──────────────────────────────────────────────────────────

async function main() {
  const reset = process.argv.includes('--reset');

  // App initialization — uses GOOGLE_APPLICATION_CREDENTIALS.
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('ERROR: set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service-account key.');
    console.error('  e.g. export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.firebase/momclock-service-account.json"');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  const auth = admin.auth();
  const db = admin.firestore();

  console.log('Mom Alarm Clock — Demo Account Seeder');
  console.log('=====================================');

  if (reset) {
    await resetDemo(auth, db);
  }

  // 1. Auth users
  const guardianUid = await upsertUser(auth, DEMO.guardian);
  const childUid = await upsertUser(auth, DEMO.child);
  console.log(`  guardian uid: ${guardianUid}`);
  console.log(`  child uid:    ${childUid}`);

  // 2. User docs
  const familyID = DEMO.family.id;
  await db.collection('users').doc(guardianUid).set({
    userID: guardianUid,
    familyID,
    role: 'parent',
    displayName: DEMO.guardian.displayName,
    email: DEMO.guardian.email,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    emailVerified: true,
  }, { merge: true });
  await db.collection('users').doc(childUid).set({
    userID: childUid,
    familyID,
    role: 'child',
    displayName: DEMO.child.displayName,
    email: DEMO.child.email,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    emailVerified: true,
  }, { merge: true });

  // 3. Family doc
  await db.collection('families').doc(familyID).set({
    name: DEMO.family.name,
    ownerUserID: guardianUid,
    joinCode: DEMO.family.joinCode,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    memberUserIDs: [guardianUid, childUid],
  }, { merge: true });

  // Family join code doc
  const future = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
  );
  await db.collection('familyCodes').doc(DEMO.family.joinCode).set({
    familyID,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: guardianUid,
    expiresAt: future,
    usedAt: null,
    usedBy: null,
  }, { merge: true });

  // 4. Child profile
  const childDoc = {
    id: DEMO.child_profile.id,
    name: DEMO.child_profile.name,
    age: DEMO.child_profile.age,
    isPaired: true,
    alarmScheduleIDs: [DEMO.alarm.id],
    stats: {
      currentStreak: DEMO.child_profile.streak,
      bestStreak: DEMO.child_profile.bestStreak,
      onTimeCount: DEMO.child_profile.onTimeCount,
      lateCount: DEMO.child_profile.lateCount,
      tamperEventCount: 0,
      averageWakeMinutes: 2.1,
      rewardPoints: DEMO.child_profile.rewardPoints,
    },
    pendingTierEscalation: false,
    rewards: [
      { id: crypto.randomUUID(), name: '30 min extra screen time', cost: 100, icon: 'tv' },
      { id: crypto.randomUUID(), name: 'Pick dinner on Friday', cost: 150, icon: 'fork.knife' },
      { id: crypto.randomUUID(), name: 'Skip one chore', cost: 200, icon: 'star' },
    ],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('families').doc(familyID)
    .collection('children').doc(DEMO.child_profile.id)
    .set(childDoc, { merge: true });

  // 5. Alarm
  const alarmDoc = {
    id: DEMO.alarm.id,
    alarmTime: { hour: DEMO.alarm.hour, minute: DEMO.alarm.minute },
    activeDays: DEMO.alarm.activeDays,
    primaryVerification: DEMO.alarm.primaryVerification,
    verificationTier: DEMO.alarm.verificationTier,
    confirmationPolicy: DEMO.alarm.confirmationPolicy,
    snoozeRules: { allowed: true, maxCount: 2, durationMinutes: 5, decreasingDuration: true },
    escalation: {
      levels: [
        { minutesAfterAlarm: 0,  action: 'gentleReminder' },
        { minutesAfterAlarm: 10, action: 'parentNotified' },
        { minutesAfterAlarm: 20, action: 'appLockPartial' },
        { minutesAfterAlarm: 30, action: 'appLockFull' },
      ],
    },
    isEnabled: true,
    skipUntil: null,
    label: DEMO.alarm.label,
    childProfileID: DEMO.child_profile.id,
    lastModified: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('families').doc(familyID)
    .collection('alarms').doc(DEMO.alarm.id)
    .set(alarmDoc, { merge: true });

  // 6. Seven days of verified session history for the dashboard graph.
  const batch = db.batch();
  for (let daysAgo = 1; daysAgo <= 7; daysAgo++) {
    const fireDate = new Date();
    fireDate.setDate(fireDate.getDate() - daysAgo);
    fireDate.setHours(DEMO.alarm.hour, DEMO.alarm.minute, 0, 0);

    const verifiedAt = new Date(fireDate.getTime() + (30 + Math.floor(Math.random() * 120)) * 1000);
    const sessionID = `demo-session-${daysAgo}`;
    const sessionRef = db.collection('families').doc(familyID)
      .collection('sessions').doc(sessionID);

    batch.set(sessionRef, {
      id: sessionID,
      childProfileID: DEMO.child_profile.id,
      alarmScheduleID: DEMO.alarm.id,
      alarmFiredAt: admin.firestore.Timestamp.fromDate(fireDate),
      state: 'verified',
      verifiedAt: admin.firestore.Timestamp.fromDate(verifiedAt),
      verifiedWith: 'quiz',
      verificationAttempts: 1,
      verificationDurationSeconds: Math.floor((verifiedAt - fireDate) / 1000),
      confirmationPolicy: 'autoAcknowledge',
      snoozeCount: daysAgo === 3 ? 1 : 0,  // one snooze for realism
      denialCount: 0,
      tamperCount: 0,
      isDeviceLocked: false,
      rewardOptimistic: false,
      rewardServerApplied: true,
      rewardPointsDelta: daysAgo === 3 ? 5 : 10,
      rewardReasonCodes: daysAgo === 3 ? ['on_time'] : ['on_time_first_try', 'no_snooze_bonus'],
      rewardRubricVersion: 1,
      lastUpdated: admin.firestore.Timestamp.fromDate(verifiedAt),
      version: 3,
    });
  }
  await batch.commit();

  // 7. Summary
  console.log('');
  console.log('SEEDED.');
  console.log('=====================================');
  console.log('');
  console.log('Hand these to App Review (paste into App Store Connect > App Information > Notes):');
  console.log('');
  console.log(`  Guardian email:    ${DEMO.guardian.email}`);
  console.log(`  Guardian password: ${DEMO.guardian.password}`);
  console.log(`  Child email:       ${DEMO.child.email}`);
  console.log(`  Child password:    ${DEMO.child.password}`);
  console.log(`  Family join code:  ${DEMO.family.joinCode}`);
  console.log('');
  console.log('Child profile: Alex (age 9), 6-day streak, 175 reward points.');
  console.log('Alarm: School Days (Mon-Fri @ 7:00 AM, Quiz verification, Trust Mode).');
  console.log('History: 7 completed sessions over the past week.');
}

// ─── Helpers ───────────────────────────────────────────────────────

async function upsertUser(auth, spec) {
  try {
    const existing = await auth.getUserByEmail(spec.email);
    // Force-reset password in case it drifted.
    await auth.updateUser(existing.uid, {
      password: spec.password,
      displayName: spec.displayName,
      emailVerified: true,
    });
    return existing.uid;
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await auth.createUser({
      email: spec.email,
      password: spec.password,
      displayName: spec.displayName,
      emailVerified: true,
    });
    return created.uid;
  }
}

async function resetDemo(auth, db) {
  console.log('[reset] removing existing demo users and family...');
  for (const spec of [DEMO.guardian, DEMO.child]) {
    try {
      const u = await auth.getUserByEmail(spec.email);
      await auth.deleteUser(u.uid);
      await db.collection('users').doc(u.uid).delete().catch(() => {});
      console.log(`  deleted user ${spec.email}`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }
  }
  const famRef = db.collection('families').doc(DEMO.family.id);
  await deleteSubcollection(famRef.collection('sessions'));
  await deleteSubcollection(famRef.collection('children'));
  await deleteSubcollection(famRef.collection('alarms'));
  await deleteSubcollection(famRef.collection('tamperEvents'));
  await deleteSubcollection(famRef.collection('pushLog'));
  await famRef.delete().catch(() => {});
  await db.collection('familyCodes').doc(DEMO.family.joinCode).delete().catch(() => {});
  console.log('  deleted family doc + subcollections + join code');
}

async function deleteSubcollection(ref) {
  const snap = await ref.get();
  if (snap.empty) return;
  const batch = ref.firestore.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
}

// ─── Run ───────────────────────────────────────────────────────────

main().catch(err => {
  console.error('FAILED:', err);
  process.exit(1);
});
