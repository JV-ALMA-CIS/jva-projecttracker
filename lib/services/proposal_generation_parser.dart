/// The validated, ready-to-apply result of an AI proposal-section
/// generation run — the client-side counterpart to the Cloud Function's own
/// `validateProposalSectionGeneration` (see `functions/index.js`). Mirrors
/// `StrategicReviewResult`/`parseStrategicReviewResponse` exactly (see
/// ADR-004/ADR-005): the Cloud Function already filters hallucinated IDs
/// and clamps confidence before writing to Firestore and before returning
/// its response, but this parser never assumes that — it re-validates the
/// raw payload independently.
class ProposalGenerationResult {
  const ProposalGenerationResult({
    required this.content,
    required this.confidenceScore,
    required this.sourceBusinessUnitIds,
    required this.sourceProductIds,
    required this.sourceServiceIds,
    required this.sourceCapabilityIds,
    required this.sourceTechnologyIds,
    required this.sourceIndustryIds,
    required this.sourceExperienceIds,
    required this.sourceKnowledgeArticleIds,
    required this.aiGeneratedAt,
  });

  final String content;
  final int? confidenceScore;
  final List<String> sourceBusinessUnitIds;
  final List<String> sourceProductIds;
  final List<String> sourceServiceIds;
  final List<String> sourceCapabilityIds;
  final List<String> sourceTechnologyIds;
  final List<String> sourceIndustryIds;
  final List<String> sourceExperienceIds;
  final List<String> sourceKnowledgeArticleIds;
  final DateTime? aiGeneratedAt;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

/// Parses and validates the raw payload returned by the
/// `generateProposalSection` Cloud Function. Returns `null` — rather than
/// throwing — when the payload is so malformed there's nothing safe to
/// apply (not a map, or missing the one field with no reasonable default:
/// `content`). Everything else degrades gracefully.
ProposalGenerationResult? parseProposalGenerationResponse(
  Map<String, dynamic>? raw,
) {
  if (raw == null) return null;

  final content = raw['content'];
  if (content is! String || content.isEmpty) return null;

  final generatedAtRaw = raw['aiGeneratedAt'];
  final aiGeneratedAt = generatedAtRaw is String
      ? DateTime.tryParse(generatedAtRaw)
      : null;

  final confidenceRaw = raw['confidenceScore'];
  final confidenceScore = confidenceRaw is num
      ? confidenceRaw.round().clamp(0, 100)
      : null;

  return ProposalGenerationResult(
    content: content,
    confidenceScore: confidenceScore,
    sourceBusinessUnitIds: _stringList(raw['sourceBusinessUnitIds']),
    sourceProductIds: _stringList(raw['sourceProductIds']),
    sourceServiceIds: _stringList(raw['sourceServiceIds']),
    sourceCapabilityIds: _stringList(raw['sourceCapabilityIds']),
    sourceTechnologyIds: _stringList(raw['sourceTechnologyIds']),
    sourceIndustryIds: _stringList(raw['sourceIndustryIds']),
    sourceExperienceIds: _stringList(raw['sourceExperienceIds']),
    sourceKnowledgeArticleIds: _stringList(raw['sourceKnowledgeArticleIds']),
    aiGeneratedAt: aiGeneratedAt,
  );
}
