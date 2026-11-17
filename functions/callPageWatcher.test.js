/**
 * Plain-Node assertion tests for callPageWatcher.js. Run with:
 *   node functions/callPageWatcher.test.js
 */
const assert = require("node:assert/strict");
const { mainText, decide, checkPage, WATCHED_CALL_PAGES } = require("./callPageWatcher");
const { buildNotificationMessage } = require("./matchScorePushNotification");
const { reminderDue } = require("./deadlineReminders");

let passed = 0;
async function test(name, fn) {
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

const NOW = new Date("2026-11-17T05:00:00Z");
const PAGE = WATCHED_CALL_PAGES.find((p) => p.key === "abil-explore");

/** Fake Firestore covering exactly what checkPage uses. */
function fakeDb({ state = null, existing = [] } = {}) {
  const states = new Map(state ? [[PAGE.key, state]] : []);
  const opps = [...existing];
  return {
    opps,
    states,
    collection(name) {
      if (name === "watchedCallPages") {
        return {
          doc: (id) => ({
            async get() {
              return { data: () => states.get(id) };
            },
            async set(data) {
              states.set(id, { ...(states.get(id) || {}), ...data });
            },
          }),
        };
      }
      assert.equal(name, "opportunities");
      return {
        where(field, op, value) {
          return {
            limit: () => ({
              async get() {
                const docs = opps
                  .filter((o) => o.data[field] === value)
                  .map((o) => ({
                    id: o.id,
                    data: () => o.data,
                    ref: {
                      async update(u) {
                        Object.assign(o.data, u);
                      },
                    },
                  }));
                return { docs };
              },
            }),
          };
        },
        async add(data) {
          const id = `opp-${opps.length + 1}`;
          opps.push({ id, data });
          return { id };
        },
      };
    },
  };
}

const page = (body) => async () => ({ ok: true, status: 200, text: async () => `<html><header>menu</header><main>${body}</main></html>` });

(async () => {
  console.log("callPageWatcher.test.js");

  await test("mainText drops header/script and decodes dashes", () => {
    const t = mainText("<header>Home Explore</header><script>x()</script><p>ABIL &#8211; Explore</p>");
    assert.equal(t, "ABIL - Explore");
  });

  await test("decide: closed or past-deadline → none; new open round → create; moved deadline → extend", () => {
    assert.equal(decide({ isOpen: false, deadline: "2027-03-01" }, null, NOW).action, "none");
    assert.equal(decide({ isOpen: true, deadline: "2026-09-23T10:00:00Z" }, null, NOW).action, "none");
    assert.equal(decide({ isOpen: true, deadline: "2027-03-01T10:00:00Z" }, null, NOW).action, "create");
    const existing = { deadline: new Date("2027-03-01T10:00:00Z") };
    assert.equal(decide({ isOpen: true, deadline: "2027-03-01T10:00:00Z" }, existing, NOW).action, "none");
    assert.equal(decide({ isOpen: true, deadline: "2027-04-15T10:00:00Z" }, existing, NOW).action, "extend");
  });

  await test("unchanged page: no AI call, no opportunity", async () => {
    const db = fakeDb();
    let aiCalls = 0;
    const deps = { db, now: NOW, fetchImpl: page("Round closed."), extract: async () => (aiCalls++, { isOpen: false }), notify: async () => {} };
    await checkPage(PAGE, deps);
    const second = await checkPage(PAGE, deps);
    assert.equal(second, "unchanged");
    assert.equal(aiCalls, 1);
    assert.equal(db.opps.length, 0);
  });

  await test("a newly opened round creates one watched opportunity and pushes 'New call open'", async () => {
    const db = fakeDb();
    const pushes = [];
    const result = await checkPage(PAGE, {
      db,
      now: NOW,
      fetchImpl: page("2027 round now open. Deadline 1 March 2027."),
      extract: async () => ({ isOpen: true, roundName: "2027 evaluation round", deadline: "2027-03-01T10:00:00Z", summary: "Kenyan SMEs; up to EUR 50,000." }),
      notify: async (p) => pushes.push(p),
    });
    assert.equal(result, "create");
    assert.equal(db.opps.length, 1);
    const o = db.opps[0].data;
    assert.equal(o.title, "ABIL EXPLORE open call (ESA / Kenya Space Agency) — 2027 evaluation round");
    assert.equal(o.kind, "grant");
    assert.equal(o.externalId, "abil-explore:2027");
    assert.equal(o.watched, true);
    assert.equal(o.suppressNotification, true);
    assert.equal(pushes.length, 1);
    assert.equal(pushes[0].type, "watchedCallOpen");
  });

  await test("an extension updates the same opportunity, resets reminders, and pushes 'Deadline extended'", async () => {
    const db = fakeDb({
      existing: [{ id: "opp-1", data: { externalId: "abil-explore:2027", title: "ABIL EXPLORE — 2027", deadline: new Date("2027-03-01T10:00:00Z"), deadlineRemindersSent: [14] } }],
    });
    const pushes = [];
    const result = await checkPage(PAGE, {
      db,
      now: NOW,
      fetchImpl: page("Deadline extended to 15 April 2027."),
      extract: async () => ({ isOpen: true, roundName: "2027 evaluation round", deadline: "2027-04-15T10:00:00Z", summary: "Extended." }),
      notify: async (p) => pushes.push(p),
    });
    assert.equal(result, "extend");
    assert.equal(db.opps.length, 1, "no duplicate");
    assert.deepEqual(db.opps[0].data.deadlineRemindersSent, []);
    assert.equal(pushes[0].type, "watchedCallExtended");
  });

  await test("the real current ABIL text (round closed 23 Sep 2026) creates nothing", async () => {
    const db = fakeDb();
    const result = await checkPage(PAGE, {
      db,
      now: NOW,
      fetchImpl: page("The cut-off date for submissions for the 2026 evaluation round has been extended to 23 September 2026 at 1:00 p.m. EAT."),
      extract: async () => ({ isOpen: false, roundName: "2026 evaluation round", deadline: "2026-09-23T10:00:00Z", summary: "" }),
      notify: async () => assert.fail("must not push"),
    });
    assert.equal(result, "none");
    assert.equal(db.opps.length, 0);
  });

  await test("push copy for watched calls names the deadline", () => {
    const open = buildNotificationMessage("t", { type: "watchedCallOpen", opportunityId: "o", opportunityTitle: "ABIL EXPLORE", deadline: "2027-03-01T10:00:00Z" });
    assert.equal(open.notification.title, "New call open — deadline 1 Mar 2027");
    const ext = buildNotificationMessage("t", { type: "watchedCallExtended", opportunityId: "o", opportunityTitle: "ABIL EXPLORE", deadline: "2027-04-15T10:00:00Z" });
    assert.equal(ext.notification.title, "Deadline extended to 15 Apr 2027");
  });

  await test("watched calls get deadline reminders even without a fit score", () => {
    const due = reminderDue({ status: "discovered", fitScorePercent: 0, watched: true, deadline: new Date("2026-11-27T10:00:00Z") }, NOW);
    assert.equal(due.reminderDay, 14);
  });

  console.log(`\n${passed} test(s) passed`);
})();
