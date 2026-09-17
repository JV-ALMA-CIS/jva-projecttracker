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

test("targets the default 'general' Android notification channel", () => {
  const message = buildNotificationMessage("token-1", {
    opportunityTitle: "Tender",
    opportunityId: "opp-42",
    score: 80,
  });
  assert.equal(message.android.notification.channelId, "general");
});

// --- collectRecipientTokens ------------------------------------------------

/**
 * Minimal fake Firestore shaped exactly like collectRecipientTokens uses it:
 * db.collection("users").get() -> docs with .data() and .ref.collection(
 * "fcmTokens").get() -> docs with .id. [users] is a list of
 * {id, role, tokens: [tokenId, ...]}.
 */
function fakeUsersDb(users) {
  return {
    collection(name) {
      assert.equal(name, "users");
      return {
        async get() {
          return {
            empty: users.length === 0,
            docs: users.map((u) => ({
              id: u.id,
              data: () => ({ role: u.role }),
              ref: {
                collection(sub) {
                  assert.equal(sub, "fcmTokens");
                  return {
                    async get() {
                      return { docs: (u.tokens || []).map((t) => ({ id: t })) };
                    },
                  };
                },
              },
            })),
          };
        },
      };
    },
  };
}

(async () => {
  await asyncTest(
    "collectRecipientTokens returns every admin's tokens when at least one admin exists",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "admin", tokens: ["t1", "t2"] },
        { id: "u2", role: "user", tokens: ["t3"] },
      ]);

      const tokens = await collectRecipientTokens(db);

      assert.deepEqual(tokens.sort(), ["t1", "t2"]);
    },
  );

  await asyncTest(
    "collectRecipientTokens falls back to every user's tokens when there are no admins",
    async () => {
      const db = fakeUsersDb([
        { id: "u1", role: "user", tokens: ["t1"] },
        { id: "u2", role: "user", tokens: ["t2"] },
      ]);

      const tokens = await collectRecipientTokens(db);

      assert.deepEqual(tokens.sort(), ["t1", "t2"]);
    },
  );

  await asyncTest(
    "collectRecipientTokens returns [] when the users collection is empty",
    async () => {
      const db = fakeUsersDb([]);
      const tokens = await collectRecipientTokens(db);
      assert.deepEqual(tokens, []);
    },
  );

  await asyncTest(
    "collectRecipientTokens returns [] when admins exist but none have saved a token",
    async () => {
      const db = fakeUsersDb([{ id: "u1", role: "admin", tokens: [] }]);
      const tokens = await collectRecipientTokens(db);
      assert.deepEqual(tokens, []);
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

      const result = await sendToTokens(
        [],
        { opportunityTitle: "Tender", score: 80 },
        fakeMessaging,
      );

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
        ["t1", "t2"],
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
    "sendToTokens does not throw when an individual token fails to deliver — logs and reports the failure count",
    async () => {
      const fakeMessaging = {
        async sendEach(messages) {
          return {
            responses: [
              { success: true },
              { success: false, error: { code: "messaging/registration-token-not-registered" } },
            ],
            successCount: 1,
            failureCount: 1,
          };
        },
      };

      const result = await sendToTokens(
        ["t1", "t2-stale"],
        { opportunityTitle: "Tender", score: 80 },
        fakeMessaging,
      );

      assert.deepEqual(result, { successCount: 1, failureCount: 1 });
    },
  );

  console.log(`\n${passed} test(s) passed`);
})();
