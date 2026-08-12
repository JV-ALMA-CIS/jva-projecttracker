/**
 * Centralized Business Unit name/slug matching — the one place that maps a
 * plain-language name (from an AI response, never trusted as an ID) to a
 * real `businessUnits` document ID. Used by both `backfillOpportunityBusinessUnits`
 * and available for `classifyOpportunity` to reuse if it's ever changed to
 * return names instead of IDs. Matching is deliberately exact-only
 * (case-insensitive, trimmed, optionally slugified) — no fuzzy/partial
 * matching, so a near-miss name is honestly "no match" rather than a wrong
 * assignment.
 */

/** trim + lowercase, collapsing internal whitespace — used for name comparison. */
function normalizeName(name) {
  return String(name || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

/**
 * Abbreviations/synonyms a tender document or Gemini might use for a
 * Business Unit, mapped to the CANONICAL catalog name they mean — keyed by
 * `normalizeName()` output. This is a fixed, hand-maintained list, not a
 * fuzzy matcher: an alias here only ever resolves to a name that must
 * itself still exist in the live `businessUnits` catalog (see
 * `matchBusinessUnitName` — the canonical name is looked up there exactly
 * like any other candidate; if the BU with that name doesn't exist yet,
 * the alias still resolves to "no match", never a guess or a new BU).
 * Add new abbreviations here rather than teaching individual call sites
 * about them, so classification and bulk backfill never drift apart.
 */
const ALIASES = {
  // Facility Management
  fm: "Facility Management",
  "facility mgmt": "Facility Management",
  "facilities management": "Facility Management",
  "facilities mgmt": "Facility Management",
  // Information Technology
  it: "Information Technology",
  ict: "Information Technology",
  software: "Information Technology",
  digital: "Information Technology",
  "information technology": "Information Technology",
  // Agribusiness
  agri: "Agribusiness",
  agriculture: "Agribusiness",
  agritech: "Agribusiness",
  "agri-business": "Agribusiness",
  // Construction
  "civil works": "Construction",
  "building works": "Construction",
  // Human Resources
  hr: "Human Resources",
  hrm: "Human Resources",
  "human resource": "Human Resources",
  "human resource management": "Human Resources",
};

/**
 * Resolves [name] to the canonical catalog name it should be matched
 * against — the alias's target if [name] normalizes to a known alias,
 * else [name] unchanged. Pure lookup, no fuzzy matching: an alias entry
 * must match the *entire* normalized input, not a substring of it.
 */
function resolveAlias(name) {
  const normalized = normalizeName(name);
  return ALIASES[normalized] || name;
}

/** Same slugification as the Dart client's `_slugify` (project_extraction_review_screen.dart). */
function slugify(name) {
  const slug = String(name || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-");
  return slug || "entity";
}

/**
 * Builds a lookup catalog from a list of `{ id, name, slug }` Business Unit
 * records — pass this once per run, reuse across every opportunity being
 * matched, rather than rebuilding it per opportunity.
 */
function buildBusinessUnitCatalog(businessUnits) {
  const byName = new Map();
  const bySlug = new Map();
  for (const bu of businessUnits) {
    byName.set(normalizeName(bu.name), bu.id);
    if (bu.slug) bySlug.set(normalizeName(bu.slug), bu.id);
  }
  return { byName, bySlug };
}

/**
 * Matches one candidate name against the catalog: exact name match first
 * (after resolving a known abbreviation/alias to its canonical name — see
 * [ALIASES]), then exact slug match (covers a model returning a
 * slug-shaped name like "construction" against a BU named "Construction").
 * Returns `null` — never a guess — when nothing matches exactly, including
 * when an alias resolves to a canonical name that isn't actually in the
 * catalog yet (e.g. "FM" before "Facility Management" has been seeded).
 */
function matchBusinessUnitName(name, catalog) {
  const normalized = normalizeName(name);
  if (!normalized) return null;

  if (catalog.byName.has(normalized)) return catalog.byName.get(normalized);

  const resolved = resolveAlias(name);
  const resolvedNormalized = normalizeName(resolved);
  if (catalog.byName.has(resolvedNormalized)) {
    return catalog.byName.get(resolvedNormalized);
  }

  const slug = slugify(name);
  if (catalog.bySlug.has(normalized)) return catalog.bySlug.get(normalized);
  if (catalog.bySlug.has(slug)) return catalog.bySlug.get(slug);
  return null;
}

/**
 * Matches a list of candidate names against the catalog, returning the
 * de-duplicated list of matched IDs and the list of names that matched
 * nothing (for logging — never silently dropped without a trace).
 */
function matchBusinessUnitNames(names, catalog) {
  const ids = new Set();
  const unmatched = [];
  for (const name of Array.isArray(names) ? names : []) {
    const id = matchBusinessUnitName(name, catalog);
    if (id) {
      ids.add(id);
    } else if (typeof name === "string" && name.trim()) {
      unmatched.push(name.trim());
    }
  }
  return { ids: Array.from(ids), unmatched };
}

module.exports = {
  normalizeName,
  slugify,
  ALIASES,
  resolveAlias,
  buildBusinessUnitCatalog,
  matchBusinessUnitName,
  matchBusinessUnitNames,
};
