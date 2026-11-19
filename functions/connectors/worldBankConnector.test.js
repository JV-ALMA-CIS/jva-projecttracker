/**
 * Plain-Node tests for worldBankConnector.js. Run with:
 *   node functions/connectors/worldBankConnector.test.js
 */
const assert = require("node:assert/strict");
const {
  parseDeadline,
  toNotice,
  findExistingMatch,
  runWorldBankDiscovery,
  COUNTRIES,
} = require("./worldBankConnector");

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

console.log("worldBankConnector.test.js");

const NOW = new Date("2026-11-19T06:00:00Z");

const raw = (over = {}) => ({
  id: "OP00481963",
  notice_type: "Invitation for Bids",
  submission_deadline_date: "2027-01-14T00:00:00Z",
  submission_deadline_time: "10:00",
  project_ctry_name: "Kenya",
  project_id: "P170941",
  project_name: "Kenya Digital Economy Acceleration Project",
  bid_reference_no: "KE-ICTA-580413-NC-RFB",
  bid_description: "ENHANCEMENT OF THE SMART ACADEMY PORTAL AS KENYA'S NATIONAL DIGITAL SKILLS MARKETPLACE",
  procurement_group: "NC",
  procurement_method_code: "RFB",
  procurement_method_name: "Request for Bids",
  contact_organization: "ICT Authority",
  contact_name: "Some Officer",
  contact_email: "officer@example.go.ke",
  contact_phone_no: "0700000000",
  ...over,
});

(async () => {
  await test("deadline is read as East Africa local time", () => {
    assert.equal(parseDeadline("2027-01-14T00:00:00Z", "10:00").toISOString(), "2027-01-14T07:00:00.000Z");
    assert.equal(parseDeadline("2027-01-14T00:00:00Z", "").toISOString(), "2027-01-14T20:59:00.000Z");
    assert.equal(parseDeadline("", "10:00"), null);
  });

  await test("a notice keeps only non-personal fields", () => {
    const n = toNotice(raw(), NOW);
    assert.equal(n.buyer, "ICT Authority");
    assert.equal(n.group, "Non-consulting services");
    assert.equal(n.sourceUrl, "https://projects.worldbank.org/en/projects-operations/procurement-detail/OP00481963");
    const text = JSON.stringify(n);
    assert.doesNotMatch(text, /Some Officer|officer@example|0700000000/);
  });

  await test("past deadlines and individual-consultant hires are skipped", () => {
    assert.equal(toNotice(raw({ submission_deadline_date: "2026-10-01T00:00:00Z" }), NOW), null);
    assert.equal(toNotice(raw({ procurement_method_code: "INDV" }), NOW), null);
    assert.equal(toNotice(raw({ bid_description: "" }), NOW), null);
  });

  await test("matches an existing tender by reference or similar title", () => {
    const n = toNotice(raw(), NOW);
    const existing = [
      { id: "a", title: "Supply of laptops", tenderReferenceNumber: "X-1" },
      { id: "b", title: "Enhancement of the Smart Academy Portal as Kenya’s National Digital Skills Marketplace" },
    ];
    assert.equal(findExistingMatch(n, existing)?.id, "b");
    assert.equal(findExistingMatch(n, [{ id: "c", title: "Other", tenderReferenceNumber: "ke-icta-580413-nc-rfb" }])?.id, "c");
    assert.equal(findExistingMatch(n, [{ id: "d", title: "Road works in Meru" }]), null);
  });

  // --- full run with fakes -------------------------------------------------

  function fakeAdmin() {
    return {
      firestore: {
        Timestamp: { fromDate: (d) => ({ toDate: () => d, iso: d.toISOString() }) },
        FieldValue: { delete: () => "__delete__" },
      },
    };
  }

  function fakeDb({ scored = [], opportunities = [] } = {}) {
    const memory = new Map(scored.map((id) => [id, { fitScorePercent: 60 }]));
    const opps = opportunities.map((o) => ({ ...o }));
    const added = [];
    const updates = [];
    const refFor = (o) => ({
      async update(data) {
        updates.push({ id: o.id, ...data });
        Object.assign(o, data);
      },
    });
    return {
      added,
      updates,
      collection(name) {
        if (name === "worldBankScoredNotices") {
          return {
            doc: (id) => ({ id, _mem: true }),
            limit: () => ({ get: async () => ({ empty: memory.size === 0 }) }),
          };
        }
        return {
          where: () => ({
            get: async () => ({ docs: opps.map((o) => ({ id: o.id, ref: refFor(o), data: () => o })) }),
          }),
          async add(data) {
            added.push(data);
            return { id: `new-${added.length}` };
          },
        };
      },
      async getAll(...refs) {
        return refs.map((r) => ({ id: r.id, exists: memory.has(r.id) }));
      },
      batch() {
        return {
          set(ref, data) {
            memory.set(ref.id, data);
          },
          async commit() {},
        };
      },
    };
  }

  /** Fake API: one Kenya IFB page with the given notices; every other query empty. */
  const fakeFetch = (notices) => async (url) => ({
    ok: true,
    status: 200,
    json: async () =>
      url.includes("project_ctry_name=Kenya") && url.includes("Invitation%20for%20Bids")
        ? { procnotices: Object.fromEntries(notices.map((n, i) => [String(i), n])) }
        : { procnotices: {} },
  });

  const quietLogger = { info() {}, warn() {}, error() {} };
  const scoreAll = (scores) => async () => scores.map((s, i) => ({ index: i, fitScorePercent: s, fitReasoning: "r" }));

  await test("queries every East African country", () => {
    assert.deepEqual(COUNTRIES, ["Kenya", "Uganda", "Tanzania", "Rwanda", "Burundi"]);
  });

  await test("first run saves good fits quietly, tagged donor-funded; weak fits only remembered", async () => {
    const db = fakeDb();
    const r = await runWorldBankDiscovery({
      db,
      admin: fakeAdmin(),
      buildProfile: async () => "profile",
      scoreBatch: scoreAll([82, 20]),
      fetchImpl: fakeFetch([raw(), raw({ id: "OP2", bid_description: "Supply of ambulances" })]),
      now: NOW,
      logger: quietLogger,
    });
    assert.equal(r.created, 1);
    assert.equal(r.quiet, true);
    const saved = db.added[0];
    assert.equal(saved.fundedBy, "World Bank");
    assert.equal(saved.suppressNotification, true);
    assert.equal(saved.externalId, "wb:OP00481963");
    assert.match(saved.description, /^World Bank-financed: Kenya Digital Economy Acceleration Project/);
    assert.ok(saved.tags.includes("donor-funded"));
  });

  await test("later runs alert normally and skip already-scored notices", async () => {
    const db = fakeDb({ scored: ["OP00481963"] });
    const r = await runWorldBankDiscovery({
      db,
      admin: fakeAdmin(),
      buildProfile: async () => "profile",
      scoreBatch: scoreAll([75]),
      fetchImpl: fakeFetch([raw(), raw({ id: "OP3", bid_description: "Construction of a county office block" })]),
      now: NOW,
      logger: quietLogger,
    });
    assert.equal(r.alreadyScored, 1);
    assert.equal(r.created, 1);
    assert.equal(r.quiet, false);
    assert.equal(db.added[0].suppressNotification, undefined);
  });

  await test("a public-buyer-archived PPIP twin is restored instead of duplicated", async () => {
    const db = fakeDb({
      scored: ["seed"],
      opportunities: [
        {
          id: "ppip-1",
          title: "Enhancement of the Smart Academy Portal as Kenya’s National Digital Skills Marketplace",
          status: "archived",
          archivedReason: "publicBuyer",
          kind: "tender",
        },
      ],
    });
    const r = await runWorldBankDiscovery({
      db,
      admin: fakeAdmin(),
      buildProfile: async () => "profile",
      scoreBatch: scoreAll([80]),
      fetchImpl: fakeFetch([raw()]),
      now: NOW,
      logger: quietLogger,
    });
    assert.equal(r.restored, 1);
    assert.equal(r.created, 0);
    const u = db.updates[0];
    assert.equal(u.status, "discovered");
    assert.equal(u.fundedBy, "World Bank");
    assert.equal(u.archivedReason, "__delete__");
  });

  await test("a weak-fit twin gets its funding noted but stays archived", async () => {
    const db = fakeDb({
      scored: ["seed"],
      opportunities: [{ id: "p", title: "Supply of ambulances", status: "archived", archivedReason: "publicBuyer", kind: "tender" }],
    });
    const r = await runWorldBankDiscovery({
      db,
      admin: fakeAdmin(),
      buildProfile: async () => "profile",
      scoreBatch: scoreAll([15]),
      fetchImpl: fakeFetch([raw({ id: "OP9", bid_description: "Supply of ambulances" })]),
      now: NOW,
      logger: quietLogger,
    });
    assert.equal(r.restored, 0);
    assert.equal(db.updates[0].status, undefined);
    assert.equal(db.updates[0].fundedBy, "World Bank");
  });

  console.log(`\n${passed} test(s) passed`);
})();
