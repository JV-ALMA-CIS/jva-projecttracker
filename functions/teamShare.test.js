/**
 * Plain-Node assertion tests for teamShare.js. Run with:
 *   node functions/teamShare.test.js
 */
const assert = require("node:assert/strict");
const { shareOpportunity, sharerName, cleanNote } = require("./teamShare");
const { buildNotificationMessage } = require("./matchScorePushNotification");

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

function fakeDb(opportunities = {}) {
  const shares = [];
  return {
    shares,
    collection(name) {
      if (name === "teamShares") {
        return { add: async (d) => (shares.push(d), { id: `share-${shares.length}` }) };
      }
      assert.equal(name, "opportunities");
      return {
        doc: (id) => ({
          async get() {
            return { exists: id in opportunities, data: () => opportunities[id] };
          },
        }),
      };
    },
  };
}

const AUTH = { uid: "u1", token: { name: "Jane Wanjiku", email: "jane@example.com" } };

(async () => {
  console.log("teamShare.test.js");

  await test("sharerName prefers the display name, then the email's local part", () => {
    assert.equal(sharerName({ name: "Jane Wanjiku" }), "Jane Wanjiku");
    assert.equal(sharerName({ email: "peter@jva.co.ke" }), "Peter");
    assert.equal(sharerName({}), "A colleague");
  });

  await test("cleanNote trims, collapses spaces and caps the length", () => {
    assert.equal(cleanNote("  fits   our Mombasa work  "), "fits our Mombasa work");
    assert.equal(cleanNote("x".repeat(500)).length, 280);
    assert.equal(cleanNote(undefined), "");
  });

  await test("records the share and pushes to everyone except the sharer", async () => {
    const db = fakeDb({ o1: { title: "Classroom renovation – Mavoko", kind: "tender" } });
    let pushed;
    let options;
    const result = await shareOpportunity({
      db,
      auth: AUTH,
      data: { opportunityId: "o1", note: "Boss, this fits our school projects" },
      notify: async (payload, opts) => ((pushed = payload), (options = opts), { successCount: 4 }),
    });
    assert.deepEqual(result, { shareId: "share-1", recipients: 4 });
    assert.equal(db.shares[0].sharedByName, "Jane Wanjiku");
    assert.equal(db.shares[0].note, "Boss, this fits our school projects");
    assert.equal(pushed.type, "teamShare");
    assert.deepEqual(options, { excludeUid: "u1" });
  });

  await test("rejects signed-out callers and unknown opportunities", async () => {
    await assert.rejects(shareOpportunity({ db: fakeDb(), auth: null, data: { opportunityId: "o1" } }), /Sign in/);
    await assert.rejects(shareOpportunity({ db: fakeDb(), auth: AUTH, data: { opportunityId: "nope" } }), /not found/);
  });

  await test("push copy names the sharer and includes the note", () => {
    const m = buildNotificationMessage("t", {
      type: "teamShare",
      opportunityId: "o1",
      opportunityTitle: "ABIL EXPLORE call",
      kind: "grant",
      sharedByName: "Jane",
      note: "let's discuss Friday",
    });
    assert.equal(m.notification.title, "Jane shared a grant / call");
    assert.equal(m.notification.body, 'ABIL EXPLORE call — "let\'s discuss Friday"');
    assert.equal(m.data.opportunityId, "o1");
  });

  await test("a hand-added opportunity reads 'added', not 'shared'", () => {
    const m = buildNotificationMessage("t", {
      type: "teamShare",
      opportunityId: "o1",
      opportunityTitle: "Borehole drilling – Kitui",
      kind: "tender",
      sharedByName: "Peter",
      justAdded: true,
    });
    assert.equal(m.notification.title, "Peter added a tender");
  });

  console.log(`\n${passed} test(s) passed`);
})();
