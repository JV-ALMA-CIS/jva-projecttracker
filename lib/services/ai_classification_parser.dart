import 'package:jva_projecttracker/models/opportunity.dart';

/// The validated, ready-to-apply result of an AI classification run — the
/// client-side counterpart to the Cloud Function's own `validateClassification`
/// (see `functions/index.js`). The Cloud Function already filters
/// hallucinated IDs and invalid enum values before writing to Firestore and
/// before returning its response, but this parser never assumes that: it
/// re-validates the raw payload independently, so a malformed or truncated
/// network response can never corrupt this screen's state. See ADR-003.
class AIClassificationResult {
  const AIClassificationResult({
    required this.classificationSummary,
    required this.industryIds,
    required this.technologyIds,
    required this.businessUnitIds,
    required this.productIds,
    required this.serviceIds,
    required this.capabilityIds,
    required this.experienceIds,
    required this.knowledgeArticleIds,
    required this.estimatedComplexity,
    required this.priority,
    required this.riskLevel,
    required this.confidenceScore,
    required this.classificationStatus,
    required this.aiReviewedAt,
  });

  final String classificationSummary;
  final List<String> industryIds;
  final List<String> technologyIds;
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> experienceIds;
  final List<String> knowledgeArticleIds;
  final EstimatedComplexity? estimatedComplexity;
  final OpportunityPriority? priority;
  final RiskLevel? riskLevel;
  final int? confidenceScore;
  final ClassificationStatus classificationStatus;
  final DateTime? aiReviewedAt;
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

int? _parseConfidenceScore(dynamic raw) {
  if (raw is! num) return null;
  final rounded = raw.round();
  if (rounded < 0) return 0;
  if (rounded > 100) return 100;
  return rounded;
}

/// Parses and validates the raw payload returned by the `classifyOpportunity`
/// Cloud Function. Returns `null` — rather than throwing — when the payload
/// is so malformed there's nothing safe to apply (not a map, or missing the
/// one field with no reasonable default: `classificationSummary`).
/// Everything else degrades gracefully: a missing/invalid enum becomes
/// `null` (or `ClassificationStatus.needsReview`, which already means
/// "AI couldn't confidently classify this"), and a missing/non-list ID
/// field becomes an empty list — a partial classification is still applied
/// rather than discarded outright.
AIClassificationResult? parseAIClassificationResponse(
  Map<String, dynamic>? raw,
) {
  if (raw == null) return null;

  final summary = raw['classificationSummary'];
  if (summary is! String || summary.isEmpty) return null;

  final aiReviewedAtRaw = raw['aiReviewedAt'];
  final aiReviewedAt = aiReviewedAtRaw is String
      ? DateTime.tryParse(aiReviewedAtRaw)
      : null;

  return AIClassificationResult(
    classificationSummary: summary,
    industryIds: _stringList(raw['industryIds']),
    technologyIds: _stringList(raw['technologyIds']),
    businessUnitIds: _stringList(raw['businessUnitIds']),
    productIds: _stringList(raw['productIds']),
    serviceIds: _stringList(raw['serviceIds']),
    capabilityIds: _stringList(raw['capabilityIds']),
    experienceIds: _stringList(raw['experienceIds']),
    knowledgeArticleIds: _stringList(raw['knowledgeArticleIds']),
    estimatedComplexity: _parseEnum(
      raw['estimatedComplexity'],
      EstimatedComplexity.values,
    ),
    priority: _parseEnum(raw['priority'], OpportunityPriority.values),
    riskLevel: _parseEnum(raw['riskLevel'], RiskLevel.values),
    confidenceScore: _parseConfidenceScore(raw['confidenceScore']),
    classificationStatus:
        _parseEnum(raw['classificationStatus'], ClassificationStatus.values) ??
        ClassificationStatus.needsReview,
    aiReviewedAt: aiReviewedAt,
  );
}
