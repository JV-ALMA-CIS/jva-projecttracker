/**
 * Plain-Node assertion tests for groundedUrlValidation.js — same convention
 * as businessUnitMatching.test.js and tenderSourceConnector.test.js. Run
 * with:
 *   node functions/lib/groundedUrlValidation.test.js
 */
const assert = require("node:assert/strict");
const { applyGroundedUrlCrossCheck } = require("./groundedUrlValidation");

let passed = 0;
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

console.log("groundedUrlValidation.test.js");

/**
 * Builds a fake Gemini response carrying grounding-chunk redirect URIs, and
 * stubs global fetch so resolveGroundingUrl's HEAD/GET calls resolve each
 * redirect URI to the given real URL without a real network call.
 */
function fakeGroundedResponse(redirectToRealUrl) {
  return {
    candidates: [
      {
        groundingMetadata: {
          groundingChunks: Object.keys(redirectToRealUrl).map((redirectUri) => ({
            web: { uri: redirectUri },
          })),
        },
      },
    ],
  };
}

async function withStubbedFetch(redirectToRealUrl, fn) {
  const originalFetch = global.fetch;
  global.fetch = async (url) => {
    const realUrl = redirectToRealUrl[url];
    if (!realUrl) {
      return { status: 404, url: null, text: async () => "" };
    }
    return { status: 200, url: realUrl, text: async () => "Tender details" };
  };
  try {
    await fn();
  } finally {
    global.fetch = originalFetch;
  }
}

(async () => {
  await asyncTest(
    "keeps a candidate whose sourceUrl exactly matches a resolved grounded URL, rewritten to that exact URL",
    async () => {
      await withStubbedFetch(
        { "https://redirect.example/1": "https://real.example/tender/42" },
        async () => {
          const response = fakeGroundedResponse({
            "https://redirect.example/1": "https://real.example/tender/42",
          });
          const { kept, dropped } = await applyGroundedUrlCrossCheck(
            [{ title: "Real tender", sourceUrl: "https://real.example/tender/42" }],
            response,
          );
          assert.equal(kept.length, 1);
          assert.equal(kept[0].sourceUrl, "https://real.example/tender/42");
          assert.equal(dropped.length, 0);
        },
      );
    },
  );

  await asyncTest(
    "drops a candidate whose sourceUrl is on the right domain but an invented path (no exact grounded match) — " +
      "the ke.usembassy.gov regression case",
    async () => {
      await withStubbedFetch(
        {
          "https://redirect.example/1":
            "https://ke.usembassy.gov/request-for-quotation-real-page",
        },
        async () => {
          const response = fakeGroundedResponse({
            "https://redirect.example/1":
              "https://ke.usembassy.gov/request-for-quotation-real-page",
          });
          const { kept, dropped } = await applyGroundedUrlCrossCheck(
            [
              {
                title: "Invented path tender",
                sourceUrl: "https://ke.usembassy.gov/embassy-of-the-united-states-fabricated",
              },
            ],
            response,
          );
          assert.equal(kept.length, 0);
          assert.equal(dropped.length, 1);
          assert.equal(
            dropped[0].sourceUrl,
            "https://ke.usembassy.gov/embassy-of-the-united-states-fabricated",
          );
        },
      );
    },
  );

  await asyncTest(
    "trailing-slash differences between the candidate and the resolved grounded URL still count as an exact match",
    async () => {
      await withStubbedFetch(
        { "https://redirect.example/1": "https://real.example/tender/42" },
        async () => {
          const response = fakeGroundedResponse({
            "https://redirect.example/1": "https://real.example/tender/42",
          });
          const { kept } = await applyGroundedUrlCrossCheck(
            [{ title: "Real tender", sourceUrl: "https://real.example/tender/42/" }],
            response,
          );
          assert.equal(kept.length, 1);
        },
      );
    },
  );

  await asyncTest(
    "when no grounding metadata is present at all, candidates pass through unchanged (cross-check cannot run)",
    async () => {
      const response = { candidates: [{}] };
      const { kept, dropped } = await applyGroundedUrlCrossCheck(
        [{ title: "Untouched", sourceUrl: "https://example.org/whatever" }],
        response,
      );
      assert.equal(kept.length, 1);
      assert.equal(kept[0].sourceUrl, "https://example.org/whatever");
      assert.equal(dropped.length, 0);
    },
  );

  await asyncTest(
    "fails closed when grounding metadata IS present but every citation redirect fails to resolve — " +
      "an empty resolved-URL map must drop every candidate, not be treated as 'no grounding'",
    async () => {
      await withStubbedFetch({}, async () => {
        // fakeGroundedResponse's redirect URI is present in groundingChunks
        // but withStubbedFetch({}) means it resolves to nothing (404/null) —
        // this is the "available: true, urls: empty Map" case.
        const response = fakeGroundedResponse({ "https://redirect.example/1": null });
        const { kept, dropped } = await applyGroundedUrlCrossCheck(
          [{ title: "Should be dropped", sourceUrl: "https://example.org/tender/1" }],
          response,
        );
        assert.equal(kept.length, 0);
        assert.equal(dropped.length, 1);
      });
    },
  );

  await asyncTest(
    "a candidate with no sourceUrl is dropped rather than crashing the cross-check",
    async () => {
      await withStubbedFetch(
        { "https://redirect.example/1": "https://real.example/tender/42" },
        async () => {
          const response = fakeGroundedResponse({
            "https://redirect.example/1": "https://real.example/tender/42",
          });
          const { kept, dropped } = await applyGroundedUrlCrossCheck(
            [{ title: "No URL" }],
            response,
          );
          assert.equal(kept.length, 0);
          assert.equal(dropped.length, 1);
        },
      );
    },
  );

  await asyncTest(
    "returns groundedUrls listing every real page grounding retrieved this run, regardless of whether any candidate matched it",
    async () => {
      await withStubbedFetch(
        {
          "https://redirect.example/1": "https://real.example/tender/42",
          "https://redirect.example/2": "https://real.example/tender/other-page",
        },
        async () => {
          const response = fakeGroundedResponse({
            "https://redirect.example/1": "https://real.example/tender/42",
            "https://redirect.example/2": "https://real.example/tender/other-page",
          });
          // Only one candidate, matching only one of the two grounded URLs —
          // the other grounded URL was retrieved by Google Search grounding
          // but no candidate happened to claim it.
          const { kept, groundedUrls } = await applyGroundedUrlCrossCheck(
            [{ title: "Real tender", sourceUrl: "https://real.example/tender/42" }],
            response,
          );
          assert.equal(kept.length, 1);
          assert.equal(groundedUrls.length, 2);
          assert.ok(groundedUrls.includes("https://real.example/tender/42"));
          assert.ok(groundedUrls.includes("https://real.example/tender/other-page"));
        },
      );
    },
  );

  await asyncTest(
    "groundedUrls is [] when no grounding metadata is present at all",
    async () => {
      const response = { candidates: [{}] };
      const { groundedUrls } = await applyGroundedUrlCrossCheck(
        [{ title: "Untouched", sourceUrl: "https://example.org/whatever" }],
        response,
      );
      assert.deepEqual(groundedUrls, []);
    },
  );

  console.log(`\n${passed} test(s) passed`);
})();
