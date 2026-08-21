import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/certification_eligibility.dart';

/// Small, hand-maintained growth-keyword list — tender wording that signals
/// "adjacent to our core wheelhouse, worth a look" even without a strict
/// cert/BU match. Deliberately short and reviewed by hand rather than
/// config-driven (see brief's "keep list small and documented" — a v1
/// constants list, not a growth-interest admin UI). Matched case-
/// insensitively against title/description/tags.
///
/// Grouped by the real capability each term maps back to, so the list stays
/// traceable to an actual held cert or delivered project rather than
/// drifting into generic "tender words":
///  - NCA mechanical/water/electrical certs (held but not yet a dedicated
///    Business Unit) — the reason this list exists at all: certified but
///    unassigned sectors still need a way to surface in Explore.
///  - Sensitive-facility construction (embassy/ambassador residence work,
///    beyond the "Embassy & Diplomatic Facilities" BU's own soft keywords).
///  - Software delivered in-house/Play Store (agritech, edutech, HR-tech,
///    CMMS, construction management) — same sector-adjacency logic as the
///    certs above, applied to the IT side.
///  - Capacity-building / community development, per the Kapluk irrigation
///    programme with AICS — a delivery track distinct from a straight
///    construction tender.
const List<String> exploreGrowthKeywords = [
  // NCA mechanical/water/electrical works
  'water works',
  'mechanical',
  'electrical works',
  'borehole',
  'plumbing',
  'hvac',
  // Oil & gas / pipeline (adjacent to mechanical/water works)
  'oil',
  'gas',
  'pipeline',
  // Sensitive-facility construction
  'diplomatic',
  'chancery',
  'secure facility',
  // Software delivered in-house (agritech, edutech, HR-tech, CMMS, CMS)
  'agritech',
  'edutech',
  'e-learning',
  'hr management system',
  'hris',
  'cmms',
  'construction management system',
  'mobile app',
  // Capacity building / community development (e.g. Kapluk irrigation, AICS)
  'irrigation',
  'capacity building',
  'community development',
  'livelihoods',
];

/// How strongly [opportunity] matches the company's held certifications —
/// used only to rank the Explore tab, never to hide an opportunity.
enum ExploreCertMatch {
  /// No `requiredCertifications` on the opportunity, or none of them share
  /// a [CertificationType] with anything the company holds.
  none,

  /// At least one required certification shares a type with a held,
  /// currently-valid certification, but the grade/class doesn't clear the
  /// bar (e.g. tender wants NCA 5, company holds NCA 7 — reversed) — still
  /// Explore-worthy, surfaced as a gap warning rather than hidden.
  typeMatchWithGap,

  /// At least one required certification is fully satisfied by a held,
  /// currently-valid certification (see [computeEligibilityGaps]).
  fullMatch,
}

/// True when [opportunity] has at least one currently-valid held
/// certification sharing a [CertificationType] with any of its
/// `requiredCertifications` — the "prefer has type match even if grade gap"
/// rule from the brief. Independent of whether the grade actually clears
/// the bar; [classifyExploreCertMatch] separates that out for ranking.
bool hasCertTypeOverlap(
  Opportunity opportunity,
  List<Certification> heldCertifications, {
  required DateTime now,
}) {
  if (opportunity.requiredCertifications.isEmpty) return false;
  final validHeldTypes = heldCertifications
      .where((c) => isCertificationCurrentlyValid(c, now: now))
      .map((c) => c.type)
      .toSet();
  return opportunity.requiredCertifications.any(
    (r) => validHeldTypes.contains(r.type),
  );
}

/// Classifies how strongly [opportunity] matches held certifications, for
/// Explore's sort order (C1: cert match strength first). Reuses
/// [computeEligibilityGaps] as the single source of truth for what counts
/// as a satisfied requirement vs. a gap, so Explore and the Opportunity
/// Workspace's Eligibility section never disagree about eligibility.
ExploreCertMatch classifyExploreCertMatch(
  Opportunity opportunity,
  List<Certification> heldCertifications, {
  required DateTime now,
}) {
  if (opportunity.requiredCertifications.isEmpty) return ExploreCertMatch.none;

  final gaps = computeEligibilityGaps(
    requirements: opportunity.requiredCertifications,
    heldCertifications: heldCertifications,
    now: now,
  );
  final fullyMatched = gaps.length < opportunity.requiredCertifications.length;
  if (fullyMatched) return ExploreCertMatch.fullMatch;

  if (hasCertTypeOverlap(opportunity, heldCertifications, now: now)) {
    return ExploreCertMatch.typeMatchWithGap;
  }
  return ExploreCertMatch.none;
}

/// True when [opportunity]'s title/description/tags contain any
/// [exploreGrowthKeywords] entry, case-insensitively.
bool matchesExploreGrowthKeyword(Opportunity opportunity) {
  final haystack =
      '${opportunity.title} ${opportunity.description} ${opportunity.tags.join(' ')}'
          .toLowerCase();
  return exploreGrowthKeywords.any((k) => haystack.contains(k));
}

/// The pipeline stages Explore never shows. Two reasons an opportunity
/// drops out:
///  - Resolved: lost or fully completed — nothing left to explore.
///  - Actively pursued: `qualified` and every stage after it means someone
///    has already made a real go/no-go call and is working the opportunity
///    in Pipeline. Explore is a discovery lens for things NOT yet being
///    pursued — once qualified, an opportunity belongs to Pipeline alone,
///    so it doesn't also clutter Explore (e.g. a cert-matched embassy
///    tender the team is already actively bidding on).
///  `discovered`/`classified`/`reviewed` stay visible in Explore — those
///  are still just triage, nobody's committed yet.
const _excludedExploreStages = {
  OpportunityPipelineStage.qualified,
  OpportunityPipelineStage.approved,
  OpportunityPipelineStage.proposalStarted,
  OpportunityPipelineStage.proposalReady,
  OpportunityPipelineStage.submitted,
  OpportunityPipelineStage.evaluation,
  OpportunityPipelineStage.negotiation,
  OpportunityPipelineStage.awarded,
  OpportunityPipelineStage.lost,
  OpportunityPipelineStage.projectStarted,
  OpportunityPipelineStage.completed,
};

/// True when [opportunity] belongs on the Explore tab — see the module doc
/// and the B1 brief: cert-eligible (full or type-match-with-gap), OR
/// unassigned/thin-BU with real title/client text plus a growth-keyword
/// signal. Never gated on `experienceIds` — an opportunity with zero linked
/// Experience can still qualify purely on certification or growth
/// keywords, per "do not require Experience in a sector to show a
/// cert-matched tender." Membership here is independent of Pipeline's BU
/// filters — an opportunity can appear in both while it's still early-stage
/// (B3) — but drops out of Explore once it reaches `qualified` or later
/// (see [_excludedExploreStages]), so an opportunity already being actively
/// pursued in Pipeline doesn't also sit in Explore as if it were still an
/// undiscovered prospect.
bool isExploreCandidate(
  Opportunity opportunity,
  List<Certification> heldCertifications, {
  required DateTime now,
}) {
  if (_excludedExploreStages.contains(opportunity.pipelineStage)) {
    return false;
  }
  if (opportunity.title.trim().isEmpty) return false;

  final certMatch = classifyExploreCertMatch(
    opportunity,
    heldCertifications,
    now: now,
  );
  if (certMatch != ExploreCertMatch.none) return true;

  final hasMeaningfulText =
      opportunity.title.trim().isNotEmpty ||
      (opportunity.client ?? '').trim().isNotEmpty;
  if (hasMeaningfulText && matchesExploreGrowthKeyword(opportunity)) {
    return true;
  }

  return false;
}

/// Sort comparator for the Explore tab (C1): cert match strength first
/// (full match, then type-match-with-gap, then none), then
/// `fitScorePercent` descending, then soonest deadline (null deadlines
/// sort last — an unknown deadline is never treated as more urgent than a
/// known one).
int compareExploreCandidates(
  Opportunity a,
  Opportunity b,
  List<Certification> heldCertifications, {
  required DateTime now,
}) {
  final aCert = classifyExploreCertMatch(a, heldCertifications, now: now);
  final bCert = classifyExploreCertMatch(b, heldCertifications, now: now);
  final certCompare = bCert.index.compareTo(aCert.index);
  if (certCompare != 0) return certCompare;

  final fitCompare = b.fitScorePercent.compareTo(a.fitScorePercent);
  if (fitCompare != 0) return fitCompare;

  final aDeadline = a.deadline;
  final bDeadline = b.deadline;
  if (aDeadline == null && bDeadline == null) return 0;
  if (aDeadline == null) return 1;
  if (bDeadline == null) return -1;
  return aDeadline.compareTo(bDeadline);
}

/// Filters [opportunities] to Explore candidates and sorts them per
/// [compareExploreCandidates] — the one function the Explore tab calls,
/// mirroring `filterOpportunities`'s role for Pipeline.
List<Opportunity> exploreOpportunities(
  List<Opportunity> opportunities,
  List<Certification> heldCertifications, {
  required DateTime now,
}) {
  final candidates = opportunities
      .where((o) => isExploreCandidate(o, heldCertifications, now: now))
      .toList();
  candidates.sort(
    (a, b) => compareExploreCandidates(a, b, heldCertifications, now: now),
  );
  return candidates;
}
