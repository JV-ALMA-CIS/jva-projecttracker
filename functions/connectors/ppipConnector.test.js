/**
 * Plain-Node assertion tests for ppipConnector.js. Run with:
 *   node functions/connectors/ppipConnector.test.js
 */
const assert = require("node:assert/strict");
const { toTender, parseNairobiTime, readableTitle, fetchActiveTenders, runPpipDiscovery } = require("./ppipConnector");

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

function record(id, overrides = {}) {
  return {
    id,
    title: `PROPOSED CONSTRUCTION OF CLASSROOM BLOCK ${id}`,
    tender_ref: `REF/${id}`,
    close_at: "2026-11-30 11:00:00",
    procurement_category_id: 2,
    procurement_category: { title: "Works" },
    procurement_method: { title: "Open Tender" },
    venue: "County HQ",
    is_agpo: null,
    terminated: 0,
    pe: { name: "Embu County Government", type: { code: "countyGovernment" } },
    // Personal data the connector must never copy:
    created_by: { name: "Officer Name", email: "officer@example.com", phone: "+254700000000" },
    team_members: [{ name: "Someone" }],
    ...overrides,
  };
}

function fakeFetch(pages) {
  return async (url) => {
    const page = Number(new URL(url).searchParams.get("page"));
    return { ok: true, json: async () => ({ data: pages[page - 1] || [], last_page: pages.length }) };
  };
}

function fakeDb(scoredIds = []) {
  const scored = new Map(scoredIds.map((id) => [id, {}]));
  const added = [];
  return {
    scored,
    added,
    async getAll(...refs) {
      return refs.map((r) => ({ id: r.id, exists: scored.has(r.id) }));
    },
    batch() {
      const ops = [];
      return { set: (ref, d) => ops.push([ref.id, d]), commit: async () => ops.forEach(([id, d]) => scored.set(id, d)) };
    },
    collection(name) {
      if (name === "ppipScoredTenders") return { doc: (id) => ({ id }) };
      assert.equal(name, "opportunities");
      return { add: async (d) => added.push(d) };
    },
  };
}

const fakeAdmin = { firestore: { Timestamp: { fromDate: (d) => ({ iso: d.toISOString() }) } } };
const quietLogger = { info() {}, error() {} };

(async () => {
  console.log("ppipConnector.test.js");

  await test("parseNairobiTime reads PPIP local times as East Africa Time (UTC+3)", () => {
    assert.equal(parseNairobiTime("2026-11-17 11:00:00").toISOString(), "2026-11-17T08:00:00.000Z");
    assert.equal(parseNairobiTime(null), null);
  });

  await test("readableTitle converts ALL CAPS but keeps numbers / mixed case", () => {
    assert.equal(readableTitle("PROPOSED RENOVATION OF 9 CLASSROOMS"), "Proposed Renovation of 9 Classrooms");
    assert.equal(readableTitle("Supply of ICT Equipment"), "Supply of ICT Equipment");
  });

  await test("toTender keeps only non-personal fields and builds the portal link", () => {
    const t = toTender(record(312633), NOW);
    assert.deepEqual(Object.keys(t).sort(), ["agpo", "category", "closeAt", "entity", "entityIsCounty", "id", "method", "reference", "sourceUrl", "title", "venue"]);
    assert.equal(t.sourceUrl, "https://tenders.go.ke/tenders/312633");
    assert.equal(JSON.stringify(t).includes("officer@example.com"), false);
  });

  await test("toTender drops closed and terminated tenders", () => {
    assert.equal(toTender(record(1, { close_at: "2026-11-16 11:00:00" }), NOW), null);
    assert.equal(toTender(record(2, { terminated: 1 }), NOW), null);
  });

  await test("fetchActiveTenders walks every page", async () => {
    const ts = await fetchActiveTenders({ now: NOW, fetchImpl: fakeFetch([[record(1), record(2)], [record(3)]]) });
    assert.deepEqual(ts.map((t) => t.id), ["1", "2", "3"]);
  });

  await test("saves tenders scoring >= 50, remembers every scored id, never copies personal data", async () => {
    const db = fakeDb();
    const result = await runPpipDiscovery({
      db,
      admin: fakeAdmin,
      now: NOW,
      logger: quietLogger,
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeFetch([[record(10), record(11, { is_agpo: 1 }), record(12)]]),
      scoreBatch: async () => [
        { index: 0, fitScorePercent: 82, fitReasoning: "Construction works." },
        { index: 1, fitScorePercent: 55, fitReasoning: "Borderline." },
        { index: 2, fitScorePercent: 10, fitReasoning: "Fuel supply." },
      ],
    });
    assert.deepEqual(result, { fetched: 3, alreadyScored: 0, scored: 3, created: 2 });
    assert.equal(db.scored.size, 3);
    const first = db.added[0];
    assert.equal(first.client, "Embu County Government");
    assert.equal(first.tenderSourceCategory, "countyGovernment");
    assert.equal(first.externalId, "ppip:10");
    assert.equal(first.deadline.iso, "2026-11-30T08:00:00.000Z");
    assert.ok(db.added[1].tags.includes("agpo"));
    assert.equal(JSON.stringify(db.added).includes("officer@example.com"), false);
  });

  await test("already-scored tenders are skipped entirely (no AI call)", async () => {
    let calls = 0;
    const result = await runPpipDiscovery({
      db: fakeDb(["10"]),
      admin: fakeAdmin,
      now: NOW,
      logger: quietLogger,
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeFetch([[record(10)]]),
      scoreBatch: async () => (calls++, []),
    });
    assert.equal(calls, 0);
    assert.equal(result.scored, 0);
  });

  await test("quiet mode marks saved tenders suppressNotification", async () => {
    const db = fakeDb();
    await runPpipDiscovery({
      db,
      admin: fakeAdmin,
      now: NOW,
      quiet: true,
      logger: quietLogger,
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeFetch([[record(20)]]),
      scoreBatch: async () => [{ index: 0, fitScorePercent: 90 }],
    });
    assert.equal(db.added[0].suppressNotification, true);
  });

  console.log(`\n${passed} test(s) passed`);
})();
