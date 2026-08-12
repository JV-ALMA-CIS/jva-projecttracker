/**
 * Plain-Node assertion tests for businessUnitMatching.js — no Gemini/Firebase
 * involved, matching this project's other pure-mapping logic. Run with:
 *   node functions/businessUnitMatching.test.js
 * There is no test framework configured in functions/package.json yet, so
 * this uses only the standard library `assert` module rather than adding a
 * new dependency for a handful of pure-function tests.
 */
const assert = require("node:assert/strict");
const {
  normalizeName,
  slugify,
  resolveAlias,
  buildBusinessUnitCatalog,
  matchBusinessUnitName,
  matchBusinessUnitNames,
} = require("./businessUnitMatching");

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

console.log("businessUnitMatching.test.js");

test("normalizeName trims, lowercases, collapses whitespace", () => {
  assert.equal(normalizeName("  Construction   Works "), "construction works");
});

test("slugify strips punctuation and joins with hyphens", () => {
  assert.equal(slugify("Information Technology!"), "information-technology");
});

test("slugify falls back to 'entity' for an empty/symbols-only name", () => {
  assert.equal(slugify("!!!"), "entity");
  assert.equal(slugify(""), "entity");
});

const catalog = buildBusinessUnitCatalog([
  { id: "bu-1", name: "Construction", slug: "construction" },
  { id: "bu-2", name: "Information Technology", slug: "information-technology" },
  { id: "bu-3", name: "Agribusiness", slug: "agribusiness" },
  { id: "bu-4", name: "Facility Management", slug: "facility-management" },
  { id: "bu-5", name: "Human Resources", slug: "human-resources" },
]);

test("matchBusinessUnitName matches an exact name case-insensitively", () => {
  assert.equal(matchBusinessUnitName("construction", catalog), "bu-1");
  assert.equal(matchBusinessUnitName("CONSTRUCTION", catalog), "bu-1");
  assert.equal(matchBusinessUnitName("  Construction  ", catalog), "bu-1");
});

test("matchBusinessUnitName matches by slug when the name itself doesn't match", () => {
  assert.equal(
    matchBusinessUnitName("information-technology", catalog),
    "bu-2",
  );
});

test("matchBusinessUnitName returns null for a name with no exact match", () => {
  assert.equal(matchBusinessUnitName("Something Else Entirely", catalog), null);
  assert.equal(matchBusinessUnitName("Constructio", catalog), null);
});

test("resolveAlias maps a known abbreviation to its canonical name", () => {
  assert.equal(resolveAlias("FM"), "Facility Management");
  assert.equal(resolveAlias("it"), "Information Technology");
  assert.equal(resolveAlias("Agri"), "Agribusiness");
  assert.equal(resolveAlias("HR"), "Human Resources");
});

test("resolveAlias returns the input unchanged when it isn't a known alias", () => {
  assert.equal(resolveAlias("Construction"), "Construction");
  assert.equal(resolveAlias("Something Unrelated"), "Something Unrelated");
});

test("matchBusinessUnitName resolves Facility Management aliases", () => {
  for (const alias of [
    "facility management",
    "facilities management",
    "FM",
    "fm",
    "facility mgmt",
  ]) {
    assert.equal(
      matchBusinessUnitName(alias, catalog),
      "bu-4",
      `expected "${alias}" to resolve to Facility Management`,
    );
  }
});

test("matchBusinessUnitName resolves Information Technology aliases", () => {
  for (const alias of ["information technology", "IT", "ICT", "software", "digital"]) {
    assert.equal(
      matchBusinessUnitName(alias, catalog),
      "bu-2",
      `expected "${alias}" to resolve to Information Technology`,
    );
  }
});

test("matchBusinessUnitName resolves Agribusiness aliases", () => {
  for (const alias of ["agribusiness", "agriculture", "agri", "agritech"]) {
    assert.equal(
      matchBusinessUnitName(alias, catalog),
      "bu-3",
      `expected "${alias}" to resolve to Agribusiness`,
    );
  }
});

test("matchBusinessUnitName resolves Construction aliases", () => {
  for (const alias of ["construction", "civil works", "building works"]) {
    assert.equal(
      matchBusinessUnitName(alias, catalog),
      "bu-1",
      `expected "${alias}" to resolve to Construction`,
    );
  }
});

test("matchBusinessUnitName resolves Human Resources aliases", () => {
  for (const alias of ["human resources", "HR", "hrm"]) {
    assert.equal(
      matchBusinessUnitName(alias, catalog),
      "bu-5",
      `expected "${alias}" to resolve to Human Resources`,
    );
  }
});

test("an alias resolving to a canonical name absent from the catalog is still a non-match", () => {
  const smallCatalog = buildBusinessUnitCatalog([
    { id: "bu-1", name: "Construction", slug: "construction" },
  ]);
  assert.equal(matchBusinessUnitName("FM", smallCatalog), null);
});

test("matchBusinessUnitName returns null for an empty/blank name", () => {
  assert.equal(matchBusinessUnitName("", catalog), null);
  assert.equal(matchBusinessUnitName("   ", catalog), null);
});

test("matchBusinessUnitNames matches multiple names and de-duplicates", () => {
  const { ids, unmatched } = matchBusinessUnitNames(
    ["Construction", "Agribusiness", "Construction"],
    catalog,
  );
  assert.deepEqual(ids.sort(), ["bu-1", "bu-3"]);
  assert.deepEqual(unmatched, []);
});

test("matchBusinessUnitNames reports unmatched names without dropping them silently", () => {
  const { ids, unmatched } = matchBusinessUnitNames(
    ["Construction", "Marketing", "Made Up Unit"],
    catalog,
  );
  assert.deepEqual(ids, ["bu-1"]);
  assert.deepEqual(unmatched, ["Marketing", "Made Up Unit"]);
});

test("matchBusinessUnitNames never invents an id for a non-list input", () => {
  const { ids, unmatched } = matchBusinessUnitNames(null, catalog);
  assert.deepEqual(ids, []);
  assert.deepEqual(unmatched, []);
});

test("matchBusinessUnitNames ignores non-string entries", () => {
  const { ids, unmatched } = matchBusinessUnitNames(
    ["Construction", 42, null],
    catalog,
  );
  assert.deepEqual(ids, ["bu-1"]);
  assert.deepEqual(unmatched, []);
});

console.log(`${passed} test(s) passed`);
if (process.exitCode) {
  console.error("Some tests failed");
  process.exit(1);
}
