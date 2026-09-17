/**
 * Plain-Node assertion tests for cleanupOffRegionOpportunities.js's filter
 * logic — same convention as businessUnitMatching.test.js. The onCall
 * handler itself (auth/admin gating, Firestore reads/batched deletes) isn't
 * exercised end-to-end here (no injection seam, same posture as every other
 * onCall Cloud Function in this codebase); this file instead verifies the
 * exact filtering rule the handler applies, using isAllowedCountry directly
 * — the same function the handler imports and calls unmodified.
 *
 * Run with:
 *   node functions/cleanupOffRegionOpportunities.test.js
 */
const assert = require("node:assert/strict");
const { isAllowedCountry } = require("./opportunityRelevance");

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

console.log("cleanupOffRegionOpportunities.test.js");

/**
 * Mirrors cleanupOffRegionOpportunities.js's own filter predicate exactly:
 * an opportunity doc is "off-region" (a cleanup candidate) when its status
 * is still open (discovered/reviewing, or unset) AND isAllowedCountry
 * rejects its title/description/client.
 */
function isCleanupCandidate(data) {
  const status = data.status;
  if (status && status !== "discovered" && status !== "reviewing") {
    return false;
  }
  return !isAllowedCountry({
    title: data.title,
    description: data.description,
    client: data.client,
  });
}

test("flags a discovered Toronto/Canada opportunity as a cleanup candidate", () => {
  assert.equal(
    isCleanupCandidate({
      title: "Construction RFP in Toronto, Canada",
      description: "",
      status: "discovered",
    }),
    true,
  );
});

test("flags a reviewing Botswana opportunity as a cleanup candidate", () => {
  assert.equal(
    isCleanupCandidate({
      title: "IT tender in Gaborone, Botswana",
      description: "",
      status: "reviewing",
    }),
    true,
  );
});

test("does NOT flag a Kenya opportunity", () => {
  assert.equal(
    isCleanupCandidate({
      title: "Roof replacement in Nairobi, Kenya",
      description: "",
      status: "discovered",
    }),
    false,
  );
});

test("does NOT flag a Uganda/Tanzania/Rwanda/Burundi opportunity", () => {
  for (const title of [
    "Road works in Kampala, Uganda",
    "Water project in Dar es Salaam, Tanzania",
    "IT upgrade in Kigali, Rwanda",
    "Construction tender in Bujumbura, Burundi",
  ]) {
    assert.equal(
      isCleanupCandidate({ title, description: "", status: "discovered" }),
      false,
      `expected ${title} to NOT be a cleanup candidate`,
    );
  }
});

test("does NOT touch an off-region opportunity that has moved past discovered/reviewing (applied/won/lost) — human work may be attached", () => {
  for (const status of ["applied", "won", "lost", "dismissed", "archived"]) {
    assert.equal(
      isCleanupCandidate({
        title: "Construction RFP in Toronto, Canada",
        description: "",
        status,
      }),
      false,
      `expected status "${status}" to be protected from cleanup`,
    );
  }
});

test("treats a missing status as still-open (discovered-equivalent) and flags it if off-region", () => {
  assert.equal(
    isCleanupCandidate({
      title: "Procurement notice for North Carolina state agency",
      description: "",
    }),
    true,
  );
});

test("checks the client field too, not just title/description", () => {
  assert.equal(
    isCleanupCandidate({
      title: "Generic tender",
      description: "",
      client: "State of North Carolina",
      status: "discovered",
    }),
    true,
  );
});

console.log(`\n${passed} test(s) passed`);
