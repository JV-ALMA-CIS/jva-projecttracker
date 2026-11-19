/**
 * Plain-Node tests for undpConnector.js and tenderPageWatchlist.js. Run with:
 *   node functions/connectors/undpConnector.test.js
 */
const assert = require("node:assert/strict");
const { parseUndpDeadline, parseNotices } = require("./undpConnector");
const { checkTenderPage, TENDER_PAGES } = require("../tenderPageWatchlist");
const { isAllowedGrantCandidate } = require("../opportunityRelevance");

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

console.log("undpConnector.test.js");

const NOW = new Date("2026-11-19T06:00:00Z");

const row = ({ href = "view_negotiation.cfm?nego_id=51608", title, ref = "UNDP-KEN-00794", office = "UNDP-KEN/KENYA ", process = "RFP - Request for proposal", deadline = "02-Dec-26<br>09:00 AM (New York time)" }) => `
<a href="${href}" class="vacanciesTableLink vacanciesTable__row">
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> Title </div> <span>${title}</span> </div>
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> Ref No </div> <span>${ref}</span> </div>
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> UNDP Office/Country </div> <span>${office}</span> </div>
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> Process </div> <span>${process}</span> </div>
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> Deadline </div> <span><nobr>${deadline}</nobr></span> </div>
 <div class="vacanciesTable__cell"> <div class="vacanciesTable__cell__label"> Posted </div> <span><nobr>10-Nov-26</nobr></span> </div>
</a>`;

(async () => {
  await test("UNDP deadline (New York time) is parsed", () => {
    assert.equal(parseUndpDeadline("02-Dec-26 09:00 AM (New York time)").toISOString(), "2026-12-02T14:00:00.000Z");
    assert.equal(parseUndpDeadline("02-Dec-26 01:30 PM").toISOString(), "2026-12-02T18:30:00.000Z");
    assert.equal(parseUndpDeadline("nonsense"), null);
  });

  await test("keeps open East African rows; drops other countries, IC hires and closed ones", () => {
    const html = [
      row({ title: "Renovation of UNDP Kenya offices" }),
      row({ href: "view_negotiation.cfm?nego_id=2", title: "Supply of desks", office: "UNDP-UGA/UGANDA" }),
      row({ href: "view_negotiation.cfm?nego_id=3", title: "Works in Lagos", office: "UNDP-NGA/NIGERIA" }),
      row({ href: "view_negotiation.cfm?nego_id=4", title: "M&E consultant", process: "IC - Individual contractor" }),
      row({ href: "view_negotiation.cfm?nego_id=5", title: "Closed one", deadline: "18-Nov-26<br>09:00 AM (New York time)" }),
    ].join("\n");
    const notices = parseNotices(html, NOW);
    assert.deepEqual(notices.map((n) => n.title), ["Renovation of UNDP Kenya offices", "Supply of desks"]);
    assert.equal(notices[0].country, "Kenya");
    assert.equal(notices[0].buyer, "UNDP Kenya");
    assert.equal(notices[0].sourceUrl, "https://procurement-notices.undp.org/view_negotiation.cfm?nego_id=51608");
    assert.equal(notices[0].id, "nego_id-51608");
    assert.equal(notices[1].country, "Uganda");
  });

  // --- tender page watchlist ------------------------------------------------

  const page = TENDER_PAGES.find((p) => p.key === "kenya-red-cross");

  function fakeDb() {
    const opportunities = [];
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
              opportunities.push({ id: `o${opportunities.length + 1}`, ...data });
              return { id: `o${opportunities.length}` };
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

  const extract = async () => ({
    calls: [
      { name: "RFP PRF33262 End-term evaluation, Nairobi and Mombasa", deadline: "2026-11-24", rolling: false, applyUrl: "", summary: "Evaluation." },
      { name: "Supply and installation of solar water heaters", deadline: "2026-12-10", rolling: false, applyUrl: "", summary: "" },
      { name: "Old closed tender", deadline: "2026-10-28", rolling: false, applyUrl: "", summary: "" },
    ],
  });
  const fetchOk = (html) => async () => ({ ok: true, status: 200, text: async () => html });

  await test("tender pages: saves open, in-scope tenders unscored; first look scores quietly", async () => {
    const db = fakeDb();
    const r = await checkTenderPage(page, { db, extract, fetchImpl: fetchOk("<main>v1</main>"), now: NOW });
    assert.deepEqual(r, { status: "checked", created: 1 });
    const [o] = db.opportunities;
    assert.equal(o.kind, "tender");
    assert.equal(o.fitScorePercent, 0);
    assert.equal(o.scoreQuietly, true);
    assert.equal(o.suppressNotification, undefined);
    assert.ok(o.tags.includes("watched-listing"));
    assert.match(o.externalId, /^tenderpage:kenya-red-cross:/);
  });

  await test("tender pages: later changes alert normally and never duplicate", async () => {
    const db = fakeDb();
    await checkTenderPage(page, { db, extract, fetchImpl: fetchOk("<main>v1</main>"), now: NOW });
    const unchanged = await checkTenderPage(page, { db, extract, fetchImpl: fetchOk("<main>v1</main>"), now: NOW });
    assert.equal(unchanged.status, "unchanged");
    const more = async () => ({
      calls: [
        { name: "RFP PRF33262 End-term evaluation, Nairobi and Mombasa", deadline: "2026-11-24", rolling: false },
        { name: "Renovation of Kenya Red Cross Nairobi warehouse", deadline: "2026-12-15", rolling: false },
      ],
    });
    const r = await checkTenderPage(page, { db, extract: more, fetchImpl: fetchOk("<main>v2</main>"), now: NOW });
    assert.equal(r.created, 1);
    assert.equal(db.opportunities[1].scoreQuietly, undefined);
  });

  await test("every tender page has a key, https url, client and buyer category", () => {
    for (const p of TENDER_PAGES) {
      assert.match(p.url, /^https:\/\//);
      assert.ok(p.key && p.client && p.tenderSourceCategory);
    }
  });

  // --- grant geography with the Italian parent -------------------------------

  await test("EU-only grant calls are now allowed (Italian parent), with backing wording", () => {
    assert.equal(
      isAllowedGrantCandidate({ title: "EIC Accelerator", description: "Open to SMEs established in EU Member States", kenyaEligible: true }),
      true,
    );
    assert.equal(isAllowedGrantCandidate({ title: "Some call", description: "Open to SMEs", kenyaEligible: true }), false);
    assert.equal(isAllowedGrantCandidate({ title: "EU call", description: "EU Member States only", kenyaEligible: false }), false);
  });

  console.log(`\n${passed} test(s) passed`);
})();
