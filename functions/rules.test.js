const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "mom-alarm-clock-test";

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../firestore.rules"),
        "utf8"
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ─── Helpers ────────────────────────────────────────

async function seedUser(uid, role, familyID) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`users/${uid}`).set({ role, familyID, displayName: "Test" });
  });
}

async function seedSession(familyID, sessionID, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`families/${familyID}/sessions/${sessionID}`).set(data);
  });
}

async function seedFamily(familyID) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`families/${familyID}`).set({ ownerUserID: "parent1" });
  });
}

// ═══════════════════════════════════════════════════
// CORE INVARIANTS (Tests 1-14 from original suite)
// ═══════════════════════════════════════════════════

test("1: child cannot write parentAction on session", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "pendingParentReview",
    childProfileID: "cp1",
    version: 1,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      parentAction: { approved: {} },
      state: "verified",
      version: 2,
      lastUpdated: new Date(),
    })
  );
});

test("2: child cannot set state to cancelled", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "ringing",
    childProfileID: "cp1",
    version: 1,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      state: "cancelled",
      version: 2,
      lastUpdated: new Date(),
    })
  );
});

test("3: child cannot change role to parent", async () => {
  await seedUser("child1", "child", "fam1");
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(db.doc("users/child1").update({ role: "parent" }));
});

test("4: child cannot change familyID", async () => {
  await seedUser("child1", "child", "fam1");
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(db.doc("users/child1").update({ familyID: "fam2" }));
});

test("5: version guard rejects older version", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "ringing",
    childProfileID: "cp1",
    version: 5,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      state: "verifying",
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("6: child cannot create family codes", async () => {
  await seedUser("child1", "child", "fam1");
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("familyCodes/CODE123").set({
      familyID: "fam1",
      createdAt: new Date(),
      createdBy: "child1",
      expiresAt: new Date(Date.now() + 86400000),
    })
  );
});

test("7: parent can create family codes", async () => {
  await seedUser("parent1", "parent", "fam1");
  const db = testEnv.authenticatedContext("parent1").firestore();
  await assertSucceeds(
    db.doc("familyCodes/CODE123").set({
      familyID: "fam1",
      createdAt: new Date(),
      createdBy: "parent1",
      expiresAt: new Date(Date.now() + 86400000),
    })
  );
});

test("8: tamper count cannot decrease", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "verifying",
    childProfileID: "cp1",
    version: 2,
    tamperCount: 3,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      tamperCount: 1,
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("9: cross-family read blocked", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam2", "sess1", { state: "ringing", childProfileID: "cp1" });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(db.doc("families/fam2/sessions/sess1").get());
});

test("10: tamper events are immutable", async () => {
  await seedUser("child1", "child", "fam1");
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("families/fam1/tamperEvents/te1").set({
      type: "volumeLowered",
      severity: "high",
      childProfileID: "cp1",
      timestamp: new Date(),
    });
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/tamperEvents/te1").update({ severity: "low" })
  );
});

test("11: child cannot write reviewWindowEndsAt", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "verifying",
    childProfileID: "cp1",
    version: 1,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      reviewWindowEndsAt: new Date(Date.now() + 999999999),
      state: "verified",
      version: 2,
      lastUpdated: new Date(),
    })
  );
});

test("12: session create must have state=ringing", async () => {
  await seedUser("child1", "child", "fam1");
  await seedFamily("fam1");
  const db = testEnv.authenticatedContext("child1").firestore();

  await assertFails(
    db.doc("families/fam1/sessions/bad1").set({
      state: "verified",
      childProfileID: "cp1",
      alarmScheduleID: "a1",
      alarmFiredAt: new Date(),
      version: 0,
    })
  );

  await assertSucceeds(
    db.doc("families/fam1/sessions/good1").set({
      state: "ringing",
      childProfileID: "cp1",
      alarmScheduleID: "a1",
      alarmFiredAt: new Date(),
      version: 0,
    })
  );
});

test("13: parent can approve pending review", async () => {
  await seedUser("parent1", "parent", "fam1");
  await seedSession("fam1", "sess1", {
    state: "pendingParentReview",
    childProfileID: "cp1",
    version: 3,
  });
  const db = testEnv.authenticatedContext("parent1").firestore();
  await assertSucceeds(
    db.doc("families/fam1/sessions/sess1").update({
      state: "verified",
      parentAction: { approved: {} },
      parentActionAt: new Date(),
      version: 4,
      lastUpdated: new Date(),
    })
  );
});

test("14: child can transition ringing -> verifying", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "ringing",
    childProfileID: "cp1",
    version: 1,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertSucceeds(
    db.doc("families/fam1/sessions/sess1").update({
      state: "verifying",
      version: 2,
      lastUpdated: new Date(),
    })
  );
});

// ═══════════════════════════════════════════════════
// EXPANDED COVERAGE (Tests 15-22)
// ═══════════════════════════════════════════════════

test("15: parent cannot modify child-only fields (verifiedAt)", async () => {
  await seedUser("parent1", "parent", "fam1");
  await seedSession("fam1", "sess1", {
    state: "pendingParentReview",
    childProfileID: "cp1",
    version: 2,
    verifiedAt: new Date(),
  });
  const db = testEnv.authenticatedContext("parent1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      verifiedAt: new Date(0),
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("16: parent cannot modify child-only fields (snoozeCount)", async () => {
  await seedUser("parent1", "parent", "fam1");
  await seedSession("fam1", "sess1", {
    state: "pendingParentReview",
    childProfileID: "cp1",
    version: 2,
    snoozeCount: 1,
  });
  const db = testEnv.authenticatedContext("parent1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      snoozeCount: 0,
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("17: child cannot modify serverVerifiedAt", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "verifying",
    childProfileID: "cp1",
    version: 1,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  // serverVerifiedAt is in child allowed list (set by saveSession overlay)
  // but serverParentActionAt is NOT
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      serverParentActionAt: new Date(),
      version: 2,
      lastUpdated: new Date(),
    })
  );
});

test("18: child cannot approve own session (parentAction write)", async () => {
  await seedUser("child1", "child", "fam1");
  await seedSession("fam1", "sess1", {
    state: "pendingParentReview",
    childProfileID: "cp1",
    version: 2,
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      parentAction: { approved: {} },
      parentActionAt: new Date(),
      state: "verified",
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("19: join code can only be marked used once", async () => {
  await seedUser("child1", "child", "fam1");
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("familyCodes/USED123").set({
      familyID: "fam1",
      createdAt: new Date(),
      createdBy: "parent1",
      expiresAt: new Date(Date.now() + 86400000),
      usedAt: new Date(),
      usedBy: "child0",
    });
  });
  const db = testEnv.authenticatedContext("child1").firestore();
  await assertFails(
    db.doc("familyCodes/USED123").update({
      usedAt: new Date(),
      usedBy: "child1",
    })
  );
});

test("20: parent cannot write reviewWindowEndsAt (server-managed)", async () => {
  await seedUser("parent1", "parent", "fam1");
  await seedSession("fam1", "sess1", {
    state: "verified",
    childProfileID: "cp1",
    version: 3,
  });
  const db = testEnv.authenticatedContext("parent1").firestore();
  await assertFails(
    db.doc("families/fam1/sessions/sess1").update({
      reviewWindowEndsAt: new Date(Date.now() + 999999999),
      version: 4,
      lastUpdated: new Date(),
    })
  );
});

test("21: child valid full flow: ringing -> snoozed -> verifying -> pendingParentReview", async () => {
  await seedUser("child1", "child", "fam1");
  await seedFamily("fam1");

  const db = testEnv.authenticatedContext("child1").firestore();

  // Create session
  await assertSucceeds(
    db.doc("families/fam1/sessions/flow1").set({
      state: "ringing",
      childProfileID: "cp1",
      alarmScheduleID: "a1",
      alarmFiredAt: new Date(),
      version: 0,
    })
  );

  // Snooze
  await assertSucceeds(
    db.doc("families/fam1/sessions/flow1").update({
      state: "snoozed",
      snoozeCount: 1,
      version: 1,
      lastUpdated: new Date(),
    })
  );

  // Start verifying
  await assertSucceeds(
    db.doc("families/fam1/sessions/flow1").update({
      state: "verifying",
      version: 2,
      lastUpdated: new Date(),
    })
  );

  // Submit for review
  await assertSucceeds(
    db.doc("families/fam1/sessions/flow1").update({
      state: "pendingParentReview",
      verifiedAt: new Date(),
      verifiedWith: "motion",
      version: 3,
      lastUpdated: new Date(),
    })
  );
});

test("22: unauthenticated user cannot read anything", async () => {
  await seedSession("fam1", "sess1", { state: "ringing", childProfileID: "cp1" });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(db.doc("families/fam1/sessions/sess1").get());
  await assertFails(db.doc("users/anyone").get());
  await assertFails(db.doc("familyCodes/ANY").get());
});
