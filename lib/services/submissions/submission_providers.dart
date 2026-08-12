import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/models/submission_communication.dart';
import 'package:jva_projecttracker/services/related_submission_knowledge.dart';
import 'package:jva_projecttracker/services/submission_blockers.dart';
import 'package:jva_projecttracker/services/submission_communication_service.dart';
import 'package:jva_projecttracker/services/submission_review_service.dart';
import 'package:jva_projecttracker/services/submission_service.dart';

import '../opportunities/opportunity_providers.dart';
import '../proposals/proposal_providers.dart';
import '../recommendations/recommendation_providers.dart';

final submissionServiceProvider = Provider((ref) => SubmissionService());
final submissionReviewServiceProvider = Provider(
  (ref) => SubmissionReviewService(),
);
final submissionCommunicationServiceProvider = Provider(
  (ref) => SubmissionCommunicationService(),
);

/// The submission record for one opportunity, live — `null` until one has
/// been started (see [Submission]). Milestone 4.5 (Submission Workspace).
final submissionByOpportunityIdProvider = StreamProvider.autoDispose
    .family<Submission?, String>((ref, opportunityId) {
      return ref
          .watch(submissionServiceProvider)
          .watchByOpportunityId(opportunityId);
    });

final submissionsStreamProvider = StreamProvider<List<Submission>>((ref) {
  return ref.watch(submissionServiceProvider).watchAll();
});

/// Top 5 open submissions paired with their opportunity (if loaded).
final topSubmissionsProvider =
    Provider<List<({Submission submission, Opportunity? opportunity})>>((ref) {
      final submissions =
          ref.watch(submissionsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};
      final open = submissions.where((s) => !s.status.isClosed).toList();
      open.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return open
          .take(5)
          .map((s) => (submission: s, opportunity: oppById[s.opportunityId]))
          .toList();
    });

/// A submission's logged client communications, live, most recent first.
final submissionCommunicationsBySubmissionIdProvider =
    StreamProvider.family<List<SubmissionCommunication>, String>((
      ref,
      submissionId,
    ) {
      return ref
          .watch(submissionCommunicationServiceProvider)
          .watchBySubmissionId(submissionId);
    });

/// The Submission Workspace's consolidated Blockers panel — derived from
/// data already streamed for the Proposal Workspace
/// ([proposalSectionsByProposalIdProvider], [submissionReadinessProvider])
/// plus a plain count of still-active recommendations
/// ([recommendationsForOpportunityProvider]). See `submission_blockers.dart`.
final submissionBlockersProvider =
    Provider.family<
      List<SubmissionBlocker>,
      ({String opportunityId, String proposalId})
    >((ref, args) {
      final sections =
          ref
              .watch(proposalSectionsByProposalIdProvider(args.proposalId))
              .value ??
          const [];
      final readiness = ref.watch(submissionReadinessProvider(args.proposalId));
      final activeRecommendationCount = ref
          .watch(recommendationsForOpportunityProvider(args.opportunityId))
          .where((r) => r.status == RecommendationStatus.active)
          .length;
      final submission = ref
          .watch(submissionByOpportunityIdProvider(args.opportunityId))
          .value;
      final opportunity = ref
          .watch(opportunityByIdProvider(args.opportunityId))
          .value;

      return computeSubmissionBlockers(
        proposalSections: sections,
        documentReadiness: readiness,
        activeRecommendationCount: activeRecommendationCount,
        submission: submission,
        deadline: opportunity?.deadline,
      );
    });

/// Open submissions that currently have at least one real blocker — the
/// Dashboard's "Submissions requiring action" source. Reuses
/// [submissionBlockersProvider] per open submission (itself already a pure
/// derivation over already-loaded streams) rather than duplicating its
/// logic; the only thing new here is the portfolio-wide loop, which
/// [submissionBlockersProvider]'s per-submission `family` shape didn't
/// previously have a caller for. No new Firestore reads.
final submissionsWithBlockersProvider =
    Provider<List<({Submission submission, Opportunity? opportunity})>>((ref) {
      final submissions =
          ref.watch(submissionsStreamProvider).value ?? const [];
      final opportunities =
          ref.watch(opportunitiesStreamProvider).value ?? const [];
      final oppById = {for (final o in opportunities) o.id: o};

      final open = submissions.where((s) => !s.status.isClosed);
      final withBlockers =
          <({Submission submission, Opportunity? opportunity})>[];
      for (final s in open) {
        final blockers = ref.watch(
          submissionBlockersProvider((
            opportunityId: s.opportunityId,
            proposalId: s.proposalId,
          )),
        );
        if (blockers.isNotEmpty) {
          withBlockers.add((
            submission: s,
            opportunity: oppById[s.opportunityId],
          ));
        }
      }
      return withBlockers;
    });

/// Previously won opportunities related to this one, for the Submission
/// Workspace's Related Knowledge panel. See
/// `related_submission_knowledge.dart`.
final relatedWinningOpportunitiesProvider =
    Provider.family<List<RelatedWinningOpportunity>, String>((
      ref,
      opportunityId,
    ) {
      final opportunity = ref
          .watch(opportunityByIdProvider(opportunityId))
          .value;
      if (opportunity == null) return const [];
      final all = ref.watch(opportunitiesStreamProvider).value ?? const [];
      return computeRelatedWinningOpportunities(
        opportunity: opportunity,
        allOpportunities: all,
      );
    });
