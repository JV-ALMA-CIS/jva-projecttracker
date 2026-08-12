/// The validated, ready-to-apply result of an AI match analysis run — the
/// client-side counterpart to the Cloud Function's own
/// `validateMatchAnalysis` (see `functions/index.js`). Mirrors
/// `AIClassificationResult`/`parseAIClassificationResponse` from Milestone
/// 3.3 exactly (see ADR-003, ADR-004): the Cloud Function already filters
/// hallucinated IDs and clamps scores before writing to Firestore and
/// before returning its response, but this parser never assumes that — it
/// re-validates the raw payload independently, so a malformed or truncated
/// network response can never corrupt this screen's state.
class MatchAnalysisResult {
  const MatchAnalysisResult({
    required this.overallMatchScore,
    required this.businessUnitScore,
    required this.productScore,
    required this.serviceScore,
    required this.capabilityScore,
    required this.technologyScore,
    required this.industryScore,
    required this.experienceScore,
    required this.knowledgeScore,
    required this.strategicRecommendation,
    required this.recommendedProductIds,
    required this.recommendedBusinessUnitIds,
    required this.recommendedExperienceIds,
    required this.recommendedKnowledgeArticleIds,
    required this.strengths,
    required this.gaps,
    required this.risks,
    required this.nextActions,
    required this.matchAnalyzedAt,
  });

  final int? overallMatchScore;
  final int? businessUnitScore;
  final int? productScore;
  final int? serviceScore;
  final int? capabilityScore;
  final int? technologyScore;
  final int? industryScore;
  final int? experienceScore;
  final int? knowledgeScore;
  final String strategicRecommendation;
  final List<String> recommendedProductIds;
  final List<String> recommendedBusinessUnitIds;
  final List<String> recommendedExperienceIds;
  final List<String> recommendedKnowledgeArticleIds;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> risks;
  final List<String> nextActions;
  final DateTime? matchAnalyzedAt;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

int? _parseScore(dynamic raw) {
  if (raw is! num) return null;
  final rounded = raw.round();
  if (rounded < 0) return 0;
  if (rounded > 100) return 100;
  return rounded;
}

/// Parses and validates the raw payload returned by the
/// `analyzeOpportunityMatch` Cloud Function. Returns `null` — rather than
/// throwing — when the payload is so malformed there's nothing safe to
/// apply (not a map, or missing the one field with no reasonable default:
/// `strategicRecommendation`). Everything else degrades gracefully: a
/// missing/out-of-range score becomes `null`, and a missing/non-list
/// field becomes an empty list — a partial analysis is still applied
/// rather than discarded outright.
MatchAnalysisResult? parseMatchAnalysisResponse(Map<String, dynamic>? raw) {
  if (raw == null) return null;

  final recommendation = raw['strategicRecommendation'];
  if (recommendation is! String || recommendation.isEmpty) return null;

  final matchAnalyzedAtRaw = raw['matchAnalyzedAt'];
  final matchAnalyzedAt = matchAnalyzedAtRaw is String
      ? DateTime.tryParse(matchAnalyzedAtRaw)
      : null;

  return MatchAnalysisResult(
    overallMatchScore: _parseScore(raw['overallMatchScore']),
    businessUnitScore: _parseScore(raw['businessUnitScore']),
    productScore: _parseScore(raw['productScore']),
    serviceScore: _parseScore(raw['serviceScore']),
    capabilityScore: _parseScore(raw['capabilityScore']),
    technologyScore: _parseScore(raw['technologyScore']),
    industryScore: _parseScore(raw['industryScore']),
    experienceScore: _parseScore(raw['experienceScore']),
    knowledgeScore: _parseScore(raw['knowledgeScore']),
    strategicRecommendation: recommendation,
    recommendedProductIds: _stringList(raw['recommendedProductIds']),
    recommendedBusinessUnitIds: _stringList(raw['recommendedBusinessUnitIds']),
    recommendedExperienceIds: _stringList(raw['recommendedExperienceIds']),
    recommendedKnowledgeArticleIds: _stringList(
      raw['recommendedKnowledgeArticleIds'],
    ),
    strengths: _stringList(raw['strengths']),
    gaps: _stringList(raw['gaps']),
    risks: _stringList(raw['risks']),
    nextActions: _stringList(raw['nextActions']),
    matchAnalyzedAt: matchAnalyzedAt,
  );
}
