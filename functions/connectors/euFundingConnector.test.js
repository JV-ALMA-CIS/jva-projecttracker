/**
 * Plain-Node assertion tests for euFundingConnector.js. Run with:
 *   node functions/connectors/euFundingConnector.test.js
 */
const assert = require("node:assert/strict");
const {
  toCall,
  isExcludedIdentifier,
  portalUrlFor,
  fetchOpenEuCalls,
  runEuFundingDiscovery,
} = require("./euFundingConnector");

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

const NOW = new Date("2026-11-17T00:00:00Z");

function apiResult({ id, title = `Call ${id}`, deadlines = ["2027-03-01T17:00:00.000+0000"], url, budget, callTitle } = {}) {
  return {
    url: url || `https://ec.europa.eu/info/funding-tenders/opportunities/data/topicDetails/${id}.json`,
    metadata: {
      identifier: [id],
      title: [title],
      deadlineDate: deadlines,
      ...(budget ? { budget: [String(budget)] } : {}),
      ...(callTitle ? { callTitle: [callTitle] } : {}),
    },
  };
}

/** Fake fetch serving [byType] = { "1": [results...], "8": [...] } as a single page each. */
function fakeEuFetch(byType) {
  return async (url, { body }) => {
    const query = JSON.parse(await body.get("query").text());
    const type = query.bool.must[0].terms.type[0];
    return { ok: true, json: async () => ({ results: byType[type] || [] }) };
  };
}

/**
 * Minimal fake Firestore: opportunities.where(externalId in ...).get() and
 * .add(); euFundingScoredCalls doc refs via getAll() and batch().set().
 */
function fakeDb(existingExternalIds = [], scoredIds = []) {
  const added = [];
  const scored = new Map(scoredIds.map((id) => [id, {}]));
  return {
    added,
    scored,
    async getAll(...refs) {
      return refs.map((r) => ({ id: r.id, exists: scored.has(r.id) }));
    },
    batch() {
      const ops = [];
      return {
        set(ref, data) {
          ops.push([ref.id, data]);
        },
        async commit() {
          ops.forEach(([id, data]) => scored.set(id, data));
        },
      };
    },
    collection(name) {
      if (name === "euFundingScoredCalls") {
        return { doc: (id) => ({ id }) };
      }
      assert.equal(name, "opportunities");
      return {
        where(field, op, values) {
          assert.equal(field, "externalId");
          assert.equal(op, "in");
          return {
            async get() {
              return {
                docs: existingExternalIds
                  .filter((id) => values.includes(id))
                  .map((id) => ({ data: () => ({ externalId: id }) })),
              };
            },
          };
        },
        async add(doc) {
          added.push(doc);
        },
      };
    },
  };
}

const fakeAdmin = {
  firestore: {
    Timestamp: {
      now: () => ({ now: true }),
      fromDate: (d) => ({ date: d.toISOString() }),
    },
  },
};

(async () => {
  console.log("euFundingConnector.test.js");

  await test("toCall keeps the soonest future deadline and builds the portal topic URL", () => {
    const call = toCall(
      apiResult({ id: "HORIZON-CL6-2027-01-X", deadlines: ["2025-01-01T00:00:00Z", "2027-05-01T00:00:00Z", "2027-02-01T00:00:00Z"] }),
      "1",
      NOW,
    );
    assert.equal(call.deadline.toISOString().slice(0, 10), "2027-02-01");
    assert.equal(
      call.sourceUrl,
      "https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/opportunities/topic-details/HORIZON-CL6-2027-01-X",
    );
  });

  await test("toCall drops records whose every deadline has passed (stale 'open' records)", () => {
    assert.equal(toCall(apiResult({ id: "NDICI-2023-MOBAF", deadlines: ["2023-06-15T17:00:00Z"] }), "1", NOW), null);
  });

  await test("toCall drops EU-internal programmes", () => {
    assert.equal(toCall(apiResult({ id: "EDF-2026-DA-X" }), "1", NOW), null);
    assert.equal(toCall(apiResult({ id: "HORIZON-MSCA-2026-PF" }), "1", NOW), null);
  });

  await test("isExcludedIdentifier matches whole prefixes only", () => {
    assert.equal(isExcludedIdentifier("ERC-2027-STG"), true);
    assert.equal(isExcludedIdentifier("HORIZON-CL4-2027-SPACE-03-34"), false);
    assert.equal(isExcludedIdentifier("EDUCATION-X"), false);
  });

  await test("portalUrlFor keeps a cascade-funding call's own portal link", () => {
    const url = "https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/opportunities/competitive-calls-cs/44087099";
    assert.equal(portalUrlFor("HORIZON-EIE-2021-INNOVSMES-01-01", "8", url), url);
  });

  await test("fetchOpenEuCalls merges both call types and dedupes by identifier", async () => {
    const calls = await fetchOpenEuCalls({
      now: NOW,
      fetchImpl: fakeEuFetch({
        1: [apiResult({ id: "HORIZON-A" }), apiResult({ id: "HORIZON-A", deadlines: ["2027-01-01T00:00:00Z"] })],
        8: [apiResult({ id: "HORIZON-B" })],
      }),
    });
    assert.deepEqual(calls.map((c) => c.identifier).sort(), ["HORIZON-A", "HORIZON-B"]);
    assert.equal(calls.find((c) => c.identifier === "HORIZON-A").deadline.toISOString().slice(0, 10), "2027-01-01");
  });

  await test("runEuFundingDiscovery saves only Kenya-eligible calls scoring >= 50, skipping already-saved ones", async () => {
    const db = fakeDb(["HORIZON-SAVED"]);
    let promptSeen = "";
    const result = await runEuFundingDiscovery({
      db,
      admin: fakeAdmin,
      now: NOW,
      logger: { info() {}, error() {} },
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeEuFetch({
        1: [
          apiResult({ id: "HORIZON-SAVED" }),
          apiResult({ id: "HORIZON-GOOD", title: "Digital agriculture in Africa", budget: 3000000 }),
          apiResult({ id: "HORIZON-LOW" }),
          apiResult({ id: "HORIZON-INELIGIBLE" }),
        ],
      }),
      scoreBatch: async (prompt) => {
        promptSeen = prompt;
        return [
          { index: 0, kenyaEligible: true, fitScorePercent: 82, kind: "grant", fitReasoning: "Fits the farm app.", eligibility: "Consortium partner" },
          { index: 1, kenyaEligible: true, fitScorePercent: 30, kind: "grant" },
          { index: 2, kenyaEligible: false, fitScorePercent: 90, kind: "grant" },
        ];
      },
    });

    assert.equal(promptSeen.includes("HORIZON-SAVED"), false, "already-saved call must not be re-scored");
    assert.deepEqual(result, { fetched: 4, alreadySaved: 1, scored: 3, created: 1 });
    assert.equal(db.added.length, 1);
    const doc = db.added[0];
    assert.equal(doc.title, "Digital agriculture in Africa");
    assert.equal(doc.externalId, "HORIZON-GOOD");
    assert.equal(doc.kind, "grant");
    assert.equal(doc.fitScorePercent, 82);
    assert.equal(doc.estimatedBudget, 3000000);
    assert.equal(doc.sourceUrlVerified, true);
    assert.equal(doc.client, "European Commission");
  });

  await test("quiet mode marks saved calls suppressNotification; normal mode doesn't", async () => {
    const run = async (quiet) => {
      const db = fakeDb();
      await runEuFundingDiscovery({
        db,
        admin: fakeAdmin,
        now: NOW,
        quiet,
        logger: { info() {}, error() {} },
        buildProfile: async () => "PROFILE",
        fetchImpl: fakeEuFetch({ 1: [apiResult({ id: "HORIZON-Q" })] }),
        scoreBatch: async () => [{ index: 0, kenyaEligible: true, fitScorePercent: 90, kind: "grant" }],
      });
      return db.added[0];
    };
    assert.equal((await run(true)).suppressNotification, true);
    assert.equal("suppressNotification" in (await run(false)), false);
  });

  await test("calls scored on an earlier run are never re-scored; every scored call is remembered", async () => {
    const db = fakeDb([], ["HORIZON-OLD"]);
    let promptSeen = "";
    await runEuFundingDiscovery({
      db,
      admin: fakeAdmin,
      now: NOW,
      logger: { info() {}, error() {} },
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeEuFetch({ 1: [apiResult({ id: "HORIZON-OLD" }), apiResult({ id: "HORIZON-NEW" })] }),
      scoreBatch: async (prompt) => {
        promptSeen = prompt;
        return [{ index: 0, kenyaEligible: true, fitScorePercent: 20, kind: "grant" }];
      },
    });
    assert.equal(promptSeen.includes("HORIZON-OLD"), false);
    assert.equal(promptSeen.includes("HORIZON-NEW"), true);
    assert.equal(db.scored.get("HORIZON-NEW").fitScorePercent, 20);
    assert.equal(db.added.length, 0);
  });

  await test("runEuFundingDiscovery survives a failed scoring batch", async () => {
    const result = await runEuFundingDiscovery({
      db: fakeDb(),
      admin: fakeAdmin,
      now: NOW,
      logger: { info() {}, error() {} },
      buildProfile: async () => "PROFILE",
      fetchImpl: fakeEuFetch({ 1: [apiResult({ id: "HORIZON-X" })] }),
      scoreBatch: async () => {
        throw new Error("model down");
      },
    });
    assert.equal(result.created, 0);
  });

  console.log(`\n${passed} test(s) passed`);
})();
