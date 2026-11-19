const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { notifyAllUsers } = require("./matchScorePushNotification");

/**
 * Monday-morning summary push to everyone: what the platform found in the
 * past 7 days (tenders by business unit, grants, programmes), how many are
 * strong matches, what closes this week, and how much the team shared.
 * Nobody watches the platform daily, so this is the weekly "here's what's
 * waiting" — including good matches below the 70% instant-alert line.
 * Tapping it opens the Opportunity Inbox.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const DAY_MS = 24 * 60 * 60 * 1000;
const CLOSED = new Set(["applied", "won", "lost", "dismissed", "archived"]);

const toDate = (v) => (v?.toDate ? v.toDate() : v ? new Date(v) : null);
const scoreOf = (o) => (typeof o.overallMatchScore === "number" ? o.overallMatchScore : o.fitScorePercent || 0);

/**
 * Pure: the week's numbers from [opportunities] (plain objects) and
 * [shareCount], with business-unit names from [unitNames] (id -> name).
 */
function computeWeeklySummary({ opportunities, unitNames = new Map(), shareCount = 0, now = new Date() }) {
  const weekAgo = new Date(now.getTime() - 7 * DAY_MS);
  const weekAhead = new Date(now.getTime() + 7 * DAY_MS);

  const fresh = opportunities.filter((o) => {
    const found = toDate(o.discoveredAt);
    return found && found >= weekAgo && !CLOSED.has(o.status);
  });

  const byKind = { tender: 0, grant: 0, programme: 0 };
  const byUnit = new Map();
  for (const o of fresh) {
    const kind = byKind[o.kind] !== undefined ? o.kind : "tender";
    byKind[kind] += 1;
    if (kind !== "tender") continue;
    for (const id of Array.isArray(o.businessUnitIds) ? o.businessUnitIds : []) {
      const name = unitNames.get(id);
      if (name) byUnit.set(name, (byUnit.get(name) || 0) + 1);
    }
  }

  const strongMatches = fresh.filter((o) => scoreOf(o) >= 70).length;
  const closingThisWeek = opportunities.filter((o) => {
    const d = toDate(o.deadline);
    return d && d > now && d <= weekAhead && !CLOSED.has(o.status) && (o.status === "reviewing" || scoreOf(o) >= 50 || o.watched);
  }).length;

  const topUnits = [...byUnit.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
  return { total: fresh.length, byKind, topUnits, strongMatches, closingThisWeek, shareCount };
}

/** Pure: notification title/body for a summary, or null when there is nothing to say. */
function summaryCopy(s) {
  if (s.total === 0 && s.closingThisWeek === 0 && s.shareCount === 0) return null;
  const title =
    s.total > 0
      ? `This week: ${s.total} new opportunit${s.total === 1 ? "y" : "ies"}`
      : "This week on JVA Project Tracker";
  const parts = [];
  if (s.byKind.tender > 0) {
    const units = s.topUnits.map(([name, n]) => `${name} ${n}`).join(", ");
    parts.push(`Tenders ${s.byKind.tender}${units ? ` (${units})` : ""}`);
  }
  if (s.byKind.grant > 0) parts.push(`Grants ${s.byKind.grant}`);
  if (s.byKind.programme > 0) parts.push(`Programmes ${s.byKind.programme}`);
  if (s.strongMatches > 0) parts.push(`${s.strongMatches} strong match${s.strongMatches === 1 ? "" : "es"}`);
  if (s.closingThisWeek > 0) parts.push(`${s.closingThisWeek} closing this week`);
  if (s.shareCount > 0) parts.push(`${s.shareCount} shared by the team`);
  return { title, body: parts.join(" · ") };
}

const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** "17 Dec" (Nairobi date). */
function shortDay(d) {
  const local = new Date(d.getTime() + 3 * 60 * 60 * 1000);
  return `${local.getUTCDate()} ${SHORT_MONTHS[local.getUTCMonth()]}`;
}

/** Trims a long call name to [max] characters at a word boundary. */
function shortName(title, max = 48) {
  const t = String(title || "").replace(/\s+/g, " ").trim();
  if (t.length <= max) return t;
  const cut = t.slice(0, max);
  return `${cut.slice(0, Math.max(cut.lastIndexOf(" "), 20)).replace(/[\s,;:—-]+$/, "")}…`;
}

/**
 * Pure: grants / calls / programmes still open today that JVA can apply
 * for — on its own ("eligible", or not checked yet) or with a partner
 * ("needsPartner"). Not-eligible ones and past deadlines are left out.
 * Sorted by deadline (soonest first), rolling calls last.
 */
function computeFundingOpenNow({ opportunities, now = new Date() }) {
  const open = opportunities.filter((o) => {
    if (o.kind !== "grant" && o.kind !== "programme") return false;
    if (CLOSED.has(o.status)) return false;
    if (o.eligibility === "notEligible") return false;
    const d = toDate(o.deadline);
    return !d || d > now;
  });
  const deadlineOf = (o) => toDate(o.deadline)?.getTime() ?? Number.POSITIVE_INFINITY;
  open.sort((a, b) => deadlineOf(a) - deadlineOf(b));
  return {
    total: open.length,
    canApply: open.filter((o) => o.eligibility !== "needsPartner").length,
    needPartner: open.filter((o) => o.eligibility === "needsPartner").length,
    // Soonest first, preferring ones JVA can apply to alone.
    next: [
      ...open.filter((o) => o.eligibility === "eligible"),
      ...open.filter((o) => o.eligibility !== "eligible"),
    ]
      .sort((a, b) => deadlineOf(a) - deadlineOf(b))
      .slice(0, 3)
      .map((o) => ({
        title: o.title,
        deadline: toDate(o.deadline),
        fundingAmount: o.fundingAmount || "",
      })),
  };
}

/** Pure: the "Funding open now" push copy, or null when nothing is open. */
function fundingCopy(f) {
  if (f.total === 0) return null;
  const title = `Funding open now: ${f.total} grant${f.total === 1 ? "" : "s"} & call${f.total === 1 ? "" : "s"}`;
  const counts = [];
  if (f.canApply > 0) counts.push(`${f.canApply} you can apply for`);
  if (f.needPartner > 0) counts.push(`${f.needPartner} need${f.needPartner === 1 ? "s" : ""} a partner`);
  const items = f.next.map((n) => {
    const when = n.deadline ? shortDay(n.deadline) : "rolling";
    return `${shortName(n.title)} — ${when}${n.fundingAmount ? ` (${n.fundingAmount})` : ""}`;
  });
  const body = [counts.join(", "), items.length ? `Next: ${items.join(" · ")}` : ""].filter(Boolean).join(". ");
  return { title, body };
}

/** Loads the data, builds the summary and (unless [dryRun]) pushes it. */
async function sendWeeklySummary({ db = admin.firestore(), now = new Date(), dryRun = false, notify = notifyAllUsers } = {}) {
  const weekAgo = admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 7 * DAY_MS));
  const [oppSnap, unitSnap, shareSnap] = await Promise.all([
    db.collection("opportunities").get(),
    db.collection("businessUnits").get(),
    db.collection("teamShares").where("createdAt", ">=", weekAgo).get(),
  ]);
  const summary = computeWeeklySummary({
    opportunities: oppSnap.docs.map((d) => d.data()),
    unitNames: new Map(unitSnap.docs.map((d) => [d.id, d.data().name])),
    shareCount: shareSnap.size,
    now,
  });
  const copy = summaryCopy(summary);
  const funding = computeFundingOpenNow({ opportunities: oppSnap.docs.map((d) => d.data()), now });
  const fundingText = fundingCopy(funding);
  logger.info(`weeklySummary: ${JSON.stringify({ summary, copy, funding: fundingText, dryRun })}`);
  if (!dryRun) {
    if (copy) await notify({ type: "weeklySummary", summaryTitle: copy.title, summaryBody: copy.body });
    if (fundingText) {
      await notify({ type: "fundingSummary", summaryTitle: fundingText.title, summaryBody: fundingText.body });
    }
  }
  return { summary, copy, funding: fundingText, sent: Boolean((copy || fundingText) && !dryRun) };
}

/** Monday 09:30 Nairobi — after the Monday tender (08:00) and grant (08:30) searches. */
const scheduledWeeklySummary = onSchedule(
  { schedule: "every monday 09:30", timeZone: "Africa/Nairobi" },
  async () => {
    await sendWeeklySummary();
  },
);

module.exports = {
  computeWeeklySummary,
  summaryCopy,
  computeFundingOpenNow,
  fundingCopy,
  sendWeeklySummary,
  scheduledWeeklySummary,
};
