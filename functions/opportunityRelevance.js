/**
 * Deterministic (no-AI-call) relevance and geography classification for
 * AI-search discovery candidates, run before a candidate is ever written to
 * Firestore by `runOpportunityDiscovery` (index.js). Split into its own
 * module (rather than living inline in index.js) so it can be required and
 * tested without triggering index.js's `admin.initializeApp()` — same
 * reasoning as businessUnitMatching.js.
 */

/**
 * Deny-list keyword scan (case-insensitive, against title+description) that
 * screens out AI-search results that aren't actually procurement
 * opportunities — the model is asked for "tenders, RFPs, or client
 * opportunities" but Google Search grounding sometimes still surfaces job
 * postings, scholarships, or event/announcement pages that merely mention a
 * company or sector. Same "deny-list keyword scan" pattern as
 * SOFT_404_PATTERNS/SOFT_BLOCK_PATTERNS in tenderSourceConnector.js — a
 * short, conservative phrase list rather than an AI call, so this stays a
 * cheap, deterministic pre-filter that runs before any candidate is written.
 */
const NON_TENDER_KEYWORD_PATTERNS = [
  /\bjob vacanc(y|ies)\b/i,
  /\bwe are hiring\b/i,
  /\brecruitment of\b/i,
  /\bscholarship(s)?\b/i,
  /\bfellowship(s)?\b/i,
  /\bcall for applications\b.*\b(students?|scholars?)\b/i,
  /\bwebinar\b/i,
  /\bconference\b/i,
  /\bworkshop\b/i,
  /\bsummit\b/i,
  /\bpress release\b/i,
  /\bannual report\b/i,
];

/**
 * Deterministic pre-filter run on every AI-search candidate before it's
 * written to Firestore — screens out expired deadlines, malformed records
 * (missing title/sourceUrl — same check already made inline by the caller,
 * kept here too so this function is a complete, independently testable
 * gate), and non-tender content (jobs, scholarships, events, announcements)
 * via NON_TENDER_KEYWORD_PATTERNS. Runs before the expensive AI Match
 * Analysis pass ever gets a chance to see the candidate, since a rejected
 * candidate is never written as an opportunity document at all.
 */
function isRelevantCandidate(candidate, { now = new Date() } = {}) {
  if (!candidate || !candidate.title || !candidate.sourceUrl) return false;

  if (candidate.deadline) {
    const deadline = new Date(candidate.deadline);
    if (!Number.isNaN(deadline.getTime()) && deadline < now) return false;
  }

  const haystack = `${candidate.title} ${candidate.description || ""}`;
  if (NON_TENDER_KEYWORD_PATTERNS.some((pattern) => pattern.test(haystack))) {
    return false;
  }

  return true;
}

/**
 * Keyword tables for `classifyGeographyPriority`/`isAllowedCountry`, checked
 * in priority order. ONLY these five countries are allowed at all — see
 * `isAllowedCountry`. `africa`/`internationalStrategic` keyword groups below
 * are kept only as classification labels for legacy/backfill purposes
 * (`classifyGeographyPriority` still needs to return *some* tier for any
 * candidate it's asked to classify), never as an "allowed" tier — no
 * candidate outside the five countries survives `isAllowedCountry`
 * regardless of what `classifyGeographyPriority` labels it.
 */
const GEOGRAPHY_KEYWORDS = {
  kenya: ["kenya", "nairobi", "mombasa", "kisumu", "nakuru", "eldoret", "kenyan"],
  eastAfrica: [
    "uganda", "tanzania", "rwanda", "burundi",
    "kampala", "dar es salaam", "dodoma", "zanzibar", "kigali", "bujumbura",
  ],
  africa: [
    "africa", "african union", "nigeria", "ghana", "egypt",
    "south africa", "senegal", "zambia", "malawi", "mozambique",
    "botswana", "namibia", "cote d'ivoire", "ivory coast",
    "south sudan", "ethiopia", "somalia", "addis ababa",
  ],
};

/**
 * HARD allow-list, per the "strict geo" requirement: an opportunity is only
 * ever notification/matching/write-eligible if its title/description/client
 * text names one of these five countries (or a well-known city/region within
 * one). A 90%+ fit score from anywhere else (Botswana, Toronto, North
 * Carolina, etc.) must still be discarded — this check runs independently of
 * fitScorePercent and before any AI matching. Deliberately does NOT fall
 * back to a generic "Africa" or "international" allowance the way
 * `classifyGeographyPriority`'s tiers used to imply — those tiers still
 * exist for ranking among allowed candidates (see [classifyGeographyPriority]),
 * but no longer make anything outside the five countries acceptable.
 *
 * A candidate that names NONE of the five countries (nor any of Kenya's own
 * cities, which is common for local tenders that never spell out "Kenya" by
 * name) is rejected — silence is not treated as "probably fine", it's
 * treated as "cannot confirm this is in-region" and dropped, matching the
 * brief's "everything else must be dropped" instruction.
 */
function isAllowedCountry(candidate) {
  const haystack = `${candidate?.title || ""} ${candidate?.description || ""} ${candidate?.client || ""}`.toLowerCase();
  return (
    GEOGRAPHY_KEYWORDS.kenya.some((k) => haystack.includes(k)) ||
    GEOGRAPHY_KEYWORDS.eastAfrica.some((k) => haystack.includes(k))
  );
}

/**
 * Classifies an (already allow-listed — see [isAllowedCountry]) candidate
 * into a ranking tier used only to order Kenya above the other four East
 * African countries within the write loop — NOT a relevance signal.
 * "kenya" > "eastAfrica". Checked against title/description/client text.
 * Callers must run [isAllowedCountry] first; this function no longer
 * classifies anything as broadly "africa"/"internationalStrategic" as
 * acceptable — those keyword groups remain only for the
 * `lib/models/opportunity.dart` GeographyPriority enum's existing
 * `africa`/`internationalStrategic` values (kept for legacy documents /
 * the enum's own back-compat, per "keep changes minimal"), which a fresh
 * candidate can still be labeled as if somehow asked to classify one that
 * failed `isAllowedCountry` — but no code path does that today, since every
 * caller runs `isAllowedCountry` first and drops before ever reaching this
 * function's africa/internationalStrategic branches in practice.
 */
function classifyGeographyPriority(candidate) {
  const haystack = `${candidate.title || ""} ${candidate.description || ""} ${candidate.client || ""}`.toLowerCase();

  if (GEOGRAPHY_KEYWORDS.kenya.some((k) => haystack.includes(k))) return "kenya";
  if (GEOGRAPHY_KEYWORDS.eastAfrica.some((k) => haystack.includes(k))) return "eastAfrica";
  if (GEOGRAPHY_KEYWORDS.africa.some((k) => haystack.includes(k))) return "africa";
  return "internationalStrategic";
}

/** Sort rank for classifyGeographyPriority's tiers — lower sorts first. */
const GEOGRAPHY_PRIORITY_RANK = {
  kenya: 0,
  eastAfrica: 1,
  africa: 2,
  internationalStrategic: 3,
};

module.exports = {
  isRelevantCandidate,
  isAllowedCountry,
  classifyGeographyPriority,
  GEOGRAPHY_PRIORITY_RANK,
};
