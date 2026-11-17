/**
 * Buyer policy: the company does not pursue tenders from Kenyan or East
 * African public bodies — national government, counties, state
 * corporations (KETRACO, KPLC, ...), water companies, NG-CDF, public
 * universities/hospitals — because they are hard to win. EXCEPT when the
 * tender is donor-funded (World Bank, AfDB, EU, ...), which is kept even if
 * a government agency runs the procurement.
 *
 * Always kept: grants / programmes, embassy & foreign-mission work, donors,
 * UN agencies, NGOs, private companies, and anything a colleague added by
 * hand (a person already judged it worth a look).
 *
 * Excluded opportunities are archived (status "archived",
 * archivedReason "publicBuyer") — never deleted — and never pushed.
 */

/** Wording that marks a tender as donor-funded. */
const DONOR_PATTERNS = [
  /world bank/i,
  /\b(IDA|IBRD)\b/,
  /african development bank|\bAfDB\b/i,
  /european union|\bEU[- ]funded\b/i,
  /\b(KfW|GIZ|JICA|USAID|FCDO|DFID|IFAD|Sida|Danida|Norad|KOICA|AICS)\b/,
  /\bAFD\b|agence fran[cç]aise/i,
  /\b(UNDP|UNICEF|UNOPS|UNHCR|UNEP|FAO|WFP|WHO)\b/,
  /global fund|\bGAVI\b|green climate fund|\bGCF\b/i,
  /\b(financed|funded|co-financed|supported) by\b/i,
  /\b(credit|loan|grant) (no\.?|number)\b/i,
];

function isDonorFunded(text) {
  return DONOR_PATTERNS.some((p) => p.test(String(text || "")));
}

function opportunityText(o) {
  return [o.title, o.description, o.client, o.procuringOrganization, o.fitReasoning].filter(Boolean).join(" ");
}

/** Buyer types the AI may return; the first two are excluded unless donor-funded. */
const PUBLIC_BUYER_TYPES = new Set(["kenyaPublic", "eastAfricaPublic"]);

/**
 * Rule-based decision. Returns { exclude: boolean, reason } when the
 * answer is clear, or null when the buyer needs an AI check.
 */
function ruleDecision(o) {
  if (o.kind === "grant" || o.kind === "programme") return { exclude: false, reason: "grant/programme" };
  if (o.addedByUid) return { exclude: false, reason: "added by a colleague" };
  const tags = Array.isArray(o.tags) ? o.tags : [];
  if (tags.includes("watched-listing") || tags.includes("watched-call")) return { exclude: false, reason: "watched page" };
  if (/embassy|high commission|consulate/i.test(`${o.client || ""} ${o.procuringOrganization || ""}`)) {
    return { exclude: false, reason: "foreign mission" };
  }
  if (isDonorFunded(opportunityText(o))) return { exclude: false, reason: "donor-funded" };
  if (tags.includes("ppip")) return { exclude: true, reason: "Kenyan public procurement portal" };
  if (o.tenderSourceCategory === "countyGovernment") return { exclude: true, reason: "county government" };
  if (["developmentPartner", "unAgency", "ngo", "privateSector", "customEnterprise"].includes(o.tenderSourceCategory)) {
    return { exclude: false, reason: `buyer category ${o.tenderSourceCategory}` };
  }
  return null;
}

function buildBuyerPrompt(opportunities) {
  const lines = opportunities
    .map((o, i) => `${i} | ${o.title || ""} | buyer: ${o.client || o.procuringOrganization || "?"} | ${String(o.description || "").slice(0, 200)}`)
    .join("\n");
  return `For each tender below, identify who the BUYER (procuring entity) is and
whether the work is funded by an international donor.

buyerType must be one of:
- "kenyaPublic": Kenyan national government, ministries, state departments,
  county governments, state corporations / parastatals (e.g. KETRACO, KPLC,
  KenGen, KeNHA, Kenya Ports Authority), public water & sanitation companies,
  NG-CDF, public universities, colleges, schools and hospitals
- "eastAfricaPublic": the same kinds of public bodies in Uganda, Tanzania,
  Rwanda, Burundi, South Sudan, Ethiopia or Somalia
- "foreignGovernment": embassies, high commissions, foreign government agencies
- "developmentPartner": World Bank, AfDB, EU, GIZ, USAID, JICA and similar
- "unAgency", "ngo", "private", or "unknown"

donorFunded is true only when the tender states it is financed by a donor
(World Bank, AfDB, EU, a UN agency, a bilateral agency, a global fund).

Tenders (index | title | buyer | description):
${lines}

Return ONLY a JSON array: [{"index": number, "buyerType": string, "donorFunded": boolean}]
No commentary, no markdown fences.`;
}

/**
 * Decides a batch. [classify] is an async (prompt) -> parsed JSON function
 * (Gemini in production). Returns an array of { exclude, reason } aligned
 * with [opportunities]. When the AI fails, undecided ones are KEPT (never
 * hide a real opportunity because of an error).
 */
async function decideBuyers(opportunities, { classify }) {
  const decisions = opportunities.map(ruleDecision);
  const pending = decisions.map((d, i) => (d ? null : i)).filter((i) => i !== null);
  if (pending.length > 0) {
    let results = [];
    try {
      const parsed = await classify(buildBuyerPrompt(pending.map((i) => opportunities[i])));
      results = Array.isArray(parsed) ? parsed : [];
    } catch {
      results = [];
    }
    const byIndex = new Map(results.map((r) => [r?.index, r]));
    pending.forEach((originalIndex, promptIndex) => {
      const r = byIndex.get(promptIndex);
      if (!r) {
        decisions[originalIndex] = { exclude: false, reason: "buyer unclear — kept" };
        return;
      }
      const publicBuyer = PUBLIC_BUYER_TYPES.has(r.buyerType);
      decisions[originalIndex] = publicBuyer && r.donorFunded !== true
        ? { exclude: true, reason: `public buyer (${r.buyerType})` }
        : { exclude: false, reason: `buyer ${r.buyerType || "unknown"}${r.donorFunded ? ", donor-funded" : ""}` };
    });
  }
  return decisions;
}

/** The Firestore update that archives an excluded opportunity. */
function archiveUpdate(reason, timestamp) {
  return {
    status: "archived",
    archivedReason: "publicBuyer",
    archivedReasonDetail: reason,
    archivedAt: timestamp,
    updatedAt: timestamp,
  };
}

module.exports = { isDonorFunded, ruleDecision, decideBuyers, buildBuyerPrompt, archiveUpdate, PUBLIC_BUYER_TYPES };
