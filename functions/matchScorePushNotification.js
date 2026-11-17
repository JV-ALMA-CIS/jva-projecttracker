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
 * Public URL of the hosted web app. Used as the web-push click-through link
 * (`webpush.fcmOptions.link`): the Firebase Messaging service worker opens/
 * focuses this URL when a browser notification is clicked, and the app reads
 * the `opportunityId` query parameter on startup to deep-link (see
 * PushNotificationService.initialize). FCM requires an absolute https URL.
 */
const WEB_APP_URL = "https://jva-projecttracker.web.app/";

/**
 * Notification copy per push type. `matchScore` is an existing opportunity
 * whose score crossed into a new >=70% band; `newOpportunity` is a freshly
 * discovered opportunity that already qualifies (either created with a high
 * fit score, or auto-scored by Match Analysis right after creation); `test`
 * is the Settings screen's "Send test notification" button.
 */
const KIND_WORDS = { tender: "tender", grant: "grant / call", programme: "programme" };

/** "23 Sep 2026" from an ISO date string; "" if missing/invalid. */
function shortDate(iso) {
  const d = iso ? new Date(iso) : null;
  if (!d || Number.isNaN(d.getTime())) return "";
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "Africa/Nairobi" });
}

function notificationCopy(type, { opportunityTitle, score, kind, daysLeft, deadline }) {
  const title = opportunityTitle || "An opportunity";
  if (type === "watchedCallOpen") {
    const when = shortDate(deadline);
    return { title: `New call open${when ? ` — deadline ${when}` : ""}`, body: title };
  }
  if (type === "watchedCallExtended") {
    const when = shortDate(deadline);
    return { title: `Deadline extended${when ? ` to ${when}` : ""}`, body: title };
  }
  if (type === "newOpportunity") {
    const kindWord = KIND_WORDS[kind] || "opportunity";
    return { title: `New ${kindWord} — ${score}% match`, body: title };
  }
  if (type === "deadline") {
    const when = daysLeft <= 0 ? "today" : daysLeft === 1 ? "tomorrow" : `in ${daysLeft} days`;
    return { title: `Deadline ${when}`, body: title };
  }
  if (type === "test") {
    return {
      title: "JVA Project Tracker test notification",
      body: "Notifications are working on this device.",
    };
  }
  return {
    title: "Strong opportunity match",
    body: `${title} is now a ${score}% match.`,
  };
}

/**
 * Builds the FCM message payload for one push token. The `data.opportunityId`
 * field is what lets the client (`opportunityIdFromMessageData` in
 * push_notification_service.dart) deep-link a notification tap straight to
 * the relevant opportunity, in every app state — keep the key name
 * (`kNotificationDataOpportunityIdKey`) in sync with that file if it ever
 * changes. `data` values must all be strings (an FCM requirement).
 *
 * Per-platform delivery settings, so the notification actually pops up
 * rather than landing silently in the tray:
 * - android: high priority + the "general" channel, which MainActivity.kt
 *   creates with IMPORTANCE_HIGH (heads-up banner + sound).
 * - apns: default sound; foreground display is enabled client-side via
 *   setForegroundNotificationPresentationOptions.
 * - webpush: Urgency high + a click-through link carrying the opportunity id.
 *   The browser shows the `notification` payload itself (via the Firebase
 *   service worker) — firebase-messaging-sw.js must NOT also call
 *   showNotification, or every push would appear twice.
 *
 * Exported so the exact notification copy/payload shape is independently
 * testable without a live Firestore trigger or a real messaging call.
 */
function buildNotificationMessage(
  token,
  { opportunityTitle, opportunityId, score, kind, daysLeft, deadline, type = "matchScore" },
) {
  const { title, body } = notificationCopy(type, { opportunityTitle, score, kind, daysLeft, deadline });
  const data = { type };
  let link = WEB_APP_URL;
  if (opportunityId != null) {
    data.opportunityId = String(opportunityId);
    link = `${WEB_APP_URL}?opportunityId=${encodeURIComponent(String(opportunityId))}`;
  }
  return {
    token,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: { channelId: "general", defaultSound: true },
    },
    apns: {
      payload: { aps: { sound: "default" } },
    },
    webpush: {
      headers: { Urgency: "high" },
      notification: { icon: "/icons/Icon-192.png" },
      fcmOptions: { link },
    },
  };
}

/**
 * Every saved FCM token for every user, deduplicated by token — the whole
 * team should see every qualifying tender (this is an internal tool used
 * only by company staff, so there is no narrower audience to target). Each
 * entry carries the token's Firestore `ref` so [sendToTokens] can delete
 * tokens FCM reports as permanently invalid. Returns `[]` (never throws) if
 * there are no users or no tokens anywhere — the caller logs and exits
 * cleanly in that case.
 *
 * Pass [uid] to collect only that one user's tokens (used by the
 * sendTestNotification callable).
 */
async function collectRecipientTokens(firestoreDb = db(), { uid } = {}) {
  let userRefs;
  if (uid) {
    userRefs = [firestoreDb.collection("users").doc(uid)];
  } else {
    const usersSnap = await firestoreDb.collection("users").get();
    if (usersSnap.empty) return [];
    userRefs = usersSnap.docs.map((d) => d.ref);
  }

  const tokenLists = await Promise.all(
    userRefs.map(async (userRef) => {
      const tokensSnap = await userRef.collection("fcmTokens").get();
      return tokensSnap.docs.map((d) => ({ token: d.id, ref: d.ref }));
    }),
  );

  const seen = new Set();
  const result = [];
  for (const entry of tokenLists.flat()) {
    if (seen.has(entry.token)) continue;
    seen.add(entry.token);
    result.push(entry);
  }
  return result;
}

/** FCM error codes meaning the token will never work again and should be removed. */
const STALE_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Sends one push (built via [buildNotificationMessage]) to every entry in
 * [recipients] (`{token, ref}` from [collectRecipientTokens]) via `sendEach`,
 * in chunks of 500 (FCM's per-call limit). Per-token failures are logged but
 * never thrown — one bad token must not fail the whole send. Tokens FCM
 * reports as permanently invalid (uninstalled app, cleared browser data,
 * etc.) are deleted from Firestore so they stop being targeted.
 * Returns `{successCount, failureCount}` for the caller's summary log.
 */
async function sendToTokens(recipients, payload, messagingClient = admin.messaging()) {
  if (recipients.length === 0) return { successCount: 0, failureCount: 0 };

  let successCount = 0;
  let failureCount = 0;
  for (let i = 0; i < recipients.length; i += 500) {
    const chunk = recipients.slice(i, i + 500);
    const messages = chunk.map(({ token }) => buildNotificationMessage(token, payload));
    const response = await messagingClient.sendEach(messages);
    successCount += response.successCount;
    failureCount += response.failureCount;

    const staleDeletes = [];
    response.responses.forEach((result, j) => {
      if (result.success) return;
      const code = result.error?.code || result.error?.message || "unknown error";
      logger.warn(`push to token ${String(chunk[j].token).slice(0, 12)}… failed: ${code}`);
      if (STALE_TOKEN_ERROR_CODES.has(code) && chunk[j].ref) {
        staleDeletes.push(Promise.resolve(chunk[j].ref.delete()).catch(() => {}));
      }
    });
    if (staleDeletes.length > 0) {
      await Promise.all(staleDeletes);
      logger.info(`removed ${staleDeletes.length} stale FCM token(s)`);
    }
  }

  return { successCount, failureCount };
}

/**
 * Collects every user's tokens and sends one notification of [type] about
 * the given opportunity. Never throws — a failed push must never fail the
 * Firestore write that triggered it.
 */
async function notifyAllUsers(payload, { firestoreDb, messagingClient } = {}) {
  const { type, opportunityId } = payload;
  try {
    const recipients = await collectRecipientTokens(firestoreDb);
    if (recipients.length === 0) {
      logger.info(`notifyAllUsers(${type}): no FCM tokens saved — skipping push for ${opportunityId}`);
      return { successCount: 0, failureCount: 0 };
    }
    const result = await sendToTokens(recipients, payload, messagingClient);
    logger.info(
      `notifyAllUsers(${type}): opportunity ${opportunityId} — ` +
        `${result.successCount} succeeded, ${result.failureCount} failed, ${recipients.length} token(s)`,
    );
    return result;
  } catch (e) {
    logger.error(`notifyAllUsers(${type}): failed for opportunity ${opportunityId}`, e);
    return { successCount: 0, failureCount: 0 };
  }
}

/**
 * Fires exactly when an opportunity's match score crosses into a new ≥70%
 * decade bucket (same event MatchNotificationWatcher/
 * shouldMarkMatchNotificationSent already reacts to client-side for the
 * in-app durable mark) and sends a real push via admin.messaging().sendEach
 * to every user's saved FCM token(s) (see collectRecipientTokens). Carries
 * the opportunity id as a data payload so a tap deep-links straight to it
 * (see buildNotificationMessage). This is also how auto-scored new tenders
 * notify: onOpportunityCreated (index.js) runs Match Analysis on unscored
 * tenders, and the resulting score write lands here. Every failure mode (no
 * users at all, no tokens saved, an individual
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

    // The first-ever Match Analysis on a freshly discovered opportunity
    // (the auto-scoring onOpportunityCreated runs for unscored tenders)
    // reads as "new opportunity", not "score changed".
    const isFirstAnalysis = !before.matchAnalyzedAt && !!after.matchAnalyzedAt;
    await notifyAllUsers({
      type: isFirstAnalysis ? "newOpportunity" : "matchScore",
      opportunityId,
      opportunityTitle: after.title,
      score,
      kind: after.kind,
    });
  },
);

module.exports.matchScoreBucket = matchScoreBucket;
module.exports.matchNotifyScoreFor = matchNotifyScoreFor;
module.exports.shouldSendMatchScorePush = shouldSendMatchScorePush;
module.exports.buildNotificationMessage = buildNotificationMessage;
module.exports.collectRecipientTokens = collectRecipientTokens;
module.exports.sendToTokens = sendToTokens;
module.exports.notifyAllUsers = notifyAllUsers;
module.exports.MATCH_SCORE_NOTIFY_THRESHOLD = MATCH_SCORE_NOTIFY_THRESHOLD;
