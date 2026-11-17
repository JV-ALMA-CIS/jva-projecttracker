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

console.log(`\n${passed} test(s) passed`);
