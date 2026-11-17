/**
 * Plain-Node assertion tests for deadlineReminders.js — same convention as
 * the other *.test.js files. Run with:
 *   node functions/deadlineReminders.test.js
 */
const assert = require("node:assert/strict");
const { reminderDue } = require("./deadlineReminders");

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

console.log("deadlineReminders.test.js");

const NOW = new Date("2026-11-16T04:00:00Z"); // 07:00 Nairobi
const inDays = (d) => new Date(NOW.getTime() + d * 24 * 60 * 60 * 1000 - 60 * 1000);

function opp(overrides = {}) {
  return { status: "discovered", fitScorePercent: 80, deadline: inDays(10), ...overrides };
}

test("sends the 14-day reminder for a qualifying opportunity 10 days out", () => {
  assert.deepEqual(reminderDue(opp(), NOW), { reminderDay: 14, daysLeft: 10, sent: [14] });
});

test("sends the 3-day reminder once the 14-day one has gone out", () => {
  const due = reminderDue(opp({ deadline: inDays(3), deadlineRemindersSent: [14] }), NOW);
  assert.deepEqual(due, { reminderDay: 3, daysLeft: 3, sent: [14, 3] });
});

test("sends only the most urgent reminder when both points are crossed at once, and marks both", () => {
  const due = reminderDue(opp({ deadline: inDays(2) }), NOW);
  assert.deepEqual(due, { reminderDay: 3, daysLeft: 2, sent: [14, 3] });
});

test("sends nothing when every crossed reminder was already sent", () => {
  assert.equal(reminderDue(opp({ deadline: inDays(2), deadlineRemindersSent: [14, 3] }), NOW), null);
});

test("sends nothing more than 14 days out", () => {
  assert.equal(reminderDue(opp({ deadline: inDays(20) }), NOW), null);
});

test("sends nothing for a passed deadline", () => {
  assert.equal(reminderDue(opp({ deadline: new Date(NOW.getTime() - 1000) }), NOW), null);
});

test("sends nothing for a low-score opportunity nobody is reviewing", () => {
  assert.equal(reminderDue(opp({ fitScorePercent: 40 }), NOW), null);
});

test("does remind for a low-score opportunity someone moved to reviewing", () => {
  assert.equal(reminderDue(opp({ fitScorePercent: 40, status: "reviewing" }), NOW).reminderDay, 14);
});

test("sends nothing once the opportunity is applied for or closed", () => {
  for (const status of ["applied", "won", "lost", "dismissed", "archived"]) {
    assert.equal(reminderDue(opp({ status }), NOW), null, status);
  }
});

test("sends nothing without a deadline", () => {
  assert.equal(reminderDue(opp({ deadline: null }), NOW), null);
});

test("accepts a Firestore Timestamp-like deadline", () => {
  const deadline = inDays(5);
  const due = reminderDue(opp({ deadline: { toDate: () => deadline } }), NOW);
  assert.equal(due.reminderDay, 14);
});

console.log(`\n${passed} test(s) passed`);
