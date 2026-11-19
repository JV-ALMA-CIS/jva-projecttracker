const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { fetchPageImpl } = require("./lib/fetchPage");

/**
 * Eligibility check for grants, calls, prizes and programmes: can JV ALMA CIS
 * actually apply? Funding calls often exclude for-profit companies, need a US
 * tax presence, an EU consortium, matching funds, or a minimum age/budget —
 * the AI fit score says nothing about that. Each grant gets:
 *
 *   eligibility:      "eligible" | "needsPartner" | "notEligible" | "unclear"
 *   eligibilityNote:  one line, e.g. "For-profit SMEs in Kenya eligible; 25% matching funds"
 *   fundingAmount:    e.g. "£100,000–£250,000" ("" if unknown)
 *   matchFunding:     e.g. "25% co-funding required" ("" if none/unknown)
 *   eligibilityCheckedAt
 *
 * "notEligible" grants get no push alert (matchNotifyScoreFor) and drop out
 * of the Monday "Funding open now" summary, but stay in the platform so
 * anyone can still see why.
 *
 * The company facts the check uses can be corrected without a deploy by
 * writing `facts` on the Firestore doc companySettings/eligibility.
 *
 * Shares admin initialization with index.js (do not call initializeApp).
 */

const ELIGIBILITY_VALUES = new Set(["eligible", "needsPartner", "notEligible", "unclear"]);
const GRANT_KINDS = new Set(["grant", "programme"]);

const DEFAULT_COMPANY_FACTS = `JV ALMA CIS (JVA):
- A privately owned, for-profit company (not an NGO, charity, university or public body).
- Registered and operating in Kenya (Nairobi); works across East Africa.
- Part of a group whose PARENT COMPANY IS REGISTERED IN ITALY (EU) and pays
  tax there. So JVA can apply to calls open only to EU / Italian-registered
  organisations through its Italian parent, and the parent can lead or join
  EU consortia with the Kenyan company as affiliate/implementing partner.
  The parent and the Kenyan company are ONE group — they do not count as two
  independent organisations for consortium rules.
- Holds a KRA tax compliance certificate, NCA contractor registrations
  (building, water works, mechanical engineering) and an ISO certificate.
- No legal entity, office or tax presence in the USA.
- NO experience in solar / photovoltaic / energy generation — calls that
  require solar or energy-generation track record are "notEligible".
- Business units: Construction, Facility Management, Embassy & Diplomatic
  Facilities, Information Technology (software, AI, GIS/satellite data,
  IoT), Agribusiness (digital agriculture platforms: Kilimo Mkononi,
  CoffeeCore), Oil & Gas Inspection Services, Human Resources.
- An established company with running products and paying clients (not an
  idea-stage start-up).`;

/** Company facts: Firestore override (companySettings/eligibility.facts) or the default. */
async function loadCompanyFacts(db) {
  try {
    const doc = await db.collection("companySettings").doc("eligibility").get();
    const facts = doc.exists ? doc.data().facts : null;
    if (typeof facts === "string" && facts.trim().length > 40) return facts.trim();
  } catch (e) {
    logger.warn(`grantEligibility: could not read company facts — using defaults: ${e.message}`);
  }
  return DEFAULT_COMPANY_FACTS;
}

/** Readable text of an HTML page (no scripts/styles/nav), trimmed. */
function pageText(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<(header|footer|nav)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&[a-z#0-9]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** The call's own page text (best effort — "" if it can't be fetched). */
async function fetchCallText(url, fetchImpl = fetchPageImpl) {
  if (!url || !/^https?:\/\//.test(url)) return "";
  try {
    const res = await fetchImpl(url, {
      redirect: "follow",
      headers: { "User-Agent": "Mozilla/5.0 (compatible; OpportunityTracker/1.0)" },
    });
    if (!res.ok) return "";
    return pageText(await res.text()).slice(0, 12000);
  } catch (_) {
    return "";
  }
}

function buildEligibilityPrompt({ title, description, client, deadline, pageText: text }, facts, now = new Date()) {
  return `Today is ${now.toISOString().slice(0, 10)}. Decide whether the company below
can apply to this funding opportunity, the way a careful grants officer would.

COMPANY
${facts}

OPPORTUNITY
Title: ${title || "(untitled)"}
Funder / organiser: ${client || "(unknown)"}
Deadline: ${deadline || "(not stated / rolling)"}
Description: ${description || "(none)"}
${text ? `\nText of the call's web page:\n"""\n${text}\n"""` : ""}

Rules:
- "eligible": the company can apply on its own — either the Kenyan company,
  or the Italian parent when the call wants an EU / Italian-registered
  applicant (then say "via Italian parent" in the note) — and no stated
  requirement rules it out.
- "needsPartner": it can take part only together with OTHER, independent
  organisations (e.g. Horizon Europe collaborative calls needing 3
  independent entities from 3 countries) or must apply through another body.
- "notEligible": a stated rule excludes it (e.g. non-profits/public bodies
  only, for-profits excluded, country not eligible, US tax presence
  required, start-ups under N years only and the company is older,
  individuals/students only).
- "unclear": the information available isn't enough to decide.
Do not guess rules that aren't stated.

Return ONLY a JSON object:
{
  "eligibility": "eligible" | "needsPartner" | "notEligible" | "unclear",
  "eligibilityNote": string (max 160 chars, plain words, e.g. "For-profit SMEs in Kenya eligible; needs 25% matching funds"),
  "fundingAmount": string (amount or range with currency as stated, e.g. "US$20,000" or "£100,000–£250,000"; "" if not stated),
  "matchFunding": string (co-funding / matching requirement, e.g. "25% matching funds"; "" if none stated)
}
No commentary, no markdown fences.`;
}

/** Validates the model's answer into the stored fields. Never throws. */
function parseEligibility(parsed) {
  const p = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  const str = (v, max) => (typeof v === "string" ? v.replace(/\s+/g, " ").trim().slice(0, max) : "");
  return {
    eligibility: ELIGIBILITY_VALUES.has(p.eligibility) ? p.eligibility : "unclear",
    eligibilityNote: str(p.eligibilityNote, 200),
    fundingAmount: str(p.fundingAmount, 80),
    matchFunding: str(p.matchFunding, 120),
  };
}

/** True when [opportunity] is a grant/programme that hasn't been checked yet. */
function needsEligibilityCheck(opportunity) {
  return (
    !!opportunity &&
    GRANT_KINDS.has(opportunity.kind) &&
    !opportunity.eligibilityCheckedAt &&
    !["archived", "dismissed", "won", "lost"].includes(opportunity.status)
  );
}

const toIso = (v) => {
  const d = v?.toDate ? v.toDate() : v ? new Date(v) : null;
  return d && !Number.isNaN(d.getTime()) ? d.toISOString().slice(0, 10) : null;
};

/**
 * Runs the check for one opportunity and returns the fields to store
 * (including eligibilityCheckedAt). [extract] is async (prompt) -> parsed
 * JSON. [text] skips fetching the page when the caller already has it.
 */
async function computeEligibility(opportunity, { extract, facts, text, fetchImpl, now = new Date() }) {
  const callText = text ?? (await fetchCallText(opportunity.sourceUrl, fetchImpl));
  const prompt = buildEligibilityPrompt(
    {
      title: opportunity.title,
      description: opportunity.description,
      client: opportunity.client || opportunity.procuringOrganization,
      deadline: toIso(opportunity.deadline),
      pageText: callText,
    },
    facts,
    now,
  );
  const result = parseEligibility(await extract(prompt));
  return { ...result, eligibilityCheckedAt: admin.firestore.Timestamp.fromDate(now) };
}

/** Checks one stored opportunity and writes the result onto it. Returns the fields. */
async function assessEligibility(ref, opportunity, { extract, facts, now }) {
  const fields = await computeEligibility(opportunity, { extract, facts, now });
  await ref.update(fields);
  logger.info(`grantEligibility: ${ref.id} → ${fields.eligibility} (${fields.eligibilityNote})`);
  return fields;
}

/**
 * Checks up to [limit] grants/programmes that haven't been checked yet
 * (existing ones from before this feature, or ones whose check failed).
 * One failure never stops the batch. Returns {checked, failed, remaining}.
 */
async function runEligibilityBackfill({ db, extract, limit = 15, now = new Date() }) {
  const snap = await db.collection("opportunities").where("kind", "in", ["grant", "programme"]).get();
  const pending = snap.docs.filter((d) => needsEligibilityCheck(d.data()));
  const facts = await loadCompanyFacts(db);
  let checked = 0;
  let failed = 0;
  for (const doc of pending.slice(0, limit)) {
    try {
      await assessEligibility(doc.ref, doc.data(), { extract, facts, now });
      checked += 1;
    } catch (e) {
      failed += 1;
      logger.error(`grantEligibility: backfill failed for ${doc.id}`, e);
    }
  }
  return { checked, failed, remaining: Math.max(0, pending.length - checked) };
}

module.exports = {
  DEFAULT_COMPANY_FACTS,
  GRANT_KINDS,
  loadCompanyFacts,
  fetchCallText,
  pageText,
  buildEligibilityPrompt,
  parseEligibility,
  needsEligibilityCheck,
  computeEligibility,
  assessEligibility,
  runEligibilityBackfill,
};
