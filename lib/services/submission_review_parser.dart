import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';

/// The validated, ready-to-apply result of an AI Submission Review run — the
/// client-side counterpart to the Cloud Function's own
/// `validateSubmissionReview` (see `functions/index.js`). Mirrors
/// `ProposalGenerationResult`/`parseProposalGenerationResponse` exactly: the
/// Cloud Function already validates before writing to Firestore and before
/// returning its response, but this parser never assumes that.
class SubmissionReviewResult {
  const SubmissionReviewResult({
    required this.overallReadiness,
    required this.riskLevel,
    required this.missingEvidence,
    required this.weakSections,
    required this.strongSections,
    required this.complianceConcerns,
    required this.recommendedImprovements,
    required this.reviewedAt,
  });

  final SubmissionReviewReadiness overallReadiness;
  final RiskLevel riskLevel;
  final List<String> missingEvidence;
  final List<String> weakSections;
  final List<String> strongSections;
  final List<String> complianceConcerns;
  final List<String> recommendedImprovements;
  final DateTime? reviewedAt;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
}

/// Parses and validates the raw payload returned by the
/// `generateSubmissionReview` Cloud Function. Returns `null` only when the
/// payload isn't even a usable map — every field beyond that degrades
/// gracefully (missing/invalid enums fall back to a sensible default,
/// exactly like every other AI-enum field in this app).
SubmissionReviewResult? parseSubmissionReviewResponse(
  Map<String, dynamic>? raw,
) {
  if (raw == null) return null;

  final reviewedAtRaw = raw['reviewedAt'];
  final reviewedAt = reviewedAtRaw is String
      ? DateTime.tryParse(reviewedAtRaw)
      : null;

  return SubmissionReviewResult(
    overallReadiness: SubmissionReviewReadinessX.fromString(
      raw['overallReadiness'] as String? ?? 'needsWork',
    ),
    riskLevel: RiskLevelX.fromString(raw['riskLevel'] as String? ?? 'medium'),
    missingEvidence: _stringList(raw['missingEvidence']),
    weakSections: _stringList(raw['weakSections']),
    strongSections: _stringList(raw['strongSections']),
    complianceConcerns: _stringList(raw['complianceConcerns']),
    recommendedImprovements: _stringList(raw['recommendedImprovements']),
    reviewedAt: reviewedAt,
  );
}
