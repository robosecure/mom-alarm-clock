const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// ─── Retention Caps ─────────────────────────────────
const MAX_SESSIONS_PER_CHILD = 500;
const MAX_TAMPER_EVENTS_PER_CHILD = 2000;

// ─── Helpers ────────────────────────────────────────

async function getParentToken(familyID) {
  const db = getFirestore();
  const snapshot = await db
    .collection("users")
    .where("familyID", "==", familyID)
    .where("role", "==", "parent")
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  const doc = snapshot.docs[0];
  const token = doc.data().fcmToken;
  if (!token) return null;
  return { token, parentDocId: doc.id };
}

/**
 * Sends push and logs the attempt to families/{fid}/pushLog/{id}.
 * Log is non-sensitive: no message bodies, no tokens, no PII.
 */
async function sendPushAndLog(message, parentDocId, familyID, meta) {
  const db = getFirestore();
  const logRef = db
    .collection("families")
    .doc(familyID)
    .collection("pushLog")
    .doc();

  let success = false;
  let errorMsg = null;

  try {
    await getMessaging().send(message);
    success = true;
  } catch (err) {
    errorMsg = err.code || err.message;
    if (
      err.code === "messaging/invalid-registration-token" ||
      err.code === "messaging/registration-token-not-registered"
    ) {
      await db.collection("users").doc(parentDocId).update({ fcmToken: null });
    }
  }

  // Write non-sensitive push event log
  try {
    await logRef.set({
      type: meta.type,
      sessionID: meta.sessionID || null,
      dedupKey: meta.dedupKey || null,
      success,
      error: errorMsg,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Non-critical
  }

  return success;
}

/**
 * Writes cleanup metrics to families/{fid}/ops/retention.
 */
async function recordCleanupMetrics(familyID, collection, deletedCount) {
  const db = getFirestore();
  const opsRef = db
    .collection("families")
    .doc(familyID)
    .collection("ops")
    .doc("retention");

  try {
    await opsRef.set(
      {
        [`${collection}_cleanupRuns`]: FieldValue.increment(1),
        [`${collection}_docsDeleted`]: FieldValue.increment(deletedCount),
        lastRunAt: FieldValue.serverTimestamp(),
        lastCollection: collection,
      },
      { merge: true }
    );
  } catch (_) {
    // Non-critical
  }
}

// ─── Set Review Window Deadline (Server-Managed) ────

exports.setReviewWindowDeadline = onDocumentUpdated(
  "families/{familyID}/sessions/{sessionID}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (after.state !== "verified") return;
    if (before.state === "verified") return;

    const policy = after.confirmationPolicy;
    if (!policy || typeof policy !== "object") return;

    const hybridData = policy.hybrid;
    if (!hybridData) return;

    const windowMinutes = hybridData.windowMinutes || hybridData;
    if (typeof windowMinutes !== "number" || windowMinutes <= 0) return;

    if (after.serverReviewWindowEndsAt) return;

    const now = Timestamp.now();
    const deadline = Timestamp.fromMillis(
      now.toMillis() + windowMinutes * 60 * 1000
    );

    const db = getFirestore();
    const sessionRef = db
      .collection("families")
      .doc(event.params.familyID)
      .collection("sessions")
      .doc(event.params.sessionID);

    await sessionRef.update({
      reviewWindowEndsAt: deadline,
      serverVerifiedAt: FieldValue.serverTimestamp(),
      serverReviewWindowSetBy: "cloudFunction",
    });

    console.log(
      `Review window set: session ${event.params.sessionID}, ${windowMinutes}min`
    );
  }
);

// ─── Pending Review Notification (Idempotent) ───────

exports.notifyParentOnPendingReview = onDocumentUpdated(
  "families/{familyID}/sessions/{sessionID}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (after.state !== "pendingParentReview") return;
    if (before.state === "pendingParentReview") return;

    const dedupKey = `pendingReview:${event.params.sessionID}:${after.version || 0}`;
    if (after._lastNotifKey === dedupKey) return;

    const parent = await getParentToken(event.params.familyID);
    if (!parent) return;

    const message = {
      token: parent.token,
      notification: {
        title: "Verification Pending",
        body: "Your child completed their wake-up verification. Tap to review.",
      },
      data: {
        type: "pendingReview",
        familyID: event.params.familyID,
        sessionID: event.params.sessionID,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "category": "PENDING_REVIEW",
          },
        },
      },
    };

    const sent = await sendPushAndLog(message, parent.parentDocId, event.params.familyID, {
      type: "pendingReview",
      sessionID: event.params.sessionID,
      dedupKey,
    });

    if (sent) {
      const db = getFirestore();
      try {
        await db
          .collection("families")
          .doc(event.params.familyID)
          .collection("sessions")
          .doc(event.params.sessionID)
          .update({ _lastNotifKey: dedupKey });
      } catch (_) {}
    }
  }
);

// ─── Tamper Event Notification ──────────────────────

exports.notifyParentOnTamperEvent = onDocumentCreated(
  "families/{familyID}/tamperEvents/{eventID}",
  async (event) => {
    const data = event.data.data();
    const parent = await getParentToken(event.params.familyID);
    if (!parent) return;

    const typeName = (data.type || "unknown").replace(/([A-Z])/g, " $1").trim();
    const severity = data.severity || "medium";

    const message = {
      token: parent.token,
      notification: {
        title: `Tamper Alert: ${typeName}`,
        body:
          data.detail ||
          "A tamper event was detected on your child's device.",
      },
      data: {
        type: "tamperEvent",
        familyID: event.params.familyID,
        severity,
      },
      apns: {
        payload: {
          aps: {
            sound: severity === "critical" ? "alarm_sound.caf" : "default",
            badge: 1,
          },
        },
      },
    };

    await sendPushAndLog(message, parent.parentDocId, event.params.familyID, {
      type: "tamperEvent",
      sessionID: data.morningSessionID || null,
      dedupKey: `tamper:${event.params.eventID}`,
    });
  }
);

// ─── Auto-Clear NextMorning Overrides on Session Completion ─

/**
 * When a session reaches a terminal state (verified, failed, cancelled),
 * clear the child's nextMorningOverrides so they don't carry forward.
 * Only clears if the override was set BEFORE the session was created.
 */
exports.clearOverridesOnSessionComplete = onDocumentUpdated(
  "families/{familyID}/sessions/{sessionID}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const terminalStates = ["verified", "failed", "cancelled"];
    if (!terminalStates.includes(after.state)) return;
    if (terminalStates.includes(before.state)) return; // Already terminal

    const childProfileID = after.childProfileID;
    if (!childProfileID) return;

    const db = getFirestore();
    const familyID = event.params.familyID;

    // Find the child profile
    const childrenSnap = await db
      .collection("families")
      .doc(familyID)
      .collection("children")
      .where("id", "==", childProfileID)
      .limit(1)
      .get();

    // Fallback: try using childProfileID as doc ID directly
    let childRef;
    if (!childrenSnap.empty) {
      childRef = childrenSnap.docs[0].ref;
    } else {
      childRef = db
        .collection("families")
        .doc(familyID)
        .collection("children")
        .doc(childProfileID);
      const childDoc = await childRef.get();
      if (!childDoc.exists) return;
    }

    const childData = (await childRef.get()).data();
    const overrides = childData?.nextMorningOverrides;
    if (!overrides) return;

    // Only clear if the override was set before this session's alarm fired
    const overrideSetAt = overrides.setAt?.toDate?.() || overrides.setAt;
    const alarmFiredAt = after.alarmFiredAt?.toDate?.() || after.alarmFiredAt;

    if (overrideSetAt && alarmFiredAt && overrideSetAt > alarmFiredAt) {
      // Override was set AFTER this session started — don't clear it (it's for tomorrow)
      return;
    }

    await childRef.update({ nextMorningOverrides: null });
    console.log(
      `Cleared nextMorningOverrides for child ${childProfileID} after session ${event.params.sessionID} completed`
    );
  }
);

// ─── Authoritative Reward Application ────────────────

/**
 * Server-authoritative reward calculation and persistence.
 * Triggers on session transition to "verified".
 *
 * Idempotency: uses rewardServerApplied (server-only flag).
 * Client sets rewardOptimistic for UI; server ignores it.
 *
 * Rubric v1 (must match RewardEngine.swift):
 *   First try (verificationAttempts <= 1) + on-time: +15
 *   Retries + on-time: +10
 *   Late: +5
 *   No-snooze bonus: +5
 *   Streak milestones: +25 at 3, +75 at 7, +150 at 14
 */
exports.applyRewardOnVerified = onDocumentUpdated(
  "families/{familyID}/sessions/{sessionID}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only trigger on transition TO "verified"
    if (after.state !== "verified") return;
    if (before.state === "verified") return;

    // Idempotency: check SERVER flag only (not client's rewardOptimistic)
    if (after.rewardServerApplied === true) return;

    const childProfileID = after.childProfileID;
    if (!childProfileID) return;

    const db = getFirestore();
    const familyID = event.params.familyID;
    const sessionRef = db
      .collection("families")
      .doc(familyID)
      .collection("sessions")
      .doc(event.params.sessionID);

    const childRef = db
      .collection("families")
      .doc(familyID)
      .collection("children")
      .doc(childProfileID);
    const childDoc = await childRef.get();
    if (!childDoc.exists) return;

    const childData = childDoc.data();
    const stats = childData.stats || {};

    // Calculate reward from correct session fields
    const alarmFiredAt = after.alarmFiredAt?.toDate?.() || after.alarmFiredAt;
    const verifiedAt = after.verifiedAt?.toDate?.() || after.verifiedAt;
    const wakeMinutes =
      alarmFiredAt && verifiedAt ? (verifiedAt - alarmFiredAt) / 60000 : 999;
    const wasOnTime = wakeMinutes < 5;
    const isFirstTry = (after.verificationAttempts || 1) <= 1; // Correct: uses attempts, not denialCount
    const noSnooze = (after.snoozeCount || 0) === 0;

    let pointsDelta = 0;
    const reasonCodes = [];

    if (wasOnTime && isFirstTry) {
      pointsDelta += 15;
      reasonCodes.push("on_time_first_try");
    } else if (wasOnTime) {
      pointsDelta += 10;
      reasonCodes.push("on_time_retries");
    } else {
      pointsDelta += 5;
      reasonCodes.push("late_verified");
    }

    if (noSnooze) {
      pointsDelta += 5;
      reasonCodes.push("no_snooze_bonus");
    }

    // Streak
    let currentStreak = stats.currentStreak || 0;
    let bestStreak = stats.bestStreak || 0;
    if (wasOnTime) {
      currentStreak += 1;
      bestStreak = Math.max(bestStreak, currentStreak);
      reasonCodes.push("streak_eligible");
      if (currentStreak === 3) { pointsDelta += 25; reasonCodes.push("milestone_3"); }
      if (currentStreak === 7) { pointsDelta += 75; reasonCodes.push("milestone_7"); }
      if (currentStreak === 14) { pointsDelta += 150; reasonCodes.push("milestone_14"); }
    }

    const newPoints = Math.max(0, (stats.rewardPoints || 0) + pointsDelta);

    // Atomic batch: session audit trail + child stats
    const batch = db.batch();
    batch.update(sessionRef, {
      rewardServerApplied: true,
      rewardPointsDelta: pointsDelta,
      rewardReasonCodes: reasonCodes,
      rewardAppliedAt: FieldValue.serverTimestamp(),
      rewardRubricVersion: 1,
    });
    batch.update(childRef, {
      "stats.rewardPoints": newPoints,
      "stats.currentStreak": currentStreak,
      "stats.bestStreak": bestStreak,
      "stats.onTimeCount": FieldValue.increment(wasOnTime ? 1 : 0),
    });
    await batch.commit();

    console.log(
      `Reward v1: session ${event.params.sessionID}, +${pointsDelta}pts, streak=${currentStreak}, codes=[${reasonCodes}]`
    );
  }
);

// ─── Session Retention Cleanup (Cursor-Based) ───────

exports.cleanupOldSessions = onDocumentCreated(
  "families/{familyID}/sessions/{sessionID}",
  async (event) => {
    const data = event.data.data();
    const childProfileID = data.childProfileID;
    if (!childProfileID) return;

    const db = getFirestore();
    const sessionsRef = db
      .collection("families")
      .doc(event.params.familyID)
      .collection("sessions");

    // Get the Nth session (the cap boundary) to use as cursor
    const boundarySnap = await sessionsRef
      .where("childProfileID", "==", childProfileID)
      .orderBy("alarmFiredAt", "desc")
      .limit(1)
      .offset(MAX_SESSIONS_PER_CHILD - 1)
      .get();

    if (boundarySnap.empty) return; // Under cap

    const boundaryDoc = boundarySnap.docs[0];
    const boundaryTime = boundaryDoc.data().alarmFiredAt;

    // Delete everything older than the boundary (startAfter cursor)
    const overflow = await sessionsRef
      .where("childProfileID", "==", childProfileID)
      .orderBy("alarmFiredAt", "desc")
      .startAfter(boundaryTime)
      .limit(50)
      .get();

    if (overflow.empty) return;

    const batch = db.batch();
    overflow.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    await recordCleanupMetrics(
      event.params.familyID,
      "sessions",
      overflow.size
    );

    console.log(
      `Retention: deleted ${overflow.size} old sessions for child ${childProfileID}`
    );
  }
);

// ─── Tamper Event Retention Cleanup (Cursor-Based) ──

exports.cleanupOldTamperEvents = onDocumentCreated(
  "families/{familyID}/tamperEvents/{eventID}",
  async (event) => {
    const data = event.data.data();
    const childProfileID = data.childProfileID;
    if (!childProfileID) return;

    const db = getFirestore();
    const tamperRef = db
      .collection("families")
      .doc(event.params.familyID)
      .collection("tamperEvents");

    const boundarySnap = await tamperRef
      .where("childProfileID", "==", childProfileID)
      .orderBy("timestamp", "desc")
      .limit(1)
      .offset(MAX_TAMPER_EVENTS_PER_CHILD - 1)
      .get();

    if (boundarySnap.empty) return;

    const boundaryDoc = boundarySnap.docs[0];
    const boundaryTime = boundaryDoc.data().timestamp;

    const overflow = await tamperRef
      .where("childProfileID", "==", childProfileID)
      .orderBy("timestamp", "desc")
      .startAfter(boundaryTime)
      .limit(50)
      .get();

    if (overflow.empty) return;

    const batch = db.batch();
    overflow.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    await recordCleanupMetrics(
      event.params.familyID,
      "tamperEvents",
      overflow.size
    );

    console.log(
      `Retention: deleted ${overflow.size} old tamper events for child ${childProfileID}`
    );
  }
);
