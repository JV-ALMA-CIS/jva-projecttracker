/**
 * Plain-Node assertion tests for matchScorePushNotification.js — same
 * convention as businessUnitMatching.test.js. Mirrors the equivalent Dart
 * tests in test/notification_builder_match_notification_watcher_test.dart —
 * this JS logic must stay in sync with notification_builder.dart's
 * matchNotifyScoreFor/matchScoreBucket/shouldMarkMatchNotificationSent, so
 * the same cases are exercised here against this file's re-implementation.
 *
 * Run with:
 *   node functions/matchScorePushNotification.test.js
 */
const assert = require("node:assert/strict");
const {
  matchScoreBucket,
  matchNotifyScoreFor,
  shouldSendMatchScorePush,
  buildNotificationMessage,
  collectRecipientTokens,
  sendToTokens,
  notifyAllUsers,
} = require("./matchScorePushNotification");

let passed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`  ok - ${name}`);
  } catch (e) {
    console.error(`  FAIL - ${name}`);
    console.error(e);
    process.exitCode = 1;
  }
}

async function asyncTest(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`  ok - ${name}`);
  } catch (e) {
    console.error(`  FAIL - ${name}`);
    console.error(e);
    process.exitCode = 1;
  }
}

console.log("matchScorePushNotification.test.js");

function opportunity({
  overallMatchScore,
  fitScorePercent = 0,
  status = "reviewing",
} = {}) {
  return { overallMatchScore, fitScorePercent, status };
}

// --- matchScoreBucket ----------------------------------------------------

test("matchScoreBucket buckets scores into their ten-point band", () => {
  assert.equal(matchScoreBucket(70), 70);
  assert.equal(matchScoreBucket(79), 70);
  assert.equal(matchScoreBucket(80), 80);
  assert.equal(matchScoreBucket(99), 90);
});

// --- matchNotifyScoreFor --------------------------------------------------

test("matchNotifyScoreFor returns overallMatchScore when set and >= threshold", () => {
  assert.equal(matchNotifyScoreFor(opportunity({ overallMatchScore: 72 })), 72);
});

test("matchNotifyScoreFor falls back to fitScorePercent when overallMatchScore is unset", () => {
  assert.equal(matchNotifyScoreFor(opportunity({ fitScorePercent: 75 })), 75);
});

test("matchNotifyScoreFor returns null when below threshold", () => {
  assert.equal(matchNotifyScoreFor(opportunity({ overallMatchScore: 65 })), null);
});

for (const status of ["won", "lost", "dismissed"]) {
  test(`matchNotifyScoreFor returns null for a ${status} opportunity even with a high score`, () => {
    assert.equal(
      matchNotifyScoreFor(opportunity({ overallMatchScore: 95, status })),
      null,
    );
  });
}

// --- shouldSendMatchScorePush --------------------------------------------

test("true when a fresh Match Analysis run first pushes the score over the threshold (no prior qualifying score)", () => {
  const before = opportunity({ overallMatchScore: undefined, fitScorePercent: 40 });
  const after = opportunity({ overallMatchScore: 72 });
  assert.equal(shouldSendMatchScorePush(before, after), true);
});

test("false when the score stays below threshold before and after", () => {
  const before = opportunity({ overallMatchScore: 50 });
  const after = opportunity({ overallMatchScore: 60 });
  assert.equal(shouldSendMatchScorePush(before, after), false);
});

test("false when the score moves within the same decade bucket (72 -> 74)", () => {
  const before = opportunity({ overallMatchScore: 72 });
  const after = opportunity({ overallMatchScore: 74 });
  assert.equal(shouldSendMatchScorePush(before, after), false);
});

test("true when the score crosses into a new decade bucket (72 -> 85)", () => {
  const before = opportunity({ overallMatchScore: 72 });
  const after = opportunity({ overallMatchScore: 85 });
  assert.equal(shouldSendMatchScorePush(before, after), true);
});

test("false when the score drops out of notify-worthy range entirely", () => {
  const before = opportunity({ overallMatchScore: 75 });
  const after = opportunity({ overallMatchScore: 40 });
  assert.equal(shouldSendMatchScorePush(before, after), false);
});

test("false for a closed opportunity even if this write raised its score into a new bucket", () => {
  const before = opportunity({ overallMatchScore: 72, status: "won" });
  const after = opportunity({ overallMatchScore: 85, status: "won" });
  assert.equal(shouldSendMatchScorePush(before, after), false);
});

test("false when this write is unrelated to score (same bucket, only title changed)", () => {
  const before = opportunity({ overallMatchScore: 72 });
  const after = opportunity({ overallMatchScore: 72 });
  assert.equal(shouldSendMatchScorePush(before, after), false);
});

// --- buildNotificationMessage ---------------------------------------------

test("builds a title/body notification for the given token, opportunity title, and score", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityTitle: "Rural water tender",
    opportunityId: "opp-1",
    score: 82,
  });

  assert.equal(message.token, "token-1");
  assert.equal(message.notification.title, "Strong opportunity match");
  assert.equal(
    message.notification.body,
    "Rural water tender is now a 82% match.",
  );
});

test("falls back to a generic opportunity reference when the title is missing", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityId: "opp-1",
    score: 75,
  });
  assert.equal(
    message.notification.body,
    "An opportunity is now a 75% match.",
  );
});

test("carries the opportunity id as a string data payload for client-side deep-linking", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityTitle: "Tender",
    opportunityId: "opp-42",
    score: 80,
  });
  assert.deepEqual(message.data, { type: "matchScore", opportunityId: "opp-42" });
});

test("targets the 'general' Android channel at high priority so it shows as a heads-up banner", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityTitle: "Tender",
    opportunityId: "opp-42",
    score: 80,
  });
  assert.equal(message.android.notification.channelId, "general");
  assert.equal(message.android.priority, "high");
});

test("newOpportunity type uses 'New opportunity' copy with the score in the title", () => {
  const message = buildNotificationMessage("token-1", {
    type: "newOpportunity",
    opportunityTitle: "Rosslyn compound roof replacement",
    opportunityId: "opp-7",
    score: 84,
  });
  assert.equal(message.notification.title, "New opportunity — 84% match");
  assert.equal(message.notification.body, "Rosslyn compound roof replacement");
  assert.deepEqual(message.data, { type: "newOpportunity", opportunityId: "opp-7" });
});

test("web push links to the hosted app with the opportunity id for deep-linking", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityTitle: "Tender",
    opportunityId: "opp 42",
    score: 80,
  });
  assert.equal(
    message.webpush.fcmOptions.link,
    "https://jva-projecttracker.web.app/?opportunityId=opp%2042",
  );
  assert.equal(message.webpush.headers.Urgency, "high");
});

test("test type carries no opportunity id and links to the app root", () => {
  const message = buildNotificationMessage("token-1", { type: "test" });
  assert.deepEqual(message.data, { type: "test" });
  assert.equal(message.webpush.fcmOptions.link, "https://jva-projecttracker.web.app/");
});

test("newOpportunity copy names the kind — grant / call", () => {
  const message = buildNotificationMessage("token-1", {
    type: "newOpportunity",
    kind: "grant",
    opportunityTitle: "ABIL EXPLORE Kenya Open Call",
    opportunityId: "opp-9",
    score: 88,
  });
  assert.equal(message.notification.title, "New grant / call — 88% match");
});

test("newOpportunity copy falls back to 'opportunity' when kind is missing", () => {
  const message = buildNotificationMessage("token-1", {
    type: "newOpportunity",
    opportunityTitle: "Tender",
    opportunityId: "opp-1",
    score: 75,
  });
  assert.equal(message.notification.title, "New opportunity — 75% match");
});

test("deadline copy says 'in N days', 'tomorrow' and 'today'", () => {
  const title = (daysLeft) =>
    buildNotificationMessage("t", { type: "deadline", opportunityId: "o", opportunityTitle: "X", daysLeft })
      .notification.title;
  assert.equal(title(14), "Deadline in 14 days");
  assert.equal(title(1), "Deadline tomorrow");
  assert.equal(title(0), "Deadline today");
});

// --- collectRecipientTokens ------------------------------------------------

/**
 * Minimal fake Firestore shaped exactly like collectRecipientTokens uses it:
 * db.collection("users").get() -> docs with .ref; .doc(uid) -> a ref;
 * ref.collection("fcmTokens").get() -> docs with .id and .ref.delete().
 * [users] is a list of {id, role, tokens: [tokenId, ...]}. Deleted token ids
 * are recorded in the returned `deleted` array.
 */
function fakeUsersDb(users) {
  const deleted = [];
  const userRef = (u) => ({
    collection(sub) {
      assert.equal(sub, "fcmTokens");
      return {
        async get() {
          return {
            docs: (u.tokens || []).map((t) => ({
              id: t,
              ref: { async delete() { deleted.push(t); } },
            })),
          };
        },
      };
    },
  });
  return {
    deleted,
    collection(name) {
      assert.equal(name, "users");
      return {
        doc(id) {
          return userRef(users.find((u) => u.id === id) || { id, tokens: [] });
        },
        async get() {
          return {
            empty: users.length === 0,
            docs: users.map((u) => ({ id: u.id, data: () => ({ role: u.role }), ref: userRef(u) })),
          };
        },
      };
    },
  };
}

const tokensOf = (recipients) => recipients.map((r) => r.token).sort();

(async () => {
  await asyncTest(
    "collectRecipientTokens returns every user's tokens regardless of role",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "admin", tokens: ["t1", "t2"] },
        { id: "u2", role: "user", tokens: ["t3"] },
      ]);
      assert.deepEqual(tokensOf(await collectRecipientTokens(db)), ["t1", "t2", "t3"]);
    },
  );

  await asyncTest(
    "collectRecipientTokens deduplicates a token saved under two accounts",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "user", tokens: ["shared"] },
        { id: "u2", role: "user", tokens: ["shared", "t2"] },
      ]);
      assert.deepEqual(tokensOf(await collectRecipientTokens(db)), ["shared", "t2"]);
    },
  );

  await asyncTest(
    "collectRecipientTokens with a uid returns only that user's tokens",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "user", tokens: ["t1"] },
        { id: "u2", role: "user", tokens: ["t2"] },
      ]);
      assert.deepEqual(tokensOf(await collectRecipientTokens(db, { uid: "u2" })), ["t2"]);
    },
  );

  await asyncTest(
    "collectRecipientTokens returns [] when the users collection is empty",
    async () => {
      assert.deepEqual(await collectRecipientTokens(fakeUsersDb([])), []);
    },
  );

  await asyncTest(
    "collectRecipientTokens returns [] when users exist but none have saved a token",
    async () => {
      const db = fakeUsersDb([{ id: "u1", role: "admin", tokens: [] }]);
      assert.deepEqual(await collectRecipientTokens(db), []);
    },
  );

  // --- sendToTokens --------------------------------------------------------

  await asyncTest(
    "sendToTokens returns {successCount: 0, failureCount: 0} without calling messaging when there are no tokens",
    async () => {
      let called = false;
      const fakeMessaging = {
        async sendEach() {
          called = true;
          return { responses: [], successCount: 0, failureCount: 0 };
        },
      };
      const result = await sendToTokens([], { opportunityTitle: "Tender", score: 80 }, fakeMessaging);
      assert.equal(called, false);
      assert.deepEqual(result, { successCount: 0, failureCount: 0 });
    },
  );

  await asyncTest(
    "sendToTokens sends one message per token and returns the aggregate success/failure counts",
    async () => {
      let receivedMessages;
      const fakeMessaging = {
        async sendEach(messages) {
          receivedMessages = messages;
          return {
            responses: messages.map(() => ({ success: true })),
            successCount: messages.length,
            failureCount: 0,
          };
        },
      };
      const result = await sendToTokens(
        [{ token: "t1" }, { token: "t2" }],
        { opportunityTitle: "Tender", score: 80 },
        fakeMessaging,
      );
      assert.equal(receivedMessages.length, 2);
      assert.equal(receivedMessages[0].token, "t1");
      assert.equal(receivedMessages[1].token, "t2");
      assert.deepEqual(result, { successCount: 2, failureCount: 0 });
    },
  );

  await asyncTest(
    "sendToTokens deletes tokens FCM reports as unregistered, but keeps tokens with transient errors",
    async () => {
      const deleted = [];
      const ref = (t) => ({ async delete() { deleted.push(t); } });
      const fakeMessaging = {
        async sendEach() {
          return {
            responses: [
              { success: true },
              { success: false, error: { code: "messaging/registration-token-not-registered" } },
              { success: false, error: { code: "messaging/internal-error" } },
            ],
            successCount: 1,
            failureCount: 2,
          };
        },
      };
      const result = await sendToTokens(
        [
          { token: "ok", ref: ref("ok") },
          { token: "stale", ref: ref("stale") },
          { token: "flaky", ref: ref("flaky") },
        ],
        { opportunityTitle: "Tender", score: 80 },
        fakeMessaging,
      );
      assert.deepEqual(result, { successCount: 1, failureCount: 2 });
      assert.deepEqual(deleted, ["stale"]);
    },
  );

  // --- notifyAllUsers ------------------------------------------------------

  await asyncTest(
    "notifyAllUsers sends a newOpportunity push to every user's devices",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "admin", tokens: ["t1"] },
        { id: "u2", role: "user", tokens: ["t2"] },
      ]);
      let sent;
      const fakeMessaging = {
        async sendEach(messages) {
          sent = messages;
          return { responses: messages.map(() => ({ success: true })), successCount: messages.length, failureCount: 0 };
        },
      };
      const result = await notifyAllUsers(
        { type: "newOpportunity", opportunityId: "opp-1", opportunityTitle: "Tender", score: 90 },
        { firestoreDb: db, messagingClient: fakeMessaging },
      );
      assert.deepEqual(result, { successCount: 2, failureCount: 0 });
      assert.deepEqual(sent.map((m) => m.token).sort(), ["t1", "t2"]);
      assert.equal(sent[0].data.type, "newOpportunity");
    },
  );

  await asyncTest(
    "notifyAllUsers never throws when messaging fails outright",
    async () => {
      const db = fakeUsersDb([{ id: "u1", role: "user", tokens: ["t1"] }]);
      const fakeMessaging = { async sendEach() { throw new Error("FCM down"); } };
      const result = await notifyAllUsers(
        { type: "newOpportunity", opportunityId: "opp-1", score: 90 },
        { firestoreDb: db, messagingClient: fakeMessaging },
      );
      assert.deepEqual(result, { successCount: 0, failureCount: 0 });
    },
  );

  console.log(`\n${passed} test(s) passed`);
})();
