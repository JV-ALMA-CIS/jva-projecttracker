/**
 * Plain-Node assertion tests for pageTitleVerification.js. Run with:
 *   node functions/lib/pageTitleVerification.test.js
 */
const assert = require("node:assert/strict");
const { verifyPageMentionsTitle, textMentionsTitle, pageText } = require("./pageTitleVerification");

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

function fakeFetch({ status = 200, body = "", url = "https://final.example/page", throws = false } = {}) {
  return async () => {
    if (throws) throw new Error("network down");
    return { status, url, text: async () => body };
  };
}

const TITLE = "Africa Business Innovation Lab EXPLORE Open Call";

(async () => {
  console.log("pageTitleVerification.test.js");

  await test("textMentionsTitle matches the full title", () => {
    assert.equal(textMentionsTitle(pageText(`<h1>${TITLE}</h1>`), TITLE), true);
  });

  await test("textMentionsTitle matches when most distinctive words are present", () => {
    const text = pageText("<p>The ABIL Explore call from the Africa Business Innovation Lab is now accepting proposals.</p>");
    assert.equal(textMentionsTitle(text, TITLE), true);
  });

  await test("textMentionsTitle rejects a page about something else on the same site", () => {
    const text = pageText("<p>Commercial opportunities: roof replacement at the embassy compound.</p>");
    assert.equal(textMentionsTitle(text, TITLE), false);
  });

  await test("verified when the page loads and shows the title; returns the final URL", async () => {
    const r = await verifyPageMentionsTitle("https://news.example/abil", TITLE, {
      fetchImpl: fakeFetch({ body: `<html><h1>${TITLE}</h1></html>` }),
    });
    assert.deepEqual(r, { verified: true, finalUrl: "https://final.example/page" });
  });

  await test("not verified on 404", async () => {
    const r = await verifyPageMentionsTitle("https://x.example", TITLE, {
      fetchImpl: fakeFetch({ status: 404, body: TITLE }),
    });
    assert.equal(r.verified, false);
  });

  await test("not verified on a soft-404 page even if the title appears", async () => {
    const r = await verifyPageMentionsTitle("https://x.example", TITLE, {
      fetchImpl: fakeFetch({ body: `Page not found. ${TITLE}` }),
      looksLikeSoft404: (b) => b.includes("Page not found"),
    });
    assert.equal(r.verified, false);
  });

  await test("not verified when the request throws", async () => {
    const r = await verifyPageMentionsTitle("https://x.example", TITLE, { fetchImpl: fakeFetch({ throws: true }) });
    assert.equal(r.verified, false);
  });

  await test("not verified for a non-http URL or a missing title", async () => {
    assert.equal((await verifyPageMentionsTitle("ftp://x", TITLE)).verified, false);
    assert.equal((await verifyPageMentionsTitle("https://x.example", "")).verified, false);
  });

  console.log(`\n${passed} test(s) passed`);
})();
