/**
 * Plain-Node assertion tests for buyerPolicy.js and cleanupPublicBuyers.js.
 * Run with: node functions/lib/buyerPolicy.test.js
 */
const assert = require("node:assert/strict");
const { isDonorFunded, ruleDecision, decideBuyers } = require("./buyerPolicy");
const { cleanupPublicBuyers } = require("../cleanupPublicBuyers");

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

const tender = (o) => ({ kind: "tender", title: "Some tender", ...o });

(async () => {
  console.log("buyerPolicy.test.js");

  await test("isDonorFunded recognises donor wording", () => {
    assert.equal(isDonorFunded("Rehabilitation of boreholes — financed by the World Bank (IDA Credit No. 1234)"), true);
    assert.equal(isDonorFunded("Supply of transformers for KETRACO"), false);
    assert.equal(isDonorFunded("AfDB-funded rural electrification"), true);
  });

  await test("rules: grants, colleague-added, embassy and donor-funded are always kept", () => {
    assert.equal(ruleDecision(tender({ kind: "grant", tags: ["ppip"] })).exclude, false);
    assert.equal(ruleDecision(tender({ addedByUid: "u1", tags: ["ppip"] })).exclude, false);
    assert.equal(ruleDecision(tender({ client: "U.S. Embassy Nairobi" })).exclude, false);
    assert.equal(ruleDecision(tender({ tags: ["ppip"], title: "Water works financed by the World Bank" })).exclude, false);
  });

  await test("rules: PPIP and county tenders are excluded", () => {
    assert.equal(ruleDecision(tender({ tags: ["ppip"], client: "Murang'a Water and Sanitation Co." })).exclude, true);
    assert.equal(ruleDecision(tender({ tenderSourceCategory: "countyGovernment" })).exclude, true);
  });

  await test("rules: NGO / UN / development-partner buyers are kept without an AI call", () => {
    assert.equal(ruleDecision(tender({ tenderSourceCategory: "ngo" })).exclude, false);
    assert.equal(ruleDecision(tender({ tenderSourceCategory: "unAgency" })).exclude, false);
  });

  await test("unclear buyers go to the AI: public excluded, donor-funded public kept, private kept", async () => {
    const opps = [
      tender({ title: "Supply of conductors", client: "KETRACO" }),
      tender({ title: "Road works", client: "Ministry of Roads" }),
      tender({ title: "Office fit-out", client: "Safaricom PLC" }),
    ];
    const decisions = await decideBuyers(opps, {
      classify: async () => [
        { index: 0, buyerType: "kenyaPublic", donorFunded: false },
        { index: 1, buyerType: "kenyaPublic", donorFunded: true },
        { index: 2, buyerType: "private", donorFunded: false },
      ],
    });
    assert.deepEqual(decisions.map((d) => d.exclude), [true, false, false]);
  });

  await test("if the AI check fails, opportunities are kept (never hidden by an error)", async () => {
    const decisions = await decideBuyers([tender({ client: "KETRACO" })], {
      classify: async () => {
        throw new Error("model down");
      },
    });
    assert.equal(decisions[0].exclude, false);
  });

  await test("only undecided opportunities are sent to the AI", async () => {
    let prompt = "";
    await decideBuyers([tender({ tags: ["ppip"] }), tender({ title: "Mystery tender XYZ" })], {
      classify: async (p) => ((prompt = p), [{ index: 0, buyerType: "unknown" }]),
    });
    assert.equal(prompt.includes("Mystery tender XYZ"), true);
    assert.equal(prompt.includes("0 | Some tender"), false);
  });

  // --- cleanupPublicBuyers -------------------------------------------------

  function fakeDb(opportunities, sources) {
    const updates = [];
    const ref = (id) => ({ id, update: async (u) => updates.push([id, u]) });
    return {
      updates,
      batch() {
        const ops = [];
        return { update: (r, u) => ops.push([r.id, u]), commit: async () => ops.forEach((o) => updates.push(o)) };
      },
      collection(name) {
        if (name === "opportunities") {
          return {
            where: (f, op, v) => ({
              async get() {
                assert.deepEqual([f, op, v], ["status", "==", "discovered"]);
                return { docs: opportunities.map(([id, data]) => ({ id, ref: ref(id), data: () => data })) };
              },
            }),
          };
        }
        assert.equal(name, "tenderSources");
        return {
          where: () => ({
            async get() {
              return { docs: sources.map(([id, data]) => ({ id, ref: ref(id), data: () => data })) };
            },
          }),
        };
      },
    };
  }

  await test("cleanup archives public-body tenders and switches off government sources", async () => {
    const db = fakeDb(
      [
        ["ppip1", tender({ tags: ["ppip"], client: "Embu County Government" })],
        ["grant1", { kind: "grant", title: "ABIL EXPLORE" }],
        ["ngo1", tender({ tenderSourceCategory: "ngo" })],
      ],
      [["src-ppip", { seedKey: "ke-tenders", enabled: true }], ["src-old", { seedKey: "tz-procurement", enabled: false }]],
    );
    const result = await cleanupPublicBuyers({
      db,
      Timestamp: { fromDate: (d) => d.toISOString() },
      classify: async () => [],
      logger: { info() {} },
      now: new Date("2026-11-17T10:00:00Z"),
    });
    assert.equal(result.archived, 1);
    assert.equal(result.kept, 2);
    assert.equal(result.sourcesDisabled, 1);
    const [id, update] = db.updates.find(([i]) => i === "ppip1");
    assert.equal(id, "ppip1");
    assert.equal(update.status, "archived");
    assert.equal(update.archivedReason, "publicBuyer");
    assert.equal(db.updates.some(([i]) => i === "grant1" || i === "ngo1"), false);
  });

  console.log(`\n${passed} test(s) passed`);
})();
