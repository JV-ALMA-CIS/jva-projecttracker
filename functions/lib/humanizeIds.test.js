/**
 * Plain-Node assertion tests for humanizeIds.js. Run with:
 *   node functions/lib/humanizeIds.test.js
 */
const assert = require("node:assert/strict");
const { humanizeIds } = require("./humanizeIds");

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

console.log("humanizeIds.test.js");

const ID = "aB3xK9pQ2mZ7rT1vW8yL";
const names = new Map([[ID, "KILIMO MKONONI digital extension tender"]]);

test("replaces a bracketed ID with the entry's name", () => {
  assert.equal(
    humanizeIds(`Fast-track [${ID}] before the deadline.`, names),
    'Fast-track "KILIMO MKONONI digital extension tender" before the deadline.',
  );
});

test("replaces a parenthesised and a bare ID", () => {
  assert.equal(humanizeIds(`The tender (${ID}) is strong.`, names), 'The tender "KILIMO MKONONI digital extension tender" is strong.');
  assert.equal(humanizeIds(`Opportunity ${ID} is strong.`, names), 'Opportunity "KILIMO MKONONI digital extension tender" is strong.');
});

test("removes an unknown ID cleanly, leaving no empty brackets or stray spaces", () => {
  assert.equal(
    humanizeIds("Pursue the tender (Zq8Lm2Nx4Pv6Rt9Sw1Ky) now.", names),
    "Pursue the tender now.",
  );
  assert.equal(
    humanizeIds("Opportunities Zq8Lm2Nx4Pv6Rt9Sw1Ky, Ab1Cd2Ef3Gh4Ij5Kl6Mn are stalled.", names),
    "Opportunities, are stalled.",
  );
});

test("leaves ordinary words and short codes alone", () => {
  const text = "KILIMOMKONONI tender ref KE-2026-0042 is open (EU funded).";
  assert.equal(humanizeIds(text, names), text);
});

test("does not touch a 20-letter single-case word", () => {
  const text = "internationalisation matters";
  assert.equal(humanizeIds(text, names), text);
});

test("returns non-strings unchanged", () => {
  assert.equal(humanizeIds(undefined, names), undefined);
  assert.equal(humanizeIds("", names), "");
});

const { namesFromPrompt, humanizeDeep } = require("./humanizeIds");
const { cleanedFields } = require("../cleanStoredAiText");

const BU = "Bu7x9Kq2LmN4pR6sT8vW";
const OPP = "Op3aB5cD7eF9gH1jK2mN";
const PROP = "Pr4qW6eR8tY0uI2oP4aS";
const PROMPT = [
  "Business Units:",
  `- [${BU}] Construction - Building and civil works`,
  "Opportunity portfolio:",
  `- [${OPP}] KILIMO MKONONI digital extension tender | status: discovered | fitScore: 82`,
  `- [${PROP}] "Coffee traceability proposal" — status: draft`,
].join("\n");

test("namesFromPrompt reads knowledge-graph, portfolio and quoted-title lines", () => {
  const names = namesFromPrompt(PROMPT);
  assert.equal(names.get(BU), "Construction");
  assert.equal(names.get(OPP), "KILIMO MKONONI digital extension tender");
  assert.equal(names.get(PROP), "Coffee traceability proposal");
});

test("humanizeDeep rewrites readable text but never touches ...Id(s) fields", () => {
  const names = namesFromPrompt(PROMPT);
  const out = humanizeDeep(
    {
      title: `Fast-track ${OPP}`,
      reasoning: `Strong fit for [${BU}].`,
      strengths: [`Track record in ${BU}`],
      relatedOpportunityIds: [OPP],
      opportunityId: OPP,
      confidenceScore: 80,
    },
    names,
  );
  assert.equal(out.title, 'Fast-track "KILIMO MKONONI digital extension tender"');
  assert.equal(out.reasoning, 'Strong fit for "Construction".');
  assert.deepEqual(out.strengths, ['Track record in "Construction"']);
  assert.deepEqual(out.relatedOpportunityIds, [OPP]);
  assert.equal(out.opportunityId, OPP);
  assert.equal(out.confidenceScore, 80);
});

test("cleanedFields returns only fields whose text actually changed", () => {
  const names = new Map([[OPP, "Kilimo tender"]]);
  assert.deepEqual(cleanedFields({ title: "Clean title", reasoning: `About ${OPP}` }, ["title", "reasoning"], names), {
    reasoning: 'About "Kilimo tender"',
  });
  assert.deepEqual(cleanedFields({ title: "Clean" }, ["title", "reasoning"], names), {});
});

console.log(`\n${passed} test(s) passed`);
