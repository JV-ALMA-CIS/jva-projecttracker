/**
 * Plain-Node assertion tests for tenderSourceConnector.js — same convention
 * as businessUnitMatching.test.js. Run with:
 *   node functions/connectors/tenderSourceConnector.test.js
 */
const assert = require("node:assert/strict");
const {
  isGroundingRedirectStub,
  createOpportunitiesFromCandidates,
  checkUrlReachable,
} = require("./tenderSourceConnector");

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

async function asyncTest(name, fn) {
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

console.log("tenderSourceConnector.test.js");

test("isGroundingRedirectStub true for the real Gemini grounding-redirect URL shape", () => {
  assert.equal(
    isGroundingRedirectStub(
      "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AXQE123",
    ),
    true,
  );
});

test("isGroundingRedirectStub false for an unrelated host with the same path segment", () => {
  assert.equal(
    isGroundingRedirectStub("https://example.com/grounding-api-redirect/AXQE123"),
    false,
  );
});

test("isGroundingRedirectStub false for vertexaisearch.cloud.google.com without the redirect path", () => {
  assert.equal(
    isGroundingRedirectStub("https://vertexaisearch.cloud.google.com/other"),
    false,
  );
});

test("isGroundingRedirectStub false for a malformed URL string", () => {
  assert.equal(isGroundingRedirectStub("not a url"), false);
});

test("isGroundingRedirectStub false for a non-string input", () => {
  assert.equal(isGroundingRedirectStub(null), false);
  assert.equal(isGroundingRedirectStub(undefined), false);
});

// --- checkUrlReachable -------------------------------------------------

// Stubs global fetch for the duration of fn(), restoring it afterward —
// checkUrlReachable calls the real global `fetch`, so this is the only way
// to test it deterministically without a real network call. Each entry in
// `responses` is either an Error (fetch throws), a bare number (status code,
// body defaults to "ok" plain-text content), or {status, body} for tests
// that need to control the response text (e.g. soft-404 detection).
async function withStubbedFetch(responses, fn) {
  const originalFetch = global.fetch;
  let call = 0;
  global.fetch = async (url, options) => {
    const response = responses[call];
    call += 1;
    if (response instanceof Error) throw response;
    if (typeof response === "number") {
      return { status: response, text: async () => "ok" };
    }
    const { status, body, bodyReadFails } = response;
    return {
      status,
      text: async () => {
        if (bodyReadFails) throw new Error("stream error");
        return body;
      },
    };
  };
  try {
    await fn();
  } finally {
    global.fetch = originalFetch;
  }
}

// --- createOpportunitiesFromCandidates -------------------------------------

function fakeDb(existingSourceUrls = []) {
  const written = [];
  return {
    written,
    collection(name) {
      assert.equal(name, "opportunities");
      return {
        where(field, op, value) {
          assert.equal(field, "sourceUrl");
          assert.equal(op, "==");
          return {
            limit() {
              return this;
            },
            async get() {
              const matches = existingSourceUrls.includes(value);
              return { empty: !matches, docs: matches ? [{}] : [] };
            },
          };
        },
        async add(data) {
          written.push(data);
          return { id: `doc-${written.length}` };
        },
      };
    },
  };
}

// admin.firestore.Timestamp is used by createOpportunitiesFromCandidates —
// stub the minimum shape it needs without pulling in firebase-admin.
const admin = require("firebase-admin");
if (!admin.firestore) {
  admin.firestore = () => {};
}
admin.firestore.Timestamp = {
  now: () => ({ _stub: "now" }),
  fromDate: (d) => ({ _stub: "fromDate", value: d }),
};

(async () => {
  await asyncTest(
    "checkUrlReachable true when HEAD returns 2xx and the follow-up GET body has no soft-404 phrasing",
    () =>
      withStubbedFetch([200, { status: 200, body: "<html>Tender details...</html>" }], async () => {
        assert.equal(await checkUrlReachable("https://example.org"), true);
      }),
  );

  await asyncTest(
    "checkUrlReachable true when HEAD returns a 3xx redirect and the GET confirms a real page",
    () =>
      withStubbedFetch([301, { status: 200, body: "Tender opportunity details" }], async () => {
        assert.equal(await checkUrlReachable("https://example.org"), true);
      }),
  );

  await asyncTest(
    "checkUrlReachable false when HEAD returns a 404 (fabricated/dead URL) — no GET needed",
    () =>
      withStubbedFetch([404], async () => {
        assert.equal(await checkUrlReachable("https://example.org"), false);
      }),
  );

  await asyncTest(
    "checkUrlReachable falls back to GET when HEAD returns 405, and trusts a clean body",
    () =>
      withStubbedFetch([405, { status: 200, body: "Tender opportunity details" }], async () => {
        assert.equal(await checkUrlReachable("https://example.org"), true);
      }),
  );

  await asyncTest(
    "checkUrlReachable false when both HEAD and the GET fallback throw",
    () =>
      withStubbedFetch(
        [new Error("DNS failure"), new Error("DNS failure")],
        async () => {
          assert.equal(await checkUrlReachable("https://example.org"), false);
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable true when HEAD throws but the GET fallback succeeds with a clean body",
    () =>
      withStubbedFetch(
        [new Error("connection reset"), { status: 200, body: "Tender details" }],
        async () => {
          assert.equal(await checkUrlReachable("https://example.org"), true);
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable false when the GET returns 4xx after an inconclusive HEAD",
    () =>
      withStubbedFetch([405, 404], async () => {
        assert.equal(await checkUrlReachable("https://example.org"), false);
      }),
  );

  // --- soft-404 detection -------------------------------------------------

  await asyncTest(
    "checkUrlReachable false when HEAD is 200 but the body is a soft-404 not-found page",
    () =>
      withStubbedFetch(
        [
          200,
          {
            status: 200,
            body: "<html><h1>Sorry, this page could not be found.</h1></html>",
          },
        ],
        async () => {
          assert.equal(await checkUrlReachable("https://ke.usembassy.gov/some-fabricated-slug/"), false);
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable false for a soft-404 phrased as 'page you were looking for'",
    () =>
      withStubbedFetch(
        [
          200,
          {
            status: 200,
            body: "The page you were looking for doesn't exist. Try our homepage instead.",
          },
        ],
        async () => {
          assert.equal(await checkUrlReachable("https://example.org/dead-link"), false);
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable false when HEAD is 200 but the body is a WAF soft-block page (real ke.usembassy.gov case)",
    () =>
      withStubbedFetch(
        [
          200,
          {
            status: 200,
            body: "We're sorry, this site is currently experiencing technical difficulties. Please try again in a few moments. Exception: forbidden",
          },
        ],
        async () => {
          assert.equal(
            await checkUrlReachable(
              "https://ke.usembassy.gov/wp-content/uploads/sites/115/19KE5026Q0091_Construction-Services.pdf",
            ),
            false,
          );
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable true when the body legitimately mentions '404' as a reference number, not a not-found page",
    () =>
      withStubbedFetch(
        [
          200,
          {
            status: 200,
            body: "Tender Reference: PR16404577 — Construction Services for Roof Replacement",
          },
        ],
        async () => {
          assert.equal(await checkUrlReachable("https://example.org/tender/pr16404577"), true);
        },
      ),
  );

  await asyncTest(
    "checkUrlReachable true when the body is unreadable — falls back to trusting the status code",
    () =>
      withStubbedFetch(
        [200, { status: 200, bodyReadFails: true }],
        async () => {
          assert.equal(await checkUrlReachable("https://example.org"), true);
        },
      ),
  );

  await asyncTest(
    "createOpportunitiesFromCandidates skips a candidate whose sourceUrl is a grounding-redirect stub",
    async () => {
      const db = fakeDb();
      const source = { id: "src-1", category: "developmentPartner", discoveryMethod: "api" };
      const result = await createOpportunitiesFromCandidates(
        db,
        source,
        [
          {
            title: "Real tender",
            sourceUrl: "https://example.org/tender/1",
          },
          {
            title: "Grounding stub tender",
            sourceUrl:
              "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AXQE123",
          },
        ],
        { reachabilityCheck: async () => true },
      );

      assert.equal(result.created, 1);
      assert.equal(db.written.length, 1);
      assert.equal(db.written[0].sourceUrl, "https://example.org/tender/1");
    },
  );

  await asyncTest(
    "createOpportunitiesFromCandidates still writes a normal candidate when no stub is present",
    async () => {
      const db = fakeDb();
      const source = { id: "src-1", category: "developmentPartner", discoveryMethod: "api" };
      const result = await createOpportunitiesFromCandidates(
        db,
        source,
        [{ title: "Real tender", sourceUrl: "https://example.org/tender/1" }],
        { reachabilityCheck: async () => true },
      );

      assert.equal(result.created, 1);
      assert.equal(db.written.length, 1);
    },
  );

  await asyncTest(
    "createOpportunitiesFromCandidates stores sourceUrlVerified: true when the reachability check succeeds",
    async () => {
      const db = fakeDb();
      const source = { id: "src-1", category: "developmentPartner", discoveryMethod: "api" };
      await createOpportunitiesFromCandidates(
        db,
        source,
        [{ title: "Real tender", sourceUrl: "https://example.org/tender/1" }],
        { reachabilityCheck: async () => true },
      );

      assert.equal(db.written[0].sourceUrlVerified, true);
      assert.notEqual(db.written[0].sourceUrlVerifiedAt, null);
    },
  );

  await asyncTest(
    "createOpportunitiesFromCandidates still creates the opportunity (not silently dropped) " +
      "when the reachability check fails, but stores sourceUrlVerified: false",
    async () => {
      const db = fakeDb();
      const source = { id: "src-1", category: "developmentPartner", discoveryMethod: "api" };
      const result = await createOpportunitiesFromCandidates(
        db,
        source,
        [
          {
            title: "Fabricated tender",
            sourceUrl: "https://tenderskenya.co.ke/tenders/fake-1",
          },
        ],
        { reachabilityCheck: async () => false },
      );

      assert.equal(result.created, 1);
      assert.equal(db.written.length, 1);
      assert.equal(db.written[0].sourceUrlVerified, false);
      assert.equal(db.written[0].sourceUrlVerifiedAt, null);
    },
  );

  console.log(`\n${passed} test(s) passed`);
})();