/**
 * Plain-Node assertion tests for opportunityRelevance.js — same convention as
 * businessUnitMatching.test.js. Run with:
 *   node functions/opportunityRelevance.test.js
 */
const assert = require("node:assert/strict");
const {
  isRelevantCandidate,
  isAllowedCountry,
  isAllowedGrantCandidate,
  classifyGeographyPriority,
  GEOGRAPHY_PRIORITY_RANK,
} = require("./opportunityRelevance");

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

console.log("opportunityRelevance.test.js");

// --- isRelevantCandidate ----------------------------------------------

test("isRelevantCandidate true for a normal tender candidate", () => {
  assert.equal(
    isRelevantCandidate({
      title: "Construction of Regional Office",
      description: "Civil works tender for a new regional office building.",
      sourceUrl: "https://example.org/tender/1",
    }),
    true,
  );
});

test("isRelevantCandidate false when title is missing", () => {
  assert.equal(
    isRelevantCandidate({ sourceUrl: "https://example.org/tender/1" }),
    false,
  );
});

test("isRelevantCandidate false when sourceUrl is missing", () => {
  assert.equal(isRelevantCandidate({ title: "Some tender" }), false);
});

test("isRelevantCandidate false for an expired deadline", () => {
  assert.equal(
    isRelevantCandidate(
      {
        title: "Construction tender",
        sourceUrl: "https://example.org/tender/1",
        deadline: "2020-01-01",
      },
      { now: new Date("2026-01-01") },
    ),
    false,
  );
});

test("isRelevantCandidate true for a future deadline", () => {
  assert.equal(
    isRelevantCandidate(
      {
        title: "Construction tender",
        sourceUrl: "https://example.org/tender/1",
        deadline: "2027-01-01",
      },
      { now: new Date("2026-01-01") },
    ),
    true,
  );
});

test("isRelevantCandidate true when deadline is an unparseable string (never guessed as expired)", () => {
  assert.equal(
    isRelevantCandidate({
      title: "Construction tender",
      sourceUrl: "https://example.org/tender/1",
      deadline: "not a date",
    }),
    true,
  );
});

test("isRelevantCandidate false for a job vacancy posting", () => {
  assert.equal(
    isRelevantCandidate({
      title: "Job Vacancy: Site Engineer",
      description: "We are hiring a site engineer for our Nairobi office.",
      sourceUrl: "https://example.org/careers/1",
    }),
    false,
  );
});

test("isRelevantCandidate false for a scholarship announcement", () => {
  assert.equal(
    isRelevantCandidate({
      title: "2026 Scholarship Applications Now Open",
      sourceUrl: "https://example.org/scholarships/1",
    }),
    false,
  );
});

test("isRelevantCandidate false for a conference/webinar announcement", () => {
  assert.equal(
    isRelevantCandidate({
      title: "Register for our upcoming webinar on climate finance",
      sourceUrl: "https://example.org/events/1",
    }),
    false,
  );
});

test("isRelevantCandidate false for a tender whose title contains the deny-listed word 'workshop'", () => {
  // A known false-positive risk of the deny-list approach: a legitimate
  // "supply of workshop equipment" tender is still filtered because the
  // word "workshop" matches the events/announcements pattern. Documented
  // here as a known trade-off rather than silently accepted.
  assert.equal(
    isRelevantCandidate({
      title: "Supply of Workshop Equipment for Vocational Training Center",
      description: "Tender for supply and installation of workshop tools.",
      sourceUrl: "https://example.org/tender/2",
    }),
    false,
  );
});

// --- isAllowedCountry (hard geography filter) ----------------------------

for (const [country, sample] of [
  ["Kenya", { title: "Construction of offices in Nairobi", description: "" }],
  ["Uganda", { title: "Road rehabilitation in Kampala, Uganda", description: "" }],
  ["Tanzania", { title: "Water supply project in Dar es Salaam, Tanzania", description: "" }],
  ["Rwanda", { title: "IT systems upgrade in Kigali, Rwanda", description: "" }],
  ["Burundi", { title: "Construction tender in Bujumbura, Burundi", description: "" }],
]) {
  test(`isAllowedCountry true for a ${country} opportunity`, () => {
    assert.equal(isAllowedCountry(sample), true);
  });
}

for (const [place, sample] of [
  ["Botswana", { title: "IT tender for a government agency in Gaborone, Botswana", description: "" }],
  ["Toronto", { title: "Construction RFP in Toronto, Canada", description: "" }],
  ["North Carolina", { title: "Procurement notice for North Carolina state agency", description: "" }],
  ["Nigeria", { title: "IT systems upgrade for a Lagos, Nigeria agency", description: "" }],
  ["South Africa", { title: "Facilities tender in Johannesburg, South Africa", description: "" }],
  ["a global/no-region opportunity", { title: "Global software modernization RFP", description: "Open to vendors worldwide." }],
]) {
  test(`isAllowedCountry false for ${place} even with no other disqualifier`, () => {
    assert.equal(isAllowedCountry(sample), false);
  });
}

test("isAllowedCountry discards a 90%+ fit score from outside the allow-list — geography check is independent of fitScorePercent", () => {
  assert.equal(
    isAllowedCountry({
      title: "High-value IT tender in Gaborone, Botswana",
      description: "",
      fitScorePercent: 95,
    }),
    false,
  );
});

test("isAllowedCountry checks the client field too, not just title/description", () => {
  assert.equal(
    isAllowedCountry({
      title: "Generic tender",
      description: "",
      client: "Government of Rwanda",
    }),
    true,
  );
});

test("isAllowedCountry is case-insensitive", () => {
  assert.equal(
    isAllowedCountry({ title: "TENDER IN NAIROBI, KENYA", description: "" }),
    true,
  );
});

// --- classifyGeographyPriority ------------------------------------------

test("classifyGeographyPriority returns kenya for a Nairobi-based tender", () => {
  assert.equal(
    classifyGeographyPriority({
      title: "Construction of offices in Nairobi",
      description: "",
      client: "County Government",
    }),
    "kenya",
  );
});

test("classifyGeographyPriority returns eastAfrica for a Uganda tender with no Kenya mention", () => {
  assert.equal(
    classifyGeographyPriority({
      title: "Road rehabilitation in Kampala, Uganda",
      description: "",
    }),
    "eastAfrica",
  );
});

test("classifyGeographyPriority returns africa for a Nigeria tender", () => {
  assert.equal(
    classifyGeographyPriority({
      title: "IT systems upgrade for a Lagos, Nigeria agency",
      description: "",
    }),
    "africa",
  );
});

test("classifyGeographyPriority returns internationalStrategic when no region matches", () => {
  assert.equal(
    classifyGeographyPriority({
      title: "Global software modernization RFP",
      description: "Open to vendors worldwide.",
    }),
    "internationalStrategic",
  );
});

test("classifyGeographyPriority prefers kenya over africa when both are mentioned", () => {
  assert.equal(
    classifyGeographyPriority({
      title: "Regional Africa initiative — Kenya pilot phase",
      description: "",
    }),
    "kenya",
  );
});

test("GEOGRAPHY_PRIORITY_RANK orders kenya before eastAfrica before africa before internationalStrategic", () => {
  assert.ok(GEOGRAPHY_PRIORITY_RANK.kenya < GEOGRAPHY_PRIORITY_RANK.eastAfrica);
  assert.ok(GEOGRAPHY_PRIORITY_RANK.eastAfrica < GEOGRAPHY_PRIORITY_RANK.africa);
  assert.ok(
    GEOGRAPHY_PRIORITY_RANK.africa < GEOGRAPHY_PRIORITY_RANK.internationalStrategic,
  );
});

// --- grants: isAllowedGrantCandidate / titleOnly ------------------------

const abil = {
  title: "ABIL EXPLORE Kenya Open Call",
  description: "ESA and Kenya Space Agency fund Earth Observation innovation by Kenyan start-ups and SMEs.",
  sourceUrl: "https://abil.ksa.go.ke/",
};

test("isAllowedGrantCandidate allows a call that names Kenya (ABIL EXPLORE)", () => {
  assert.equal(isAllowedGrantCandidate(abil), true);
});

test("isAllowedGrantCandidate allows a call open to African applicants when the model confirms Kenyan eligibility", () => {
  assert.equal(
    isAllowedGrantCandidate({
      title: "Climate Innovation Fund 2026",
      description: "Grants for start-ups across Africa building climate solutions.",
      kenyaEligible: true,
      eligibility: "Registered SMEs in any African country",
    }),
    true,
  );
});

test("isAllowedGrantCandidate allows a third-country-open call when the model confirms Kenyan eligibility", () => {
  assert.equal(
    isAllowedGrantCandidate({
      title: "EIC Pathfinder Open",
      description: "Breakthrough technology research.",
      kenyaEligible: true,
      eligibility: "Consortia may include entities from third countries",
    }),
    true,
  );
});

test("isAllowedGrantCandidate rejects an open-sounding call the model did not confirm as Kenya-eligible", () => {
  assert.equal(
    isAllowedGrantCandidate({
      title: "Climate Innovation Fund 2026",
      description: "Grants for start-ups across Africa.",
      kenyaEligible: false,
    }),
    false,
  );
});

test("isAllowedGrantCandidate never trusts kenyaEligible alone without supporting wording", () => {
  assert.equal(
    isAllowedGrantCandidate({
      title: "Regional SME Digitalisation Grant",
      description: "Support for SMEs in Bavaria.",
      kenyaEligible: true,
      eligibility: "SMEs registered in Bavaria",
    }),
    false,
  );
});

test("isRelevantCandidate titleOnly ignores 'workshop' in a grant description", () => {
  const grant = { ...abil, description: "Shortlisted applicants attend a kick-off workshop in Nairobi." };
  assert.equal(isRelevantCandidate(grant), false);
  assert.equal(isRelevantCandidate(grant, { titleOnly: true }), true);
});

test("isRelevantCandidate titleOnly still rejects a scholarship by its title", () => {
  assert.equal(
    isRelevantCandidate({ title: "Mastercard Foundation Scholarship 2026", sourceUrl: "https://x.org" }, { titleOnly: true }),
    false,
  );
});

console.log(`\n${passed} test(s) passed`);
