const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { matchNotifyScoreFor, notifyAllUsers } = require("./matchScorePushNotification");

/**
 * Deadline reminders: a push to every user 14 days and 3 days before an
 * opportunity's deadline, so qualifying tenders and grants aren't missed.
 * Shares admin initialization with index.js (do not call initializeApp here).
 */

/** Days-before-deadline at which a reminder is sent, largest first. */
const REMINDER_DAYS = [14, 3];
const DAY_MS = 24 * 60 * 60 * 1000;

/** Statuses for which the deadline no longer matters. */
const NO_REMINDER_STATUSES = new Set(["applied", "won", "lost", "dismissed", "archived"]);

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Decides whether [opportunity] is due a reminder at [now]. Returns
 * `{ reminderDay, daysLeft, sent }` — `sent` being the full updated
 * `deadlineRemindersSent` list to write back — or null if no reminder is due.
 *
 * Only opportunities someone would act on get reminders: still open
 * (not applied/closed), and either scoring at or above the notify threshold
 * or already moved into "reviewing" by a person. When several reminder
 * points have been crossed at once (e.g. the opportunity was found 2 days
 * before its deadline), only the most urgent one is sent and all crossed
 * points are marked, so nobody gets two pushes in one morning.
 */
function reminderDue(opportunity, now = new Date()) {
  if (!opportunity || NO_REMINDER_STATUSES.has(opportunity.status)) return null;
  const qualifies =
    matchNotifyScoreFor(opportunity) != null || opportunity.status === "reviewing";
  if (!qualifies) return null;

  const deadline = toDate(opportunity.deadline);
  if (!deadline) return null;
  const msLeft = deadline.getTime() - now.getTime();
  if (msLeft < 0) return null;
  const daysLeft = Math.ceil(msLeft / DAY_MS);

  const alreadySent = Array.isArray(opportunity.deadlineRemindersSent)
    ? opportunity.deadlineRemindersSent
    : [];
  const crossed = REMINDER_DAYS.filter((d) => daysLeft <= d && !alreadySent.includes(d));
  if (crossed.length === 0) return null;

  const reminderDay = Math.min(...crossed);
  return {
    reminderDay,
    daysLeft,
    sent: [...new Set([...alreadySent, ...crossed])].sort((a, b) => b - a),
  };
}

/** Sends any due reminders. Returns the number of reminders sent. */
async function sendDueDeadlineReminders({ now = new Date(), firestoreDb = admin.firestore() } = {}) {
  const horizon = new Date(now.getTime() + (Math.max(...REMINDER_DAYS) + 1) * DAY_MS);
  const snap = await firestoreDb
    .collection("opportunities")
    .where("deadline", ">=", admin.firestore.Timestamp.fromDate(now))
    .where("deadline", "<=", admin.firestore.Timestamp.fromDate(horizon))
    .get();

  let sent = 0;
  for (const doc of snap.docs) {
    const opportunity = doc.data();
    const due = reminderDue(opportunity, now);
    if (!due) continue;

    // Mark first, so a crash between send and mark can't cause a repeat
    // reminder every day; a missed reminder is better than a daily spam.
    await doc.ref.update({ deadlineRemindersSent: due.sent });
    await notifyAllUsers({
      type: "deadline",
      opportunityId: doc.id,
      opportunityTitle: opportunity.title,
      kind: opportunity.kind,
      daysLeft: due.daysLeft,
    });
    sent += 1;
  }
  logger.info(`sendDueDeadlineReminders: ${snap.size} opportunities in window, ${sent} reminder(s) sent`);
  return sent;
}

/** Every morning at 07:00 Nairobi time. */
exports.scheduledDeadlineReminders = onSchedule(
  { schedule: "every day 07:00", timeZone: "Africa/Nairobi" },
  async () => {
    await sendDueDeadlineReminders();
  },
);

module.exports.reminderDue = reminderDue;
module.exports.sendDueDeadlineReminders = sendDueDeadlineReminders;
module.exports.REMINDER_DAYS = REMINDER_DAYS;
