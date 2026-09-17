/**
 * Plain-Node assertion tests for apiConnector.js — same convention as
 * tenderSourceConnector.test.js. `buildWebsiteFallbackCandidates` and
 * `pickUnambiguousGroundedFallback` are covered here: they're the pure,
 * independently testable pieces of new logic in this connector, testable
 * without stubbing Gemini/fetch. `_syncAiSearch` itself calls `genAiClient()`
 * directly with no injection seam (same as every other AI-search Cloud
 * Function in this codebase — see runOpportunityDiscovery in index.js, also
 * untested at that level), so it isn't covered end-to-end here; its behavior
 * changes (using the shared applyGroundedUrlCrossCheck, and calling
 * buildWebsiteFallbackCandidates on the dropped set + grounded URLs) are
 * each covered by their own dedicated test file (groundedUrlValidation.test.js
 * and this file, respectively).
 *
 * Run with:
 *   node functions/connectors/apiConnector.test.js
 */
const assert = require("node:assert/strict");
const {
  buildWebsiteFallbackCandidates,
  pickUnambiguousGroundedFallback,
  enforceSameDomainWhenWebsiteKnown,
  applyGeographyGate,
} = require("./apiConnector");

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

console.log("apiConnector.test.js");

test("returns [] when source.website is unset, even with dropped candidates", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  assert.deepEqual(buildWebsiteFallbackCandidates(dropped, { id: "src-1" }), []);
});

test("returns [] when there are no dropped candidates", () => {
  assert.deepEqual(
    buildWebsiteFallbackCandidates([], { id: "src-1", website: "https://real.example" }),
    [],
  );
});

test("rewrites a dropped candidate's sourceUrl to source.website and marks it sourceUrlIsFallback", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const fallbacks = buildWebsiteFallbackCandidates(dropped, {
    id: "src-1",
    website: "https://real.example",
  });

  assert.equal(fallbacks.length, 1);
  assert.equal(fallbacks[0].sourceUrl, "https://real.example");
  assert.equal(fallbacks[0].sourceUrlIsFallback, true);
  assert.equal(fallbacks[0].title, "Dropped tender");
});

test("drops a candidate with no title even when source.website is set", () => {
  const dropped = [{ sourceUrl: "https://fake.example/1" }];
  const fallbacks = buildWebsiteFallbackCandidates(dropped, {
    id: "src-1",
    website: "https://real.example",
  });

  assert.equal(fallbacks.length, 0);
});

test("caps fallbacks at MAX_WEBSITE_FALLBACKS_PER_RUN (3) even when more candidates were dropped", () => {
  const dropped = [1, 2, 3, 4, 5].map((n) => ({
    title: `Tender ${n}`,
    sourceUrl: `https://fake.example/${n}`,
  }));
  const fallbacks = buildWebsiteFallbackCandidates(dropped, {
    id: "src-1",
    website: "https://real.example",
  });

  assert.equal(fallbacks.length, 3);
  assert.deepEqual(
    fallbacks.map((f) => f.title),
    ["Tender 1", "Tender 2", "Tender 3"],
  );
});

test("preserves other candidate fields (description, fitScorePercent, tags) on the fallback", () => {
  const dropped = [
    {
      title: "Dropped tender",
      sourceUrl: "https://fake.example/1",
      description: "A tender description",
      fitScorePercent: 65,
      tags: ["construction"],
    },
  ];
  const fallbacks = buildWebsiteFallbackCandidates(dropped, {
    id: "src-1",
    website: "https://real.example",
  });

  assert.equal(fallbacks[0].description, "A tender description");
  assert.equal(fallbacks[0].fitScorePercent, 65);
  assert.deepEqual(fallbacks[0].tags, ["construction"]);
});

// --- pickUnambiguousGroundedFallback -------------------------------------

test("returns null when there are no same-domain grounded URLs", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = ["https://other-domain.example/page"];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, groundedUrls, {
      website: "https://real.example",
    }),
    null,
  );
});

test("returns the single same-domain grounded URL when exactly one candidate is dropped and exactly one grounded URL matches the domain", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = [
    "https://real.example/tender/actual-page",
    "https://other-domain.example/unrelated",
  ];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, groundedUrls, {
      website: "https://real.example",
    }),
    "https://real.example/tender/actual-page",
  );
});

test("returns null when multiple same-domain grounded URLs exist (ambiguous — never guesses)", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = [
    "https://real.example/tender/page-a",
    "https://real.example/tender/page-b",
  ];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, groundedUrls, {
      website: "https://real.example",
    }),
    null,
  );
});

test("returns null when there is exactly one same-domain grounded URL but more than one dropped candidate (never attaches the same URL to multiple candidates)", () => {
  const dropped = [
    { title: "Dropped tender 1", sourceUrl: "https://fake.example/1" },
    { title: "Dropped tender 2", sourceUrl: "https://fake.example/2" },
  ];
  const groundedUrls = ["https://real.example/tender/actual-page"];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, groundedUrls, {
      website: "https://real.example",
    }),
    null,
  );
});

test("matches the domain ignoring a leading www.", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = ["https://www.real.example/tender/actual-page"];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, groundedUrls, {
      website: "https://real.example",
    }),
    "https://www.real.example/tender/actual-page",
  );
});

test("returns null when groundedUrls is empty", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  assert.equal(
    pickUnambiguousGroundedFallback(dropped, [], { website: "https://real.example" }),
    null,
  );
});

// --- buildWebsiteFallbackCandidates + groundedUrls integration ----------

test("prefers the unambiguous grounded same-domain URL over the bare homepage", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = ["https://real.example/tender/actual-page"];
  const fallbacks = buildWebsiteFallbackCandidates(
    dropped,
    { id: "src-1", website: "https://real.example" },
    groundedUrls,
  );

  assert.equal(fallbacks.length, 1);
  assert.equal(fallbacks[0].sourceUrl, "https://real.example/tender/actual-page");
  assert.equal(fallbacks[0].sourceUrlIsFallback, true);
});

test("falls back to the bare homepage when the grounded-URL match is ambiguous", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = [
    "https://real.example/tender/page-a",
    "https://real.example/tender/page-b",
  ];
  const fallbacks = buildWebsiteFallbackCandidates(
    dropped,
    { id: "src-1", website: "https://real.example" },
    groundedUrls,
  );

  assert.equal(fallbacks[0].sourceUrl, "https://real.example");
});

test("still returns [] when source.website is unset, even with groundedUrls available", () => {
  const dropped = [{ title: "Dropped tender", sourceUrl: "https://fake.example/1" }];
  const groundedUrls = ["https://real.example/tender/actual-page"];
  assert.deepEqual(
    buildWebsiteFallbackCandidates(dropped, { id: "src-1" }, groundedUrls),
    [],
  );
});

// --- enforceSameDomainWhenWebsiteKnown ------------------------------------

test("no-op (kept unchanged, nothing demoted) when source.website is unset", () => {
  const kept = [{ title: "Tender", sourceUrl: "https://ke.usembassy.gov/rfq-real" }];
  const result = enforceSameDomainWhenWebsiteKnown(kept, { id: "src-1" });

  assert.deepEqual(result.kept, kept);
  assert.deepEqual(result.demoted, []);
});

test("no-op when there are no kept candidates", () => {
  const result = enforceSameDomainWhenWebsiteKnown([], {
    id: "src-1",
    website: "https://ke.usembassy.gov",
  });

  assert.deepEqual(result.kept, []);
  assert.deepEqual(result.demoted, []);
});

test("keeps a candidate whose sourceUrl is on the same domain as source.website", () => {
  const kept = [
    { title: "Real tender", sourceUrl: "https://ke.usembassy.gov/rfq-real" },
  ];
  const result = enforceSameDomainWhenWebsiteKnown(kept, {
    id: "src-1",
    website: "https://ke.usembassy.gov/tag/commercial-opportunities/",
  });

  assert.deepEqual(result.kept, kept);
  assert.deepEqual(result.demoted, []);
});

test(
  "demotes a candidate whose sourceUrl is on a DIFFERENT domain than source.website to a sourceUrlIsFallback pointing at the website — " +
    "the case where grounding was unavailable and a fabricated/off-domain URL would otherwise pass through untouched",
  () => {
    const kept = [
      {
        title: "Suspicious tender",
        sourceUrl: "https://some-other-domain.example/fabricated-path",
      },
    ];
    const result = enforceSameDomainWhenWebsiteKnown(kept, {
      id: "src-1",
      website: "https://ke.usembassy.gov/tag/commercial-opportunities/",
    });

    assert.deepEqual(result.kept, []);
    assert.equal(result.demoted.length, 1);
    assert.equal(
      result.demoted[0].sourceUrl,
      "https://ke.usembassy.gov/tag/commercial-opportunities/",
    );
    assert.equal(result.demoted[0].sourceUrlIsFallback, true);
    assert.equal(result.demoted[0].title, "Suspicious tender");
  },
);

test("prefers an unambiguous same-domain grounded URL over the bare homepage when demoting", () => {
  const kept = [
    {
      title: "Suspicious tender",
      sourceUrl: "https://some-other-domain.example/fabricated-path",
    },
  ];
  const groundedUrls = ["https://ke.usembassy.gov/rfq-real-grounded-page"];
  const result = enforceSameDomainWhenWebsiteKnown(
    kept,
    { id: "src-1", website: "https://ke.usembassy.gov" },
    groundedUrls,
  );

  assert.equal(
    result.demoted[0].sourceUrl,
    "https://ke.usembassy.gov/rfq-real-grounded-page",
  );
});

test("only demotes the off-domain candidate, keeps the same-domain one untouched", () => {
  const kept = [
    { title: "Real tender", sourceUrl: "https://ke.usembassy.gov/rfq-real" },
    {
      title: "Off-domain tender",
      sourceUrl: "https://some-other-domain.example/fabricated-path",
    },
  ];
  const result = enforceSameDomainWhenWebsiteKnown(kept, {
    id: "src-1",
    website: "https://ke.usembassy.gov",
  });

  assert.equal(result.kept.length, 1);
  assert.equal(result.kept[0].title, "Real tender");
  assert.equal(result.demoted.length, 1);
  assert.equal(result.demoted[0].title, "Off-domain tender");
});

// --- applyGeographyGate ---------------------------------------------------

test("drops a candidate with no recognizable Kenya/East-Africa mention (e.g. a Toronto/Canada tender)", () => {
  const candidates = [
    {
      title: "Construction RFP in Toronto, Canada",
      description: "",
      sourceUrl: "https://canadabuys.canada.ca/tender/1",
    },
  ];
  const result = applyGeographyGate(candidates);
  assert.equal(result.length, 0);
});

test("keeps a Kenya candidate and tags it geographyPriority: kenya", () => {
  const candidates = [
    {
      title: "Roof replacement at a facility in Nairobi, Kenya",
      description: "",
      sourceUrl: "https://ke.usembassy.gov/rfq-1",
    },
  ];
  const result = applyGeographyGate(candidates);
  assert.equal(result.length, 1);
  assert.equal(result[0].geographyPriority, "kenya");
});

test("keeps a Uganda candidate and tags it geographyPriority: eastAfrica", () => {
  const candidates = [
    {
      title: "Road works in Kampala, Uganda",
      description: "",
      sourceUrl: "https://example.org/tender/1",
    },
  ];
  const result = applyGeographyGate(candidates);
  assert.equal(result.length, 1);
  assert.equal(result[0].geographyPriority, "eastAfrica");
});

test("drops a Botswana/Nigeria candidate even with an otherwise-valid shape — the reported leakage case", () => {
  const candidates = [
    { title: "IT tender in Gaborone, Botswana", description: "", sourceUrl: "https://example.org/1" },
    { title: "Construction tender in Lagos, Nigeria", description: "", sourceUrl: "https://example.org/2" },
    { title: "Procurement notice for North Carolina state agency", description: "", sourceUrl: "https://example.org/3" },
  ];
  const result = applyGeographyGate(candidates);
  assert.equal(result.length, 0);
});

test("preserves other candidate fields while filtering/tagging", () => {
  const candidates = [
    {
      title: "Tender in Nairobi, Kenya",
      description: "",
      sourceUrl: "https://example.org/1",
      fitScorePercent: 82,
      tags: ["construction"],
    },
  ];
  const result = applyGeographyGate(candidates);
  assert.equal(result[0].fitScorePercent, 82);
  assert.deepEqual(result[0].tags, ["construction"]);
});

console.log(`\n${passed} test(s) passed`);
