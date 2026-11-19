/**
 * Plain-Node tests for funderWatchlist.js and grantEligibility.js. Run with:
 *   node functions/funderWatchlist.test.js
 */
const assert = require("node:assert/strict");
const { openCalls, similarTitles, isSameCall, checkFunderPage, FUNDER_PAGES } = require("./funderWatchlist");
const {
  parseEligibility,
  needsEligibilityCheck,
  buildEligibilityPrompt,
  DEFAULT_COMPANY_FACTS,
} = require("./grantEligibility");
const { matchNotifyScoreFor } = require("./matchScorePushNotification");
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

console.log("funderWatchlist.test.js");

const NOW = new Date("2026-11-19T06:00:00Z");
const PAGE = { key: "aecf", url: "https://www.aecfafrica.org/", name: "AECF (Africa Enterprise Challenge Fund)", client: "AECF", kind: "grant" };

/** Minimal Firestore fake: opportunities (where/limit/get/add) + a state collection. */
function fakeDb(existing = []) {
  const opportunities = [...existing];
  const state = new Map();
  const query = (filter) => ({
    limit: () => query(filter),
    async get() {
      const docs = opportunities.filter(filter).map((o) => ({ id: o.id, data: () => o }));
      return { empty: docs.length === 0, docs };
    },
  });
  return {
    opportunities,
    collection(name) {
      if (name === "opportunities") {
        return {
          where: (field, _op, value) => query((o) => o[field] === value),
          async add(data) {
            const id = `opp-${opportunities.length + 1}`;
            opportunities.push({ id, ...data });
            return { id };
          },
        };
      }
      return {
        doc: (id) => ({
          async get() {
            return { data: () => state.get(id) };
          },
          async set(data) {
            state.set(id, { ...(state.get(id) || {}), ...data });
          },
        }),
      };
    },
  };
}

const pageFetch = (html) => async () => ({ ok: true, status: 200, text: async () => html });

(async () => {
  await test("every watched funder page has a key, https url, name and kind", () => {
    const keys = new Set();
    for (const p of FUNDER_PAGES) {
      assert.ok(p.key && !keys.has(p.key), p.key);
      keys.add(p.key);
      assert.match(p.url, /^https:\/\//);
      assert.ok(p.name && p.client);
      assert.ok(["grant", "programme"].includes(p.kind));
    }
  });

  await test("openCalls keeps calls with a future deadline or rolling, drops the rest", () => {
    const calls = openCalls(
      PAGE,
      {
        calls: [
          { name: "Agribusiness Growth Challenge Fund", deadline: "2027-01-15", rolling: false, applyUrl: "https://www.aecfafrica.org/etcf", summary: "s" },
          { name: "Rolling window", deadline: null, rolling: true, applyUrl: "", summary: "" },
          { name: "Closed round", deadline: "2026-10-01" },
          { name: "No date, not rolling", deadline: null, rolling: false },
          { name: "" },
        ],
      },
      NOW,
    );
    assert.deepEqual(
      calls.map((c) => c.name),
      ["Agribusiness Growth Challenge Fund", "Rolling window"],
    );
    assert.equal(calls[0].externalId, "funder:aecf:agribusiness-growth-challenge-fund:2027");
    assert.equal(calls[1].externalId, "funder:aecf:rolling-window:rolling");
    assert.equal(calls[1].applyUrl, PAGE.url, "falls back to the funder page");
  });

  await test("openCalls tolerates a junk AI answer", () => {
    assert.deepEqual(openCalls(PAGE, null, NOW), []);
    assert.deepEqual(openCalls(PAGE, { calls: "nope" }, NOW), []);
  });

  await test("similarTitles matches the same call worded differently", () => {
    assert.equal(similarTitles("Fund for Innovation in Development (FID) - Open Call", "FID open call — Fund for Innovation in Development"), true);
    assert.equal(similarTitles("UNICEF Venture Fund", "Ashden Awards"), false);
  });

  await test("isSameCall ignores the funder's name; a funder's single main call matches anything at its link", () => {
    assert.equal(isSameCall("AECF — Agribusiness Growth Challenge Fund", "Women in Agribusiness window", PAGE), false);
    assert.equal(isSameCall("AECF Agribusiness Growth Challenge Fund", "Agribusiness Growth Challenge Fund", PAGE), true);
    const fid = { name: "Fund for Innovation in Development (FID)" };
    assert.equal(isSameCall("Fund for Innovation in Development (FID) - Open Call for Innovative Projects", "Open call for innovative projects", fid), true);
    assert.equal(isSameCall("FID - Open Call for Innovative Projects", "Fund for Innovation in Development", fid), true);
  });

  const extraction = {
    calls: [
      { name: "Agribusiness Growth Challenge Fund", deadline: "2027-01-15", rolling: false, applyUrl: "", summary: "For SMEs in Kenya." },
      { name: "Women in Agribusiness window", deadline: "2027-02-01", rolling: false, applyUrl: "", summary: "Non-profits only." },
    ],
  };
  const extract = async (prompt) => {
    if (prompt.includes("List every funding call")) return extraction;
    // Eligibility prompt: the second call excludes companies.
    return /Title: .*Women in Agribusiness/.test(prompt)
      ? { eligibility: "notEligible", eligibilityNote: "Non-profits only", fundingAmount: "" }
      : { eligibility: "eligible", eligibilityNote: "Kenyan SMEs eligible", fundingAmount: "US$1.5m" };
  };

  await test("first look at a funder page saves what's open without alerting", async () => {
    const db = fakeDb();
    const pushes = [];
    const r = await checkFunderPage(PAGE, {
      db,
      extract,
      fetchImpl: pageFetch("<main>first</main>"),
      notify: async (p) => pushes.push(p),
      now: NOW,
      facts: DEFAULT_COMPANY_FACTS,
    });
    assert.equal(r.created, 2);
    assert.equal(pushes.length, 0);
  });

  await test("a new open call is saved with its eligibility; only eligible ones push", async () => {
    const db = fakeDb();
    await db.collection("watchedFunderPages").doc(PAGE.key).set({ contentHash: "seen-before" });
    const pushes = [];
    const r = await checkFunderPage(PAGE, {
      db,
      extract,
      fetchImpl: pageFetch("<main>Agribusiness Growth Challenge Fund ... Women in Agribusiness</main>"),
      notify: async (p) => pushes.push(p),
      now: NOW,
      facts: DEFAULT_COMPANY_FACTS,
    });
    assert.deepEqual(r, { status: "checked", created: 2 });
    const [etcf, women] = db.opportunities;
    assert.equal(etcf.eligibility, "eligible");
    assert.equal(etcf.fundingAmount, "US$1.5m");
    assert.equal(etcf.watched, true);
    assert.equal(etcf.suppressNotification, true);
    assert.equal(women.eligibility, "notEligible");
    assert.equal(pushes.length, 1);
    assert.equal(pushes[0].type, "watchedCallOpen");
    assert.equal(pushes[0].opportunityId, "opp-1");
  });

  await test("an unchanged page costs nothing; a changed page doesn't duplicate known calls", async () => {
    const db = fakeDb();
    const deps = { db, extract, notify: async () => {}, now: NOW, facts: DEFAULT_COMPANY_FACTS };
    await checkFunderPage(PAGE, { ...deps, fetchImpl: pageFetch("<main>v1</main>") });
    let calls = 0;
    const counting = async (p) => {
      calls += 1;
      return extract(p);
    };
    const same = await checkFunderPage(PAGE, { ...deps, extract: counting, fetchImpl: pageFetch("<main>v1</main>") });
    assert.equal(same.status, "unchanged");
    assert.equal(calls, 0);
    const changed = await checkFunderPage(PAGE, { ...deps, fetchImpl: pageFetch("<main>v2</main>") });
    assert.deepEqual(changed, { status: "checked", created: 0 });
    assert.equal(db.opportunities.length, 2);
  });

  await test("a call already found by AI search (same link, similar title) is not added again", async () => {
    const db = fakeDb([
      { id: "x", title: "AECF Agribusiness Growth Challenge Fund", sourceUrl: PAGE.url, kind: "grant" },
    ]);
    const r = await checkFunderPage(PAGE, {
      db,
      extract,
      fetchImpl: pageFetch("<main>x</main>"),
      notify: async () => {},
      now: NOW,
      facts: DEFAULT_COMPANY_FACTS,
    });
    assert.equal(r.created, 1, "only the second call is new");
  });

  await test("scope policy: solar titles are out of scope, other work isn't", () => {
    const { outOfScopeReason } = require("./lib/scopePolicy");
    assert.equal(outOfScopeReason({ title: "Design and installation of grid-tied solar power system" }), "solar");
    assert.equal(outOfScopeReason({ title: "PV based electrification of the economy" }), "solar");
    assert.equal(outOfScopeReason({ title: "Photovoltaic mini-grids for health centres" }), "solar");
    assert.equal(outOfScopeReason({ title: "Construction of a school block", description: "with solar lighting" }), null);
    assert.equal(outOfScopeReason({ title: "Supply of GPS devices" }), null);
    assert.equal(outOfScopeReason({ title: "Renewable Energy Valleys in Africa to increase energy security" }), "energy");
    assert.equal(outOfScopeReason({ title: "Innovative microgrids for improved energy system integration" }), "energy");
    assert.equal(outOfScopeReason({ title: "Energy Transition Challenge Fund" }), "energy");
    assert.equal(outOfScopeReason({ title: "Geothermal well-pad civil works" }), "energy");
    assert.equal(outOfScopeReason({ title: "Renovation of the EU Delegation offices" }), null);
    assert.equal(outOfScopeReason({ title: "HVAC maintenance services at EACOP sites" }), null);
  });

  await test("a solar call on a funder page is neither saved nor alerted", async () => {
    const db = fakeDb();
    const pushes = [];
    const r = await checkFunderPage(PAGE, {
      db,
      extract: async (p) =>
        p.includes("List every funding call")
          ? { calls: [{ name: "Solar mini-grid window", deadline: "2027-03-01", rolling: false, applyUrl: "", summary: "" }] }
          : { eligibility: "eligible" },
      fetchImpl: pageFetch("<main>solar</main>"),
      notify: async (x) => pushes.push(x),
      now: NOW,
      facts: DEFAULT_COMPANY_FACTS,
    });
    assert.equal(r.created, 0);
    assert.equal(pushes.length, 0);
  });

  // --- grantEligibility -----------------------------------------------------

  await test("parseEligibility keeps valid values and falls back to unclear", () => {
    assert.deepEqual(parseEligibility({ eligibility: "needsPartner", eligibilityNote: "  EU  consortium ", fundingAmount: "€2m", matchFunding: "" }), {
      eligibility: "needsPartner",
      eligibilityNote: "EU consortium",
      fundingAmount: "€2m",
      matchFunding: "",
    });
    assert.equal(parseEligibility({ eligibility: "maybe" }).eligibility, "unclear");
    assert.equal(parseEligibility(null).eligibility, "unclear");
  });

  await test("only unchecked, live opportunities (tenders too) need a check", () => {
    assert.equal(needsEligibilityCheck({ kind: "grant", status: "discovered" }), true);
    assert.equal(needsEligibilityCheck({ kind: "programme", status: "reviewing" }), true);
    assert.equal(needsEligibilityCheck({ kind: "tender", status: "discovered" }), true);
    assert.equal(needsEligibilityCheck({ kind: "tender", status: "applied" }), false);
    assert.equal(needsEligibilityCheck({ kind: "grant", status: "archived" }), false);
    assert.equal(needsEligibilityCheck({ kind: "grant", status: "discovered", eligibilityCheckedAt: new Date() }), false);
  });

  await test("the eligibility prompt carries the company facts and the call page", () => {
    const prompt = buildEligibilityPrompt(
      { title: "Kirby Prize", description: "d", client: "Kirby", deadline: "2026-12-02", pageText: "US tax presence required" },
      DEFAULT_COMPANY_FACTS,
      NOW,
    );
    assert.match(prompt, /for-profit company/);
    assert.match(prompt, /PARENT COMPANY IS REGISTERED IN ITALY/);
    assert.match(prompt, /via Italian parent/);
    assert.match(prompt, /US tax presence required/);
    assert.match(prompt, /"notEligible"/);
  });

  await test("a not-eligible grant never alerts and gets no deadline reminder", () => {
    const grant = { kind: "grant", status: "discovered", fitScorePercent: 90, eligibility: "notEligible", deadline: new Date(NOW.getTime() + 2 * 86400000), watched: true };
    assert.equal(matchNotifyScoreFor(grant), null);
    assert.equal(reminderDue(grant, NOW), null);
    assert.ok(reminderDue({ ...grant, status: "reviewing" }, NOW), "unless the team is reviewing it");
    assert.equal(matchNotifyScoreFor({ ...grant, eligibility: "eligible" }), 90);
    assert.equal(matchNotifyScoreFor({ ...grant, eligibility: "needsPartner" }), null, "consortium-only: no instant alert");
    assert.equal(reminderDue({ ...grant, eligibility: "needsPartner" }, NOW), null);
  });

  console.log(`\n${passed} test(s) passed`);
})();
