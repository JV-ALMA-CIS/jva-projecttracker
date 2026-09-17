const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

/**
 * NOT ADDED TO index.js's setGlobalOptions/admin.initializeApp() here — this
 * module is require()'d from index.js so it shares the same
 * already-initialized `admin` app. Do not call admin.initializeApp() again
 * in this file. Same convention as tenderSourceSync.js's db().
 */
function db() {
  return admin.firestore();
}

/**
 * Mirrors lib/services/notification_builder.dart's kMatchScoreNotifyThreshold/
 * matchScoreBucket/shouldMarkMatchNotificationSent — the exact same
 * "notification-worthy score, bucketed by decade, renotify only on a new
 * bucket" decision the client already makes for the in-app durable mark
 * (Opportunity.lastNotifiedScore). Deliberately re-implemented here rather
 * than imported (Cloud Functions is a separate Node runtime, can't import
 * Dart) — kept in careful sync with the Dart source; if one changes, the
 * other must too. Do not change this logic without also updating
 * notification_builder.dart, and vice versa.
 */
const MATCH_SCORE_NOTIFY_THRESHOLD = 70;
const CLOSED_STATUSES = new Set(["won", "lost", "dismissed"]);

function matchScoreBucket(score) {
  return Math.floor(score / 10) * 10;
}

function matchNotifyScoreFor(opportunity) {
  if (CLOSED_STATUSES.has(opportunity.status)) return null;
  const score =
    typeof opportunity.overallMatchScore === "number"
      ? opportunity.overallMatchScore
      : opportunity.fitScorePercent || 0;
  if (score < MATCH_SCORE_NOTIFY_THRESHOLD) return null;
  return score;
}

/**
 * True when [after] (the opportunity document post-update) has just crossed
 * into a new notify-worthy decade bucket relative to [before] (its state
 * pre-update) — i.e. this specific write is the one that should trigger a
 * push, not a write that merely re-confirms an already-notified bucket or
 * moves the score within the same one. Exported for testing without
 * needing a live Firestore trigger.
 */
function shouldSendMatchScorePush(before, after) {
  const score = matchNotifyScoreFor(after);
  if (score == null) return false;

  const beforeScore = matchNotifyScoreFor(before);
  // Nothing to compare against pre-update (opportunity was never
  // notification-worthy before this write, e.g. a fresh Match Analysis run
  // pushing it over the threshold for the first time) — still a genuine
  // crossing, so this should fire.
  if (beforeScore == null) return true;

  return matchScoreBucket(beforeScore) !== matchScoreBucket(score);
}

/**
 * Builds the FCM message payload for one push token. The `data.opportunityId`
 * field is what lets the client (`opportunityIdFromMessageData` in
 * push_notification_service.dart) deep-link a notification tap straight to
 * the relevant opportunity, in every app state — keep the key name
 * (`kNotificationDataOpportunityIdKey`) in sync with that file if it ever
 * changes. `data` values must all be strings (an FCM requirement), hence
 * `String(opportunityId)`.
 *
 * `android.notification.channelId` targets the "general" channel declared in
 * `android/app/src/main/AndroidManifest.xml`'s
 * `com.google.firebase.messaging.default_notification_channel_id` meta-data
 * — redundant with that default today, but explicit here so a future second
 * channel doesn't silently redirect this notification type too.
 *
 * Exported so the exact notification copy/payload shape is independently
 * testable without a live Firestore trigger or a real messaging call.
 */
function buildNotificationMessage(token, { opportunityTitle, opportunityId, score }) {
  return {
    token,
    notification: {
      title: "Strong opportunity match",
      body: `${opportunityTitle || "An opportunity"} is now a ${score}% match.`,
    },
    data: {
      type: "matchScore",
      opportunityId: String(opportunityId),
    },
    android: {
      notification: { channelId: "general" },
    },
  };
}

/**
 * There is no reliable per-opportunity owner today — `Opportunity.assignedTo`
 * is a free-text field (no user-directory picker exists anywhere in this
 * app; see Project.assignedTo's own doc comment), so it cannot be resolved
 * to a `users/{uid}` document. Broadcasting to admins is the pragmatic
 * stand-in until real uid-based assignment exists: reads every `users` doc
 * with `role == "admin"`, then every token under each admin's
 * `fcmTokens` subcollection. Falls back to every user (any role) if there
 * are no admins at all, so a very small/newly-seeded team isn't silently
 * notified to nobody. Returns `[]` (never throws) if the `users` collection
 * is empty or has no tokens anywhere — the caller logs and exits cleanly in
 * that case rather than crashing the trigger.
 */
async function collectRecipientTokens(firestoreDb = db()) {
  const usersSnap = await firestoreDb.collection("users").get();
  if (usersSnap.empty) return [];

  const adminDocs = usersSnap.docs.filter((d) => d.data()?.role === "admin");
  const targetDocs = adminDocs.length > 0 ? adminDocs : usersSnap.docs;

  const tokenLists = await Promise.all(
    targetDocs.map(async (userDoc) => {
      const tokensSnap = await userDoc.ref.collection("fcmTokens").get();
      return tokensSnap.docs.map((d) => d.id);
    }),
  );
  return tokenLists.flat();
}

/**
 * Sends one push (built via [buildNotificationMessage]) to every token in
 * [tokens] via a single `sendEach` call (batches of up to 500 — well beyond
 * any realistic admin-token count today, so no chunking loop is needed yet).
 * Per-token delivery failures (an unregistered/expired token, a malformed
 * token, etc.) are logged individually but never thrown — one bad token
 * must not be treated as this function failing, since most tokens in the
 * same call likely still delivered fine. Returns `{successCount,
 * failureCount}` for the caller's own summary log.
 */
async function sendToTokens(tokens, payload, messagingClient = admin.messaging()) {
  if (tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const messages = tokens.map((token) => buildNotificationMessage(token, payload));
  const response = await messagingClient.sendEach(messages);

  response.responses.forEach((result, i) => {
    if (!result.success) {
      logger.warn(
        `onOpportunityMatchScoreUpdated: push to token ${tokens[i]} failed: ` +
          `${result.error?.code || result.error?.message || "unknown error"}`,
      );
    }
  });

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
  };
}

/**
 * Fires exactly when an opportunity's match score crosses into a new ≥70%
 * decade bucket (same event MatchNotificationWatcher/
 * shouldMarkMatchNotificationSent already reacts to client-side for the
 * in-app durable mark) and sends a real push via admin.messaging().sendEach
 * to every admin's saved FCM token(s) (see collectRecipientTokens's doc
 * comment for why "admin" rather than a per-opportunity owner). Carries the
 * opportunity id as a data payload so a tap deep-links straight to it (see
 * buildNotificationMessage). Every failure mode (no users at all, no tokens saved, an individual
 * send failure) is logged and swallowed rather than thrown, since a failed
 * push must never fail the underlying Firestore write this trigger reacts
 * to.
 */
exports.onOpportunityMatchScoreUpdated = onDocumentUpdated(
  "opportunities/{opportunityId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (!shouldSendMatchScorePush(before, after)) return;

    const score = matchNotifyScoreFor(after);
    const bucket = matchScoreBucket(score);
    const opportunityId = event.params.opportunityId;

    logger.info(
      `onOpportunityMatchScoreUpdated: opportunity ${opportunityId} crossed into the ${bucket}% bucket (score ${score})`,
    );

    try {
      const tokens = await collectRecipientTokens();
      if (tokens.length === 0) {
        logger.info(
          `onOpportunityMatchScoreUpdated: no recipient FCM tokens found — skipping push for opportunity ${opportunityId}`,
        );
        return;
      }

      const { successCount, failureCount } = await sendToTokens(tokens, {
        opportunityTitle: after.title,
        opportunityId,
        score,
      });
      logger.info(
        `onOpportunityMatchScoreUpdated: push sent for opportunity ${opportunityId} — ` +
          `${successCount} succeeded, ${failureCount} failed, ${tokens.length} token(s) targeted`,
      );
    } catch (e) {
      // A lookup/send failure must never fail the Firestore write this
      // trigger reacts to (the opportunity document itself already wrote
      // successfully by the time this trigger runs) — log and move on.
      logger.error(
        `onOpportunityMatchScoreUpdated: failed to send push for opportunity ${opportunityId}`,
        e,
      );
    }
  },
);

module.exports.matchScoreBucket = matchScoreBucket;
module.exports.matchNotifyScoreFor = matchNotifyScoreFor;
module.exports.shouldSendMatchScorePush = shouldSendMatchScorePush;
module.exports.buildNotificationMessage = buildNotificationMessage;
module.exports.collectRecipientTokens = collectRecipientTokens;
module.exports.sendToTokens = sendToTokens;
