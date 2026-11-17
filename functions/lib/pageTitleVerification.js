/**
 * Second chance for AI-search candidates whose `sourceUrl` didn't exactly
 * match a page Google Search grounding retrieved (see
 * groundedUrlValidation.js). Grant calls and many tenders are found through
 * news posts and listing sites, so the model's link often differs from the
 * grounded URL even when the call is real — the exact-match check alone was
 * discarding every grant.
 *
 * Instead of trusting the domain (the old ke.usembassy.gov regression: a
 * real domain with an invented path), this opens the page and keeps the
 * candidate only if the page loads, isn't a soft-404 / block page, and
 * actually shows the candidate's title. An invented URL either fails to
 * load or lands on a page that doesn't contain the title.
 */

const STOPWORDS = new Set([
  "the", "and", "for", "with", "from", "into", "this", "that", "call", "calls",
  "open", "tender", "tenders", "grant", "grants", "proposal", "proposals",
  "supply", "provision", "services", "service", "request", "invitation",
  "notice", "programme", "program", "2024", "2025", "2026", "2027", "2028",
]);

/** Lower-cases, strips HTML tags/entities, collapses whitespace. */
function pageText(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&[a-z#0-9]+;/gi, " ")
    .toLowerCase()
    .replace(/\s+/g, " ");
}

/** The distinctive words of a title (>= 4 letters, not boilerplate). */
function significantWords(title) {
  return [
    ...new Set(
      String(title)
        .toLowerCase()
        .split(/[^a-z0-9]+/)
        .filter((w) => w.length >= 4 && !STOPWORDS.has(w)),
    ),
  ];
}

/**
 * True when [text] (already normalised by [pageText]) shows [title]: either
 * the whole title, or at least 60% of its distinctive words (minimum 2).
 */
function textMentionsTitle(text, title) {
  const normalizedTitle = String(title).toLowerCase().replace(/\s+/g, " ").trim();
  if (normalizedTitle.length >= 12 && text.includes(normalizedTitle)) return true;
  const words = significantWords(title);
  if (words.length < 2) return false;
  const found = words.filter((w) => text.includes(w)).length;
  return found >= 2 && found / words.length >= 0.6;
}

/**
 * Opens [url] and returns `{ verified, finalUrl }` — verified only if the
 * page loads (status < 400), isn't a soft-404/block page ([looksLikeSoft404]
 * is injected so this module doesn't depend on the connector), and shows
 * [title]. Never throws.
 */
async function verifyPageMentionsTitle(
  url,
  title,
  { fetchImpl = fetch, looksLikeSoft404 = () => false, timeoutMs = 8000 } = {},
) {
  if (typeof url !== "string" || !/^https?:\/\//i.test(url) || !title) {
    return { verified: false, finalUrl: null };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchImpl(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: { "User-Agent": "Mozilla/5.0 (compatible; OpportunityTracker/1.0)" },
    });
    if (!res || res.status >= 400) return { verified: false, finalUrl: null };
    const body = await res.text();
    if (looksLikeSoft404(body)) return { verified: false, finalUrl: null };
    if (!textMentionsTitle(pageText(body), title)) return { verified: false, finalUrl: null };
    return { verified: true, finalUrl: res.url || url };
  } catch {
    return { verified: false, finalUrl: null };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { verifyPageMentionsTitle, textMentionsTitle, pageText, significantWords };
