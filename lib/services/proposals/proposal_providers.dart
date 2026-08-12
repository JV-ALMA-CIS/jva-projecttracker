import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/document_suggestions.dart';
import 'package:jva_projecttracker/services/proposal_generation_service.dart';
import 'package:jva_projecttracker/services/proposal_readiness.dart';
import 'package:jva_projecttracker/services/proposal_section_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';
import 'package:jva_projecttracker/services/submission_timeline.dart';
import 'package:jva_projecttracker/services/submission_validation.dart';

import '../library/library_document_providers.dart';
import '../opportunities/opportunity_providers.dart';

final proposalServiceProvider = Provider((ref) => ProposalService());
final proposalSectionServiceProvider = Provider(
  (ref) => ProposalSectionService(),
);
final proposalGenerationServiceProvider = Provider(
  (ref) => ProposalGenerationService(),
);

/// The proposal for one opportunity, live. See [projectByIdProvider] for
/// the autoDispose/family reasoning — scoped to the Proposal Workspace
/// screen's lifetime.
final proposalByOpportunityIdProvider = StreamProvider.autoDispose
    .family<Proposal?, String>((ref, opportunityId) {
      return ref
          .watch(proposalServiceProvider)
          .watchByOpportunityId(opportunityId);
    });

/// A proposal's sections, live, ordered by [ProposalSection.order]. Not
/// autoDispose — same reasoning as [opportunityEventsByOpportunityProvider]:
/// a list keyed by a parent id, not a single "detail screen" entity.
final proposalSectionsByProposalIdProvider =
    StreamProvider.family<List<ProposalSection>, String>((ref, proposalId) {
      return ref
          .watch(proposalSectionServiceProvider)
          .watchByProposalId(proposalId);
    });

/// Section-completion progress for one proposal (0-1), derived from
/// [proposalSectionsByProposalIdProvider] — same "derive from the live
/// stream" idiom as [activeRecommendationsProvider]/[notificationsProvider].
/// Milestone 4.4 (Submission Tracking) is expected to blend in checklist
/// completion alongside this, not replace it.
final proposalSectionProgressProvider = Provider.family<double, String>((
  ref,
  proposalId,
) {
  final sections =
      ref.watch(proposalSectionsByProposalIdProvider(proposalId)).value ??
      const [];
  if (sections.isEmpty) return 0;
  final approved = sections
      .where((s) => s.status == ProposalSectionStatus.approved)
      .length;
  return approved / sections.length;
});

/// A proposal's at-a-glance submission readiness for the given opportunity
/// — see `proposal_readiness.dart`. Derived from data already loaded by the
/// Proposal Workspace (the proposal's own section-completion progress plus
/// the linked opportunity's deadline); no new reads.
final proposalReadinessProvider = Provider.family<ProposalReadiness, String>((
  ref,
  opportunityId,
) {
  final proposal = ref
      .watch(proposalByOpportunityIdProvider(opportunityId))
      .value;
  final opportunity = ref.watch(opportunityByIdProvider(opportunityId)).value;
  final progress = proposal == null
      ? 0.0
      : ref.watch(proposalSectionProgressProvider(proposal.id));

  return deriveProposalReadiness(
    sectionProgress: progress,
    status: proposal?.status ?? ProposalStatus.draft,
    deadline: opportunity?.deadline,
    now: DateTime.now(),
  );
});

/// Every document linked to one proposal, live.
final documentsForProposalProvider =
    StreamProvider.family<List<LibraryDocument>, String>((ref, proposalId) {
      return ref
          .watch(libraryDocumentServiceProvider)
          .watchByProposal(proposalId);
    });

/// A proposal's document-based submission readiness — see
/// `submission_readiness.dart`. Derived purely from the documents already
/// linked to it; no independent computation.
final submissionReadinessProvider =
    Provider.family<SubmissionReadiness, String>((ref, proposalId) {
      final documents =
          ref.watch(documentsForProposalProvider(proposalId)).value ?? const [];
      return deriveSubmissionReadiness(
        proposalDocuments: documents,
        now: DateTime.now(),
      );
    });

/// Contextual document suggestions for one opportunity's proposal — see
/// `document_suggestions.dart`. `null` while the opportunity/proposal
/// aren't loaded yet.
final documentSuggestionsProvider =
    Provider.family<List<DocumentSuggestion>, String>((ref, opportunityId) {
      final opportunity = ref
          .watch(opportunityByIdProvider(opportunityId))
          .value;
      final proposal = ref
          .watch(proposalByOpportunityIdProvider(opportunityId))
          .value;
      if (opportunity == null || proposal == null) return const [];

      final allDocuments =
          ref.watch(libraryDocumentsStreamProvider).value ?? const [];
      final linkedDocuments =
          ref.watch(documentsForProposalProvider(proposal.id)).value ??
          const [];

      return deriveDocumentSuggestions(
        opportunity: opportunity,
        proposal: proposal,
        allDocuments: allDocuments,
        linkedDocuments: linkedDocuments,
        now: DateTime.now(),
      );
    });

/// Submission-derived helpers
final submissionValidationProvider =
    Provider.family<SubmissionValidation?, String>((ref, opportunityId) {
      final proposal = ref
          .watch(proposalByOpportunityIdProvider(opportunityId))
          .value;
      if (proposal == null) return null;
      final sections =
          ref.watch(proposalSectionsByProposalIdProvider(proposal.id)).value ??
          const [];
      final readiness = ref.watch(submissionReadinessProvider(proposal.id));
      return deriveSubmissionValidation(
        proposal: proposal,
        sections: sections,
        documentReadiness: readiness,
        now: DateTime.now(),
      );
    });

final submissionTimelineProvider =
    Provider.family<List<SubmissionTimelineEntry>?, String>((
      ref,
      opportunityId,
    ) {
      final proposal = ref
          .watch(proposalByOpportunityIdProvider(opportunityId))
          .value;
      final opportunity = ref
          .watch(opportunityByIdProvider(opportunityId))
          .value;
      if (proposal == null || opportunity == null) return null;
      final sections =
          ref.watch(proposalSectionsByProposalIdProvider(proposal.id)).value ??
          const [];
      final readiness = ref.watch(submissionReadinessProvider(proposal.id));
      return deriveSubmissionTimeline(
        proposal: proposal,
        sections: sections,
        documentReadiness: readiness,
        pipelineStage: opportunity.pipelineStage,
      );
    });

/// Every proposal, live. Backs the Dashboard's "Active proposals" strip —
/// see [ProposalService.watchAll].
final proposalsStreamProvider = StreamProvider<List<Proposal>>((ref) {
  return ref.watch(proposalServiceProvider).watchAll();
});

/// The 3 most recently updated proposals, for the Dashboard's compact
/// section — same "derive, then take(n)" shape as [topOpportunitiesProvider].
final topProposalsProvider = Provider<List<Proposal>>((ref) {
  final proposals = ref.watch(proposalsStreamProvider).value ?? const [];
  return proposals.take(3).toList();
});
