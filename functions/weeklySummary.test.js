/**
 * Plain-Node assertion tests for weeklySummary.js. Run with:
 *   node functions/weeklySummary.test.js
 */
const assert = require("node:assert/strict");
const { computeWeeklySummary, summaryCopy, computeFundingOpenNow, fundingCopy } = require("./weeklySummary");
const { buildNotificationMessage } = require("./matchScorePushNotification");

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

console.log("weeklySummary.test.js");

const NOW = new Date("2026-11-23T06:30:00Z"); // Monday 09:30 Nairobi
const daysAgo = (n) => new Date(NOW.getTime() - n * 86400000);
const inDays = (n) => new Date(NOW.getTime() + n * 86400000);
const units = new Map([["bu-c", "Construction"], ["bu-fm", "Facility Management"], ["bu-it", "Information Technology"]]);

const opps = [
  { kind: "tender", status: "discovered", discoveredAt: daysAgo(1), businessUnitIds: ["bu-c"], fitScorePercent: 82 },
  { kind: "tender", status: "discovered", discoveredAt: daysAgo(2), businessUnitIds: ["bu-c", "bu-fm"], fitScorePercent: 60 },
  { kind: "tender", status: "discovered", discoveredAt: daysAgo(3), businessUnitIds: ["bu-it"], fitScorePercent: 55 },
  { kind: "grant", status: "discovered", discoveredAt: daysAgo(4), fitScorePercent: 75, deadline: inDays(3) },
  { kind: "programme", status: "discovered", discoveredAt: daysAgo(5), fitScorePercent: 40 },
  // Not counted: older than a week, or archived by the buyer policy.
  { kind: "tender", status: "discovered", discoveredAt: daysAgo(9), businessUnitIds: ["bu-c"], fitScorePercent: 90 },
  { kind: "tender", status: "archived", discoveredAt: daysAgo(1), businessUnitIds: ["bu-c"], fitScorePercent: 90 },
  // Older item still open, closing this week, being reviewed.
  { kind: "tender", status: "reviewing", discoveredAt: daysAgo(20), fitScorePercent: 30, deadline: inDays(5) },
];

test("counts the past week's opportunities by kind and top business units", () => {
  const s = computeWeeklySummary({ opportunities: opps, unitNames: units, shareCount: 2, now: NOW });
  assert.equal(s.total, 5);
  assert.deepEqual(s.byKind, { tender: 3, grant: 1, programme: 1 });
  assert.deepEqual(s.topUnits[0], ["Construction", 2]);
  assert.equal(s.strongMatches, 2);
  assert.equal(s.closingThisWeek, 2);
  assert.equal(s.shareCount, 2);
});

test("builds a readable one-line summary", () => {
  const s = computeWeeklySummary({ opportunities: opps, unitNames: units, shareCount: 2, now: NOW });
  const copy = summaryCopy(s);
  assert.equal(copy.title, "This week: 5 new opportunities");
  assert.equal(
    copy.body,
    "Tenders 3 (Construction 2, Facility Management 1, Information Technology 1) · Grants 1 · Programmes 1 · 2 strong matches · 2 closing this week · 2 shared by the team",
  );
});

test("sends nothing in a completely empty week", () => {
  const s = computeWeeklySummary({ opportunities: [], now: NOW });
  assert.equal(summaryCopy(s), null);
});

test("singular wording for one opportunity", () => {
  const s = computeWeeklySummary({
    opportunities: [{ kind: "grant", status: "discovered", discoveredAt: daysAgo(1), fitScorePercent: 20 }],
    now: NOW,
  });
  assert.equal(summaryCopy(s).title, "This week: 1 new opportunity");
});

test("the push opens the Inbox (app data + web link)", () => {
  const m = buildNotificationMessage("t", { type: "weeklySummary", summaryTitle: "This week: 5 new opportunities", summaryBody: "Tenders 3" });
  assert.equal(m.notification.title, "This week: 5 new opportunities");
  assert.equal(m.notification.body, "Tenders 3");
  assert.equal(m.data.open, "inbox");
  assert.equal(m.webpush.fcmOptions.link, "https://jva-projecttracker.web.app/?open=inbox");
});

// --- Funding open now -------------------------------------------------------

const grants = [
  { title: "GSMA Innovation Fund for AI-enabled financial health", kind: "grant", status: "discovered", eligibility: "eligible", deadline: inDays(24), fundingAmount: "£100,000–£250,000" },
  { title: "FID open call", kind: "grant", status: "discovered", eligibility: "eligible" }, // rolling
  { title: "Horizon AI robotics", kind: "grant", status: "discovered", eligibility: "needsPartner", deadline: inDays(60) },
  { title: "AI for Good Innovation Factory", kind: "programme", status: "discovered", eligibility: "unclear", deadline: inDays(4) },
  // Left out: not eligible, deadline passed, archived, a tender.
  { title: "Japan GGP Kenya", kind: "grant", status: "discovered", eligibility: "notEligible", deadline: inDays(70) },
  { title: "Old prize", kind: "grant", status: "discovered", eligibility: "eligible", deadline: daysAgo(2) },
  { title: "Archived call", kind: "grant", status: "archived", eligibility: "eligible", deadline: inDays(9) },
  { title: "Some tender", kind: "tender", status: "discovered", deadline: inDays(9) },
];

test("funding: counts open grants JVA can apply for or join with a partner", () => {
  const f = computeFundingOpenNow({ opportunities: grants, now: NOW });
  assert.equal(f.total, 4);
  assert.equal(f.canApply, 3);
  assert.equal(f.needPartner, 1);
});

test("funding: next three are soonest first, rolling last", () => {
  const f = computeFundingOpenNow({ opportunities: grants, now: NOW });
  assert.deepEqual(
    f.next.map((n) => n.title),
    ["AI for Good Innovation Factory", "GSMA Innovation Fund for AI-enabled financial health", "Horizon AI robotics"],
  );
});

test("funding copy names deadlines and amounts, Synnefa-style", () => {
  const copy = fundingCopy(computeFundingOpenNow({ opportunities: grants, now: NOW }));
  assert.equal(copy.title, "Funding open now: 4 grants & calls");
  assert.match(copy.body, /^3 you can apply for, 1 needs a partner\. Next: /);
  assert.match(copy.body, /AI for Good Innovation Factory — 27 Nov/);
  assert.match(copy.body, /— 17 Dec \(£100,000–£250,000\)/);
});

test("funding copy: nothing open means no push", () => {
  assert.equal(fundingCopy(computeFundingOpenNow({ opportunities: [], now: NOW })), null);
});

test("funding push opens the Inbox on Grants", () => {
  const m = buildNotificationMessage("t", { type: "fundingSummary", summaryTitle: "Funding open now: 4", summaryBody: "x" });
  assert.equal(m.notification.title, "Funding open now: 4");
  assert.equal(m.data.open, "grants");
  assert.equal(m.webpush.fcmOptions.link, "https://jva-projecttracker.web.app/?open=grants");
  assert.equal(m.android.notification.channelId, "summary");
  assert.equal(m.webpush.notification.requireInteraction, false);
});

console.log(`\n${passed} test(s) passed`);
