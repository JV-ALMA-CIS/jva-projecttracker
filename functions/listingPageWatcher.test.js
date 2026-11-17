/**
 * Plain-Node assertion tests for listingPageWatcher.js. Run with:
 *   node functions/listingPageWatcher.test.js
 */
const assert = require("node:assert/strict");
const { extractPostLinks, postTitle, toReadableCase, checkListingPage, WATCHED_LISTING_PAGES } = require("./listingPageWatcher");

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

const PAGE = WATCHED_LISTING_PAGES.find((p) => p.key === "us-embassy-kenya");
const NOW = new Date("2026-11-17T05:00:00Z");
const ROSSLYN = "https://ke.usembassy.gov/request-for-quotation-number-19ke5026q0128-underground-storage-water-tank-cleaning-rosslyn-ridge/";
const CCTV = "https://ke.usembassy.gov/request-for-quotation-number-19ke5026q0123-legat-cctv-for-jttf-k-building/";
const CLOSED = "https://ke.usembassy.gov/request-for-quotation-number-19ke5026q0116-refuse-removal-disposal-for-usg-houses/";

const LISTING = `
  <a href="https://ke.usembassy.gov/">Home</a>
  <a href="https://ke.usembassy.gov/tag/commercial-opportunities/">Commercial Opportunities</a>
  <article><a href="${ROSSLYN}">x</a><a href="${ROSSLYN}">dup</a></article>
  <article><a href="${CCTV}">x</a></article>
  <article><a href="${CLOSED}">x</a></article>`;

const post = (title) =>
  `<html><head><title>${title} - U.S. Embassy in Kenya</title><meta property="og:title" content="${title}" /></head>` +
  `<body><h1>U.S. Embassy in Kenya</h1><p>${title}. Quotations due 5 December 2026.</p></body></html>`;

function fakeFetch(pages) {
  return async (url) => {
    if (!(url in pages)) return { ok: false, status: 404, text: async () => "" };
    return { ok: true, status: 200, text: async () => pages[url] };
  };
}

function fakeDb({ processed = [], existingSourceUrls = [] } = {}) {
  const items = new Map(processed.map((id) => [id, {}]));
  const added = [];
  return {
    items,
    added,
    collection(name) {
      if (name === "watchedListingItems") {
        return {
          doc: (id) => ({
            async get() {
              return { exists: items.has(id) };
            },
            async set(data) {
              items.set(id, data);
            },
          }),
        };
      }
      assert.equal(name, "opportunities");
      return {
        where: (field, op, value) => ({
          limit: () => ({
            async get() {
              return { empty: !existingSourceUrls.includes(value) };
            },
          }),
        }),
        async add(doc) {
          added.push(doc);
          return { id: `opp-${added.length}` };
        },
      };
    },
  };
}

const PAGES = {
  [PAGE.url]: LISTING,
  [ROSSLYN]: post("REQUEST FOR QUOTATION NUMBER 19KE5026Q0128 UNDERGROUND STORAGE WATER TANK CLEANING - ROSSLYN RIDGE"),
  [CCTV]: post("Request for Quotation Number 19KE5026Q0123 Legat CCTV for JTTF-K Building"),
  [CLOSED]: post("Request for Quotation 19KE5026Q0116 Refuse Removal"),
};

const extract = async (prompt) =>
  prompt.includes("Refuse Removal")
    ? { isOpen: false, deadline: "2026-10-01T09:00:00Z", reference: "19KE5026Q0116", summary: "Closed." }
    : { isOpen: true, deadline: "2026-12-05T09:00:00Z", reference: "19KE5026Q01xx", summary: "Clean the underground tanks." };

(async () => {
  console.log("listingPageWatcher.test.js");

  await test("extractPostLinks keeps only RFQ post links, deduplicated, in page order", () => {
    assert.deepEqual(extractPostLinks(LISTING, PAGE.linkPattern), [ROSSLYN, CCTV, CLOSED]);
  });

  await test("postTitle uses og:title, keeps ' - Rosslyn Ridge', drops the site name, fixes ALL CAPS", () => {
    assert.equal(
      postTitle(PAGES[ROSSLYN]),
      "Request for Quotation Number 19KE5026Q0128 Underground Storage Water Tank Cleaning - Rosslyn Ridge",
    );
  });

  await test("toReadableCase leaves mixed-case titles alone and upper-cases known acronyms", () => {
    assert.equal(toReadableCase("Legat CCTV for JTTF-K Building"), "Legat CCTV for JTTF-K Building");
    assert.equal(toReadableCase("REQUEST FOR QUOTATION (RFQ)- PR16251147- FLOOR"), "Request for Quotation (RFQ)- PR16251147- Floor");
  });

  await test("first run: open RFQs become unscored tenders; closed ones are only remembered", async () => {
    const db = fakeDb();
    const counts = await checkListingPage(PAGE, { db, fetchImpl: fakeFetch(PAGES), extract, now: NOW });
    assert.deepEqual(counts, { links: 3, skipped: 0, created: 2, closed: 1, failed: 0 });
    const rosslyn = db.added.find((o) => o.sourceUrl === ROSSLYN);
    assert.equal(rosslyn.kind, "tender");
    assert.equal(rosslyn.fitScorePercent, 0, "left unscored so Match Analysis runs and decides the push");
    assert.equal(rosslyn.client, "U.S. Embassy Nairobi");
    assert.equal(rosslyn.tenderReferenceNumber, "19KE5026Q01xx");
    assert.equal(db.items.size, 3);
  });

  await test("second run: every post already remembered — no fetches of posts, no AI calls", async () => {
    const db = fakeDb();
    await checkListingPage(PAGE, { db, fetchImpl: fakeFetch(PAGES), extract, now: NOW });
    let aiCalls = 0;
    const counts = await checkListingPage(PAGE, {
      db,
      fetchImpl: fakeFetch(PAGES),
      extract: async (p) => (aiCalls++, extract(p)),
      now: NOW,
    });
    assert.equal(aiCalls, 0);
    assert.deepEqual(counts, { links: 3, skipped: 3, created: 0, closed: 0, failed: 0 });
  });

  await test("a post already saved by another path is remembered, not duplicated", async () => {
    const db = fakeDb({ existingSourceUrls: [ROSSLYN] });
    const counts = await checkListingPage(PAGE, { db, fetchImpl: fakeFetch(PAGES), extract, now: NOW });
    assert.equal(counts.created, 1);
    assert.equal(db.added.some((o) => o.sourceUrl === ROSSLYN), false);
  });

  await test("a post that fails to load is not remembered, so it's retried next run", async () => {
    const db = fakeDb();
    const pages = { ...PAGES };
    delete pages[CCTV];
    const counts = await checkListingPage(PAGE, { db, fetchImpl: fakeFetch(pages), extract, now: NOW });
    assert.equal(counts.failed, 1);
    assert.equal(db.items.size, 2);
  });

  console.log(`\n${passed} test(s) passed`);
})();
