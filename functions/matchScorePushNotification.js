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
  // Opportunities the company can't apply for alone (grantEligibility.js)
  // never alert instantly: not eligible, or only with outside partners
  // (e.g. Horizon consortium calls). They still show in the Monday summary.
  if (opportunity.eligibility === "notEligible" || opportunity.eligibility === "needsPartner") return null;
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

function notificationCopy(
  type,
  { opportunityTitle, score, kind, daysLeft, deadline, sharedByName, note, justAdded, summaryTitle, summaryBody },
) {
  const title = opportunityTitle || "An opportunity";
  if (type === "weeklySummary") {
    return { title: summaryTitle || "Weekly summary", body: summaryBody || "" };
  }
  if (type === "fundingSummary") {
    return { title: summaryTitle || "Funding open now", body: summaryBody || "" };
  }
  if (type === "teamShare") {
    const who = sharedByName || "A colleague";
    const kindWord = KIND_WORDS[kind] || "opportunity";
    return {
      title: `${who} ${justAdded ? "added" : "shared"} a ${kindWord}`,
      body: note ? `${title} — "${note}"` : title,
    };
  }
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
  {
    opportunityTitle,
    opportunityId,
    score,
    kind,
    daysLeft,
    deadline,
    sharedByName,
    note,
    justAdded,
    summaryTitle,
    summaryBody,
    type = "matchScore",
  },
) {
  const { title, body } = notificationCopy(type, {
    opportunityTitle,
    score,
    kind,
    daysLeft,
    deadline,
    sharedByName,
    note,
    justAdded,
    summaryTitle,
    summaryBody,
  });
  const data = { type };
  let link = WEB_APP_URL;
  // The weekly summary opens the Opportunity Inbox (app: data.open; web: ?open=inbox).
  if (type === "weeklySummary") {
    data.open = "inbox";
    link = `${WEB_APP_URL}?open=inbox`;
  }
  // "Funding open now" opens the Opportunity Inbox on its Grants tab.
  if (type === "fundingSummary") {
    data.open = "grants";
    link = `${WEB_APP_URL}?open=grants`;
  }
  if (opportunityId != null) {
    data.opportunityId = String(opportunityId);
    link = `${WEB_APP_URL}?opportunityId=${encodeURIComponent(String(opportunityId))}`;
  }
  const tag = tagFor(type, opportunityId);
  const sticky = STICKY_TYPES.has(type);
  const channelId = channelForType(type);
  const ttlSeconds = ttlSecondsFor(type);
  // Repeated in data so the app can show the same system notification
  // itself when the push arrives while it's open (PushNotificationService).
  Object.assign(data, { title, body, tag, sticky: sticky ? "1" : "0", channel: channelId, link });
  return {
    token,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      ttl: ttlSeconds * 1000,
      collapseKey: tag,
      notification: {
        channelId,
        defaultSound: true,
        tag,
        icon: "ic_stat_jva",
        color: NOTIFICATION_COLOR,
      },
    },
    apns: {
      headers: { "apns-collapse-id": tag.slice(0, 64) },
      payload: { aps: { sound: "default" } },
    },
    webpush: {
      headers: { Urgency: "high", TTL: String(ttlSeconds) },
      notification: {
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
        tag,
        renotify: true,
        requireInteraction: sticky,
      },
      fcmOptions: { link },
    },
  };
}

/** App navy (AppTheme.seedColor); tints the Android status-bar icon. */
const NOTIFICATION_COLOR = "#1A2B4C";

/**
 * Alerts about something we can still apply for stay on screen until the
 * person clicks or dismisses them (like an Outlook reminder) — on desktop
 * browsers via `requireInteraction`. Test and summary pushes fade normally.
 */
const STICKY_TYPES = new Set([
  "newOpportunity",
  "matchScore",
  "deadline",
  "watchedCallOpen",
  "watchedCallExtended",
  "teamShare",
]);

/**
 * Android channel per push type — ids must match MainActivity.kt and
 * kAndroidChannels in push_notification_service.dart. Older installs that
 * lack a channel fall back to the manifest default ("general").
 */
function channelForType(type) {
  switch (type) {
    case "newOpportunity":
    case "matchScore":
    case "watchedCallOpen":
    case "watchedCallExtended":
      return "opportunities";
    case "deadline":
      return "deadlines";
    case "teamShare":
      return "team";
    case "weeklySummary":
    case "fundingSummary":
      return "summary";
    default:
      return "general";
  }
}

/**
 * How long FCM keeps trying to deliver to a device that's off/offline. A
 * "deadline today" reminder or Monday summary arriving two days late is
 * noise; a new tender is still worth knowing about for a few days.
 */
function ttlSecondsFor(type) {
  if (type === "test") return 60 * 60;
  if (type === "deadline" || type === "weeklySummary" || type === "fundingSummary") return 24 * 60 * 60;
  return 3 * 24 * 60 * 60;
}

/**
 * Replace key: a newer alert about the same opportunity (e.g. its deadline
 * reminder) replaces the older one on screen instead of stacking up.
 */
function tagFor(type, opportunityId) {
  if (opportunityId != null) return `opp-${opportunityId}`;
  if (type === "weeklySummary") return "weekly-summary";
  if (type === "fundingSummary") return "funding-summary";
  return `jva-${type || "alert"}`;
}

/** Top-level device registry: one doc per FCM token, `{token, uid, platform, os, updatedAt, lastSentAt?}`. */
const DEVICE_TOKENS = "deviceTokens";
/** Old per-user location (`users/{uid}/fcmTokens/{token}`), still written by older app builds. */
const LEGACY_TOKENS = "fcmTokens";

/**
 * Every registered device for every signed-up employee, deduplicated by
 * token — the whole team sees every qualifying tender (internal tool, no
 * narrower audience). Each entry is `{token, uid, ref, legacyRef?}`; `ref`
 * is the `deviceTokens` doc so [sendToTokens] can delete dead tokens and
 * record the last send.
 *
 * Devices are read straight from the top-level `deviceTokens` registry, so
 * an account is reachable whether or not it has a `users/{uid}` profile doc.
 * (The old lookup walked `users` docs first, and Firestore never lists a
 * parent doc that doesn't exist, so any account without a profile silently
 * got no pushes.) Old-location tokens are found with a collection-group
 * query (which does see orphaned subcollections), moved into `deviceTokens`,
 * and still included in this send — older APKs keep writing there until
 * they're updated, so this keeps running on every send.
 *
 * Pass [uid] for one person's devices (sendTestNotification), [excludeUid]
 * to skip one person (team shares skip the sharer). Never returns duplicates.
 */
async function collectRecipientTokens(firestoreDb = db(), { uid, excludeUid } = {}) {
  const registry = firestoreDb.collection(DEVICE_TOKENS);
  const [deviceSnap, legacySnap] = await Promise.all([
    (uid ? registry.where("uid", "==", uid) : registry).get(),
    firestoreDb.collectionGroup(LEGACY_TOKENS).get(),
  ]);
  const wanted = (owner) => !!owner && (!uid || owner === uid) && owner !== excludeUid;

  const byToken = new Map();
  for (const d of deviceSnap.docs) {
    const owner = d.data().uid;
    if (wanted(owner)) byToken.set(d.id, { token: d.id, uid: owner, ref: d.ref });
  }

  const moves = [];
  for (const d of legacySnap.docs) {
    const owner = d.ref.parent?.parent?.id;
    if (!owner) continue;
    const token = d.id;
    const target = registry.doc(token);
    moves.push(moveLegacyToken(d, target, owner));
    if (!wanted(owner)) continue;
    const existing = byToken.get(token);
    if (existing) {
      existing.legacyRef = d.ref;
    } else {
      byToken.set(token, { token, uid: owner, ref: target, legacyRef: d.ref });
    }
  }
  if (moves.length > 0) {
    const results = await Promise.all(moves);
    const moved = results.filter(Boolean).length;
    if (moved > 0) logger.info(`collectRecipientTokens: moved ${moved} device(s) into ${DEVICE_TOKENS}`);
  }
  return [...byToken.values()];
}

/**
 * Copies one old-location token into `deviceTokens` (unless that token is
 * already registered there — the registry copy is always the newer one),
 * then deletes the old doc. Returns true if a new registry doc was written.
 * Never throws.
 */
async function moveLegacyToken(legacyDoc, target, owner) {
  let created = false;
  try {
    const data = legacyDoc.data ? legacyDoc.data() || {} : {};
    await target.create({
      token: legacyDoc.id,
      uid: owner,
      platform: "unknown",
      os: "unknown",
      updatedAt: data.updatedAt || new Date(),
      movedFromLegacyAt: new Date(),
    });
    created = true;
  } catch (e) {
    // ALREADY_EXISTS (gRPC code 6) just means the registry already has it.
    if (e?.code !== 6 && e?.code !== "already-exists") {
      logger.warn(`moveLegacyToken: could not copy a device for ${owner}: ${e?.message || e}`);
      return false;
    }
  }
  try {
    await legacyDoc.ref.delete();
  } catch (_) {
    // Harmless: it will be found and skipped again next send.
  }
  return created;
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
    const sentMarks = [];
    const sentAt = new Date();
    response.responses.forEach((result, j) => {
      const entry = chunk[j];
      if (result.success) {
        // Shown in Settings → "My devices" as "last alert sent". Best-effort.
        if (entry.ref?.update) {
          sentMarks.push(
            Promise.resolve(entry.ref.update({ lastSentAt: sentAt, lastSentType: payload.type || "matchScore" })).catch(
              () => {},
            ),
          );
        }
        return;
      }
      const code = result.error?.code || result.error?.message || "unknown error";
      logger.warn(`push to token ${String(entry.token).slice(0, 12)}… failed: ${code}`);
      if (!STALE_TOKEN_ERROR_CODES.has(code)) return;
      for (const ref of [entry.ref, entry.legacyRef]) {
        if (ref?.delete) staleDeletes.push(Promise.resolve(ref.delete()).catch(() => {}));
      }
    });
    await Promise.all(sentMarks);
    if (staleDeletes.length > 0) {
      await Promise.all(staleDeletes);
      logger.info(`removed ${staleDeletes.length} stale FCM token doc(s)`);
    }
  }

  return { successCount, failureCount };
}

/**
 * Collects every user's tokens and sends one notification of [type] about
 * the given opportunity. Never throws — a failed push must never fail the
 * Firestore write that triggered it.
 */
async function notifyAllUsers(payload, { firestoreDb, messagingClient, excludeUid } = {}) {
  const { type, opportunityId } = payload;
  try {
    const recipients = await collectRecipientTokens(firestoreDb, { excludeUid });
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
    // Added by hand: the person who added it already shared it with the
    // team (shareOpportunityWithTeam), so its first score isn't news.
    if (isFirstAnalysis && after.addedByUid) return;
    // Saved on a watcher's first look at a page (tenderPageWatchlist.js):
    // scored for ranking, but the backlog doesn't alert one by one.
    if (isFirstAnalysis && after.scoreQuietly) return;
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
module.exports.DEVICE_TOKENS = DEVICE_TOKENS;
module.exports.channelForType = channelForType;
module.exports.ttlSecondsFor = ttlSecondsFor;
module.exports.tagFor = tagFor;
module.exports.sendToTokens = sendToTokens;
module.exports.notifyAllUsers = notifyAllUsers;
module.exports.MATCH_SCORE_NOTIFY_THRESHOLD = MATCH_SCORE_NOTIFY_THRESHOLD;
