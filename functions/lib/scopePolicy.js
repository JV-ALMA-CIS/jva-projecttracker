/**
 * Work JVA does not do, whatever the source (AI search, PPIP, EU portal,
 * World Bank feed, funder/page watchers): such opportunities are archived
 * on arrival (never deleted) and never alert. Checked against the TITLE
 * only, so e.g. a building tender that mentions solar lighting somewhere in
 * its description is kept.
 *
 * Decided by the user (2026-11-19): "JVA has no experience in solar".
 * Add a pattern here to rule out another line of work.
 */
const OUT_OF_SCOPE_PATTERNS = [
  { reason: "solar", pattern: /\bsolar\b/i },
  { reason: "solar", pattern: /\bphoto-?voltaic/i },
  { reason: "solar", pattern: /\bPV\b/ },
];

/** The out-of-scope reason for [opportunity] ("solar", ...), or null if in scope. */
function outOfScopeReason(opportunity) {
  const title = String(opportunity?.title || "");
  const hit = OUT_OF_SCOPE_PATTERNS.find((p) => p.pattern.test(title));
  return hit ? hit.reason : null;
}

/**
 * Firestore update that archives an out-of-scope opportunity — same fields
 * as the buyer policy's archiveUpdate (lib/buyerPolicy.js).
 */
function outOfScopeArchiveUpdate(reason, timestamp) {
  return {
    status: "archived",
    archivedReason: "outOfScope",
    archivedReasonDetail: reason,
    archivedAt: timestamp,
    updatedAt: timestamp,
  };
}

module.exports = { OUT_OF_SCOPE_PATTERNS, outOfScopeReason, outOfScopeArchiveUpdate };
