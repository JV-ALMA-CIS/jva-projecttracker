import 'package:jva_projecttracker/models/executive_summary.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

/// What kind of gap a [SubmissionBlocker] represents — drives its icon on
/// the Submission Workspace.
enum SubmissionBlockerCategory {
  proposalSection,
  document,
  recommendation,
  submissionRecord,
}

/// One consolidated "why can't we submit yet" item. Reuses
/// [ExecutiveInsightSeverity] (info/watch/risk) rather than a new severity
/// enum — the same three-level urgency signal already established for
/// Milestone 5.1's AI insights applies just as well here.
class SubmissionBlocker {
  final String title;
  final ExecutiveInsightSeverity severity;
  final SubmissionBlockerCategory category;

  const SubmissionBlocker({
    required this.title,
    required this.severity,
    required this.category,
  });
}

const int _kBlockerUrgentDeadlineDays = 3;

/// Builds the Submission Workspace's consolidated blockers list from data
/// that's already been derived elsewhere — proposal sections,
/// [SubmissionReadiness] (document gaps), and a plain count of still-active
/// AI recommendations for the opportunity. This function performs no
/// Firestore reads and introduces no new business rules of its own; it
/// only prioritizes and phrases what other providers already computed,
/// per this project's "analytics must derive from existing data" rule.
List<SubmissionBlocker> computeSubmissionBlockers({
  required List<ProposalSection> proposalSections,
  required SubmissionReadiness documentReadiness,
  required int activeRecommendationCount,
  required Submission? submission,
  DateTime? deadline,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final urgent =
      deadline != null &&
      deadline.difference(today).inDays <= _kBlockerUrgentDeadlineDays;

  final blockers = <SubmissionBlocker>[];

  final incompleteSections = proposalSections
      .where((s) => s.status != ProposalSectionStatus.approved)
      .length;
  if (incompleteSections > 0) {
    blockers.add(
      SubmissionBlocker(
        title: '$incompleteSections proposal section(s) not yet approved',
        severity: urgent
            ? ExecutiveInsightSeverity.risk
            : ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.proposalSection,
      ),
    );
  }

  final unassignedSections = proposalSections
      .where((s) => (s.assignedTo ?? '').isEmpty)
      .length;
  if (unassignedSections > 0) {
    blockers.add(
      SubmissionBlocker(
        title: '$unassignedSections proposal section(s) have no owner',
        severity: ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.proposalSection,
      ),
    );
  }

  if (documentReadiness.missingCategories.isNotEmpty) {
    blockers.add(
      SubmissionBlocker(
        title:
            '${documentReadiness.missingCategories.length} required document category(ies) missing',
        severity: ExecutiveInsightSeverity.risk,
        category: SubmissionBlockerCategory.document,
      ),
    );
  }

  if (documentReadiness.expiredDocuments.isNotEmpty) {
    blockers.add(
      SubmissionBlocker(
        title:
            '${documentReadiness.expiredDocuments.length} document(s) have expired',
        severity: ExecutiveInsightSeverity.risk,
        category: SubmissionBlockerCategory.document,
      ),
    );
  }

  if (documentReadiness.pendingReviewDocuments.isNotEmpty) {
    blockers.add(
      SubmissionBlocker(
        title:
            '${documentReadiness.pendingReviewDocuments.length} document(s) awaiting review',
        severity: ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.document,
      ),
    );
  }

  if (documentReadiness.needsUpdateDocuments.isNotEmpty) {
    blockers.add(
      SubmissionBlocker(
        title:
            '${documentReadiness.needsUpdateDocuments.length} document(s) need an update',
        severity: ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.document,
      ),
    );
  }

  if (activeRecommendationCount > 0) {
    blockers.add(
      SubmissionBlocker(
        title:
            '$activeRecommendationCount AI recommendation(s) still need action',
        severity: ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.recommendation,
      ),
    );
  }

  if (submission != null &&
      submission.status == SubmissionStatus.submitted &&
      (submission.referenceNumber ?? '').isEmpty) {
    blockers.add(
      const SubmissionBlocker(
        title: 'No reference/confirmation number recorded for this submission',
        severity: ExecutiveInsightSeverity.watch,
        category: SubmissionBlockerCategory.submissionRecord,
      ),
    );
  }

  if (submission != null &&
      submission.status == SubmissionStatus.underEvaluation &&
      submission.evaluationDate == null) {
    blockers.add(
      const SubmissionBlocker(
        title: 'No evaluation date recorded',
        severity: ExecutiveInsightSeverity.info,
        category: SubmissionBlockerCategory.submissionRecord,
      ),
    );
  }

  int rank(ExecutiveInsightSeverity s) => switch (s) {
    ExecutiveInsightSeverity.risk => 0,
    ExecutiveInsightSeverity.watch => 1,
    ExecutiveInsightSeverity.info => 2,
  };
  blockers.sort((a, b) => rank(a.severity).compareTo(rank(b.severity)));

  return blockers;
}
