/**
 * AI prompts list every opportunity / knowledge-graph entry with its
 * Firestore document ID (e.g. "[aB3xK9pQ2mZ7rT1vW8yL]") so the model can
 * return those IDs in structured `related*Ids` fields. Models sometimes also
 * copy the IDs into human-readable text (titles, reasoning, narratives),
 * which then shows staff a string of random letters instead of a tender
 * name. [humanizeIds] replaces each such ID in free text with the entry's
 * real name, or drops it when the name isn't known.
 *
 * Mirrored client-side by lib/utils/humanize_ids.dart (cleans text stored
 * before this existed) — keep the two in sync.
 */

// Firestore auto-IDs are 20 characters of [A-Za-z0-9]. Matched bracketed,
// parenthesised, or bare.
const ID_PATTERN = /\[([A-Za-z0-9]{20})\]|\(([A-Za-z0-9]{20})\)|\b([A-Za-z0-9]{20})\b/g;

/**
 * True when a 20-char token looks like a generated ID rather than a real
 * word — it contains a digit, or mixes upper and lower case. A genuine
 * 20-letter word in one case (rare) is left alone.
 */
function looksLikeGeneratedId(token) {
  return /\d/.test(token) || (/[a-z]/.test(token) && /[A-Z]/.test(token));
}

/**
 * Replaces generated IDs in [text] with `"Name"` from [namesById] (a Map),
 * or removes them when unknown, then tidies the spacing/punctuation left
 * behind. Non-string input is returned unchanged.
 */
function humanizeIds(text, namesById = new Map()) {
  if (typeof text !== "string" || text.length === 0) return text;

  const replaced = text.replace(ID_PATTERN, (match, bracketed, parenthesised, bare) => {
    const id = bracketed || parenthesised || bare;
    if (!looksLikeGeneratedId(id)) return match;
    const name = namesById.get(id);
    return name ? `"${name}"` : "";
  });

  return replaced
    .replace(/\(\s*\)|\[\s*\]/g, "")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\s+([.,;:!?)])/g, "$1")
    .replace(/\(\s+/g, "(")
    .trim();
}

/**
 * Reads the `[ID] Name` pairs a prompt was built with, so IDs the model
 * echoes back can be replaced by the same names. Handles the three line
 * shapes the prompt builders use:
 *   "- [id] Name - summary"        (knowledge graph: name before " - ")
 *   "- [id] Title | status: ..."   (opportunity portfolio: before " | ")
 *   "[id] \"Title\" ..."           (proposals: the quoted title)
 */
function namesFromPrompt(prompt) {
  const names = new Map();
  if (typeof prompt !== "string") return names;
  for (const m of prompt.matchAll(/\[([A-Za-z0-9]{20})\][ \t]*([^\n]*)/g)) {
    const [, id, rest] = m;
    if (!looksLikeGeneratedId(id)) continue;
    let name;
    const quoted = rest.match(/^"([^"]+)"/);
    if (quoted) name = quoted[1];
    else if (rest.includes(" | ")) name = rest.split(" | ")[0];
    else name = rest.split(" - ")[0];
    name = (name || "").trim();
    if (name) names.set(id, name);
  }
  return names;
}

/** True for keys holding machine references (`opportunityId`, `relatedProductIds`, ...). */
function isIdKey(key) {
  return typeof key === "string" && /(Id|Ids|ID|IDs)$/.test(key);
}

/**
 * Applies [humanizeIds] to every human-readable string inside [value]
 * (objects/arrays walked recursively), leaving `...Id` / `...Ids` fields —
 * the structured references — untouched.
 */
function humanizeDeep(value, namesById, key = null) {
  if (isIdKey(key)) return value;
  if (typeof value === "string") return humanizeIds(value, namesById);
  if (Array.isArray(value)) return value.map((v) => humanizeDeep(v, namesById, null));
  if (value && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype) {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = humanizeDeep(v, namesById, k);
    return out;
  }
  return value;
}

module.exports = { humanizeIds, looksLikeGeneratedId, namesFromPrompt, humanizeDeep, isIdKey };
