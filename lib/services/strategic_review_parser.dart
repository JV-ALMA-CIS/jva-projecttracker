import 'package:jva_projecttracker/models/opportunity.dart';

/// The validated, ready-to-apply result of an AI strategic review run — the
/// client-side counterpart to the Cloud Function's own
/// `validateStrategicReview` (see `functions/index.js`). Mirrors
/// `MatchAnalysisResult`/`parseMatchAnalysisResponse` from Milestone 3.4
/// exactly (see ADR-004, ADR-005): the Cloud Function already filters
/// hallucinated IDs and clamps/validates enums before writing to Firestore
/// and before returning its response, but this parser never assumes that —
/// it re-validates the raw payload independently, so a malformed or
/// truncated network response can never corrupt this screen's state.
class StrategicReviewResult {
  const StrategicReviewResult({
    required this.executiveRecommendation,
    required this.executiveSummary,
    required this.strategicStrengths,
    required this.strategicWeaknesses,
    required this.strategicRisks,
    required this.mitigationStrategies,
    required this.competitiveAdvantages,
    required this.missingRequirements,
    required this.strategicReviewBusinessUnitIds,
    required this.strategicReviewProductIds,
    required this.strategicReviewServiceIds,
    required this.strategicReviewCapabilityIds,
    required this.strategicReviewTechnologyIds,
    required this.strategicReviewExperienceIds,
    required this.strategicReviewKnowledgeArticleIds,
    required this.proposalPositioningStrategy,
    required this.nextRecommendedActions,
    required this.strategicReviewedAt,
  });

  final StrategicReviewRecommendation? executiveRecommendation;
  final String executiveSummary;
  final List<String> strategicStrengths;
  final List<String> strategicWeaknesses;
  final List<String> strategicRisks;
  final List<String> mitigationStrategies;
  final List<String> competitiveAdvantages;
  final List<String> missingRequirements;
  final List<String> strategicReviewBusinessUnitIds;
  final List<String> strategicReviewProductIds;
  final List<String> strategicReviewServiceIds;
  final List<String> strategicReviewCapabilityIds;
  final List<String> strategicReviewTechnologyIds;
  final List<String> strategicReviewExperienceIds;
  final List<String> strategicReviewKnowledgeArticleIds;
  final String? proposalPositioningStrategy;
  final List<String> nextRecommendedActions;
  final DateTime? strategicReviewedAt;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

T? _parseEnum<T extends Enum>(dynamic raw, List<T> values) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

/// Parses and validates the raw payload returned by the
/// `generateStrategicReview` Cloud Function. Returns `null` — rather than
/// throwing — when the payload is so malformed there's nothing safe to
/// apply (not a map, or missing the one field with no reasonable default:
/// `executiveSummary`). Everything else degrades gracefully: an invalid
/// `executiveRecommendation` becomes `null`, and a missing/non-list field
/// becomes an empty list — a partial review is still applied rather than
/// discarded outright.
StrategicReviewResult? parseStrategicReviewResponse(Map<String, dynamic>? raw) {
  if (raw == null) return null;

  final summary = raw['executiveSummary'];
  if (summary is! String || summary.isEmpty) return null;

  final strategicReviewedAtRaw = raw['strategicReviewedAt'];
  final strategicReviewedAt = strategicReviewedAtRaw is String
      ? DateTime.tryParse(strategicReviewedAtRaw)
      : null;

  return StrategicReviewResult(
    executiveRecommendation: _parseEnum(
      raw['executiveRecommendation'],
      StrategicReviewRecommendation.values,
    ),
    executiveSummary: summary,
    strategicStrengths: _stringList(raw['strategicStrengths']),
    strategicWeaknesses: _stringList(raw['strategicWeaknesses']),
    strategicRisks: _stringList(raw['strategicRisks']),
    mitigationStrategies: _stringList(raw['mitigationStrategies']),
    competitiveAdvantages: _stringList(raw['competitiveAdvantages']),
    missingRequirements: _stringList(raw['missingRequirements']),
    strategicReviewBusinessUnitIds: _stringList(
      raw['strategicReviewBusinessUnitIds'],
    ),
    strategicReviewProductIds: _stringList(raw['strategicReviewProductIds']),
    strategicReviewServiceIds: _stringList(raw['strategicReviewServiceIds']),
    strategicReviewCapabilityIds: _stringList(
      raw['strategicReviewCapabilityIds'],
    ),
    strategicReviewTechnologyIds: _stringList(
      raw['strategicReviewTechnologyIds'],
    ),
    strategicReviewExperienceIds: _stringList(
      raw['strategicReviewExperienceIds'],
    ),
    strategicReviewKnowledgeArticleIds: _stringList(
      raw['strategicReviewKnowledgeArticleIds'],
    ),
    proposalPositioningStrategy: raw['proposalPositioningStrategy'] as String?,
    nextRecommendedActions: _stringList(raw['nextRecommendedActions']),
    strategicReviewedAt: strategicReviewedAt,
  );
}
