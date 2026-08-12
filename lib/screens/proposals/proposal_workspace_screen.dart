import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/screens/documents/document_library_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/proposal_progress_ring.dart';
import 'package:jva_projecttracker/widgets/proposal_progress_tracker.dart';
import 'package:jva_projecttracker/widgets/proposal_readiness_style.dart';
import 'package:jva_projecttracker/widgets/proposal_section_card.dart';
import 'package:jva_projecttracker/widgets/proposal_section_style.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Wraps this workspace's two always-visible "hero" cards (AI Proposal
/// Summary, Submission Overview) in a colored left accent rail, so they
/// read as primary content versus the collapsed reference cards below them
/// — the same accent-rail technique used on the Dashboard, applied here to
/// this screen's own two most important cards. The border is additive
/// (Flutter grows the box around the child), so the wrapped `Card`'s own
/// content is untouched.
Widget _heroAccent({required Color color, required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    child: child,
  );
}

/// The Proposal Workspace — an AI co-pilot for preparing one opportunity's
/// proposal, not a document editor. Everything a team needs to answer "are
/// we ready to submit, what's missing, what should we do next, what does AI
/// say, who owns what" lives on this one page: a header with completion/
/// readiness/deadline, an always-visible AI summary (sourced from the
/// opportunity's own strategic review — no separate proposal-AI backend
/// exists yet, see Milestone 4.2), a real-sections progress tracker, the
/// existing inline-expand section list, and collapsible Document Readiness/
/// Team Collaboration/Timeline/AI Assistant panels. Sections are collapsed,
/// glanceable rows that expand in place to edit (no separate editor
/// screen); nothing here requires an explicit "Save" — every edit
/// auto-commits. See ADR-008 for the original foundation this redesign
/// builds on.
class ProposalWorkspaceScreen extends ConsumerStatefulWidget {
  const ProposalWorkspaceScreen({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  ConsumerState<ProposalWorkspaceScreen> createState() =>
      _ProposalWorkspaceScreenState();
}

class _ProposalWorkspaceScreenState
    extends ConsumerState<ProposalWorkspaceScreen> {
  bool _creating = false;

  Future<void> _createProposal(Opportunity opportunity) async {
    setState(() => _creating = true);
    final now = DateTime.now();

    final proposalId = await ref
        .read(proposalServiceProvider)
        .create(
          Proposal(
            id: '',
            opportunityId: widget.opportunityId,
            title: 'Proposal for ${opportunity.title}',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final sectionService = ref.read(proposalSectionServiceProvider);
    for (final (index, type) in ProposalSectionTypeX.standardSet.indexed) {
      await sectionService.create(
        ProposalSection(
          id: '',
          proposalId: proposalId,
          order: index,
          type: type,
          title: type.label,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (opportunity.pipelineStage.index <
        OpportunityPipelineStage.proposalStarted.index) {
      final actor = ref.read(authStateChangesProvider).value?.email;
      await ref
          .read(opportunityServiceProvider)
          .transitionStage(
            opportunityId: widget.opportunityId,
            newStage: OpportunityPipelineStage.proposalStarted,
            note: 'Proposal created',
            actor: actor,
          );
    }

    if (mounted) setState(() => _creating = false);
  }

  Future<void> _addSection(
    String proposalId,
    List<ProposalSection> existing,
  ) async {
    final strings = ref.read(appStringsProvider);
    final existingTypes = existing.map((s) => s.type).toSet();
    final available = ProposalSectionTypeX.standardSet
        .where((t) => !existingTypes.contains(t))
        .toList();

    final chosen = await showModalBottomSheet<ProposalSectionType>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in available)
              ListTile(
                leading: Icon(proposalSectionTypeIcon(type)),
                title: Text(strings.proposalSectionTypeLabel(type)),
                onTap: () => Navigator.of(sheetContext).pop(type),
              ),
            ListTile(
              leading: Icon(
                proposalSectionTypeIcon(ProposalSectionType.custom),
              ),
              title: Text(
                strings.proposalSectionTypeLabel(ProposalSectionType.custom),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ProposalSectionType.custom),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    final now = DateTime.now();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1;
    await ref
        .read(proposalSectionServiceProvider)
        .create(
          ProposalSection(
            id: '',
            proposalId: proposalId,
            order: nextOrder,
            type: chosen,
            title: chosen.label,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<bool> _confirmDeleteSection() async {
    final strings = ref.read(appStringsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteSectionConfirmTitle),
        content: Text(strings.deleteSectionConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.confirmButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onReorder(
    List<ProposalSection> sections,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem (unlike the deprecated onReorder) already adjusts
    // newIndex for the removed item at oldIndex — no manual -1 needed.
    final reordered = [...sections];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await ref
        .read(proposalSectionServiceProvider)
        .reorder(reordered.map((s) => s.id).toList());
  }

  String _deadlineText(AppStrings strings, DateTime deadline, DateTime now) {
    final daysLeft = deadline.difference(now).inDays;
    if (daysLeft < 0) return strings.deadlineOverdueLabel(-daysLeft);
    if (daysLeft == 0) return strings.deadlineDueTodayLabel;
    return strings.deadlineDueInLabel(daysLeft);
  }

  Widget _bulletList(BuildContext context, String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final opportunityAsync = ref.watch(
      opportunityByIdProvider(widget.opportunityId),
    );

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: PageHeader(
              icon: Icons.description_outlined,
              title: strings.proposalWorkspaceTitle,
              subtitle: null,
            ),
          ),
          Expanded(
            child: opportunityAsync.when(
              data: (opportunity) => opportunity == null
                  ? const SizedBox.shrink()
                  : _buildBody(strings, opportunity),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(strings.errorPrefix(error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppStrings strings, Opportunity opportunity) {
    final proposalAsync = ref.watch(
      proposalByOpportunityIdProvider(widget.opportunityId),
    );

    return proposalAsync.when(
      data: (proposal) => proposal == null
          ? _buildEmptyState(strings, opportunity)
          : _buildWorkspace(strings, opportunity, proposal),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
    );
  }

  Widget _buildEmptyState(AppStrings strings, Opportunity opportunity) {
    return EmptyState(
      icon: Icons.description_outlined,
      title: strings.createProposalEmptyStateTitle,
      body: strings.createProposalEmptyStateBody,
      action: FilledButton.icon(
        onPressed: _creating ? null : () => _createProposal(opportunity),
        icon: _creating
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(strings.createProposalButton),
      ),
    );
  }

  Widget _buildWorkspace(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
  ) {
    final sectionsAsync = ref.watch(
      proposalSectionsByProposalIdProvider(proposal.id),
    );

    return sectionsAsync.when(
      data: (sections) {
        final approvedCount = sections
            .where((s) => s.status == ProposalSectionStatus.approved)
            .length;
        final allApproved =
            sections.isNotEmpty && approvedCount == sections.length;

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: sections.length,
          onReorderItem: (oldIndex, newIndex) =>
              _onReorder(sections, oldIndex, newIndex),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                strings,
                opportunity,
                proposal,
                sections,
                approvedCount,
                allApproved,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAiSummary(strings, opportunity, sections),
              const SizedBox(height: AppSpacing.lg),
              _buildSubmissionOverview(strings, opportunity, proposal),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: strings.proposalProgressSectionTitle),
              const SizedBox(height: AppSpacing.sm),
              ProposalProgressTracker(sections: sections),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
          itemBuilder: (context, index) {
            final section = sections[index];
            return Padding(
              key: ValueKey(section.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ProposalSectionCard(
                section: section,
                opportunity: opportunity,
                dragHandleIndex: index,
                onDelete: () async {
                  final confirmed = await _confirmDeleteSection();
                  if (confirmed) {
                    await ref
                        .read(proposalSectionServiceProvider)
                        .delete(section.id);
                  }
                },
              ),
            );
          },
          footer: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: OutlinedButton.icon(
                  onPressed: () => _addSection(proposal.id, sections),
                  icon: const Icon(Icons.add),
                  label: Text(strings.addSectionButton),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDocumentReadiness(strings, proposal),
              const SizedBox(height: AppSpacing.md),
              _buildTeamCollaboration(strings, proposal, sections),
              const SizedBox(height: AppSpacing.md),
              _buildTimeline(strings, proposal),
              const SizedBox(height: AppSpacing.md),
              _buildAiAssistantPanel(strings),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
    );
  }

  Widget _buildHeader(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
    List<ProposalSection> sections,
    int approvedCount,
    bool allApproved,
  ) {
    final theme = Theme.of(context);
    final progress = ref.watch(proposalSectionProgressProvider(proposal.id));
    final readiness = ref.watch(
      proposalReadinessProvider(widget.opportunityId),
    );
    final (readinessBg, readinessFg) = proposalReadinessColors(
      theme.colorScheme,
      readiness,
    );
    final isReady = proposal.status == ProposalStatus.readyForReview;
    final locale = strings.locale.languageCode;
    final dateFormat = DateFormat.yMMMd(locale);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProposalProgressRing(progress: progress),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opportunity.client ?? opportunity.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                _ProposalTitleField(
                  key: ValueKey('title-${proposal.id}'),
                  proposal: proposal,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.sectionsCompletedLabel(
                    approvedCount,
                    sections.length,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(strings.proposalStatusLabel(proposal.status)),
                      backgroundColor: isReady
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isReady
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(strings.proposalReadinessLabel(readiness)),
                      backgroundColor: readinessBg,
                      labelStyle: TextStyle(color: readinessFg),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (opportunity.deadline != null)
                      Text(
                        _deadlineText(
                          strings,
                          opportunity.deadline!,
                          DateTime.now(),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.proposalLastUpdatedLabel(
                    dateFormat.format(proposal.updatedAt),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (proposal.status != ProposalStatus.finalized)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: isReady
                        ? TextButton(
                            onPressed: () => ref
                                .read(proposalServiceProvider)
                                .updateStatus(
                                  proposal.id,
                                  ProposalStatus.draft,
                                ),
                            child: Text(strings.reopenForEditingButton),
                          )
                        : TextButton(
                            onPressed: allApproved
                                ? () => ref
                                      .read(proposalServiceProvider)
                                      .updateStatus(
                                        proposal.id,
                                        ProposalStatus.readyForReview,
                                      )
                                : null,
                            child: Text(strings.markReadyForReviewButton),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummary(
    AppStrings strings,
    Opportunity opportunity,
    List<ProposalSection> sections,
  ) {
    final theme = Theme.of(context);
    final hasStrategicReview = opportunity.strategicReviewedAt != null;

    final incomplete = sections
        .where((s) => s.status != ProposalSectionStatus.approved)
        .length;
    final unassigned = sections
        .where((s) => (s.assignedTo ?? '').isEmpty)
        .length;

    return _heroAccent(
      color: AppStatusColors.ai,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.aiProposalSummarySectionTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (hasStrategicReview) ...[
                Text(
                  strings.aiSummaryFromStrategicReviewCaption,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (opportunity.executiveRecommendation != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Chip(
                      label: Text(
                        strings.strategicReviewRecommendationLabel(
                          opportunity.executiveRecommendation!,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (opportunity.executiveSummary?.isNotEmpty ?? false) ...[
                  Text(
                    strings.executiveSummaryLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(opportunity.executiveSummary!),
                  ),
                ],
                _bulletList(
                  context,
                  strings.strategicStrengthsLabel,
                  opportunity.strategicStrengths,
                ),
                _bulletList(
                  context,
                  strings.strategicWeaknessesLabel,
                  opportunity.strategicWeaknesses,
                ),
                _bulletList(
                  context,
                  strings.missingRequirementsLabel,
                  opportunity.missingRequirements,
                ),
                _bulletList(
                  context,
                  strings.nextRecommendedActionsLabel,
                  opportunity.nextRecommendedActions,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    strings.noStrategicReviewForProposalPrompt,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              Text(
                strings.proposalReadinessAssessmentTitle,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (incomplete == 0 && unassigned == 0)
                Text(strings.allSectionsCompleteLabel)
              else ...[
                if (incomplete > 0)
                  Text(strings.incompleteSectionsCountLabel(incomplete)),
                if (unassigned > 0)
                  Text(strings.unassignedSectionsCountLabel(unassigned)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionOverview(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
  ) {
    final theme = Theme.of(context);
    final validation = ref.watch(
      submissionValidationProvider(widget.opportunityId),
    );
    if (validation == null) return const SizedBox.shrink();

    final pendingApprovals = mergedApprovals(
      proposal.approvals,
    ).where((a) => a.decision == ApprovalDecision.pending).length;

    return _heroAccent(
      color: theme.colorScheme.primary,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.submissionOverviewSectionTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      strings.submissionReadinessScoreLabel(
                        (validation.readinessScore * 100).round(),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      strings.blockersCountLabel(validation.blockers.length),
                    ),
                    backgroundColor: validation.isSubmittable
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: validation.isSubmittable
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (pendingApprovals > 0)
                    Chip(
                      label: Text(
                        strings.approvalsPendingCountLabel(pendingApprovals),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (opportunity.deadline != null)
                    Text(
                      _deadlineText(
                        strings,
                        opportunity.deadline!,
                        DateTime.now(),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => pushSlideFade(
                  context,
                  SubmissionWorkspaceScreen(
                    opportunityId: widget.opportunityId,
                  ),
                ),
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: Text(strings.openSubmissionWorkspaceButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentReadiness(AppStrings strings, Proposal proposal) {
    final theme = Theme.of(context);
    final readiness = ref.watch(submissionReadinessProvider(proposal.id));
    final suggestions = ref.watch(
      documentSuggestionsProvider(widget.opportunityId),
    );
    final (readyBg, readyFg) = readiness.isReady
        ? (
            theme.colorScheme.primaryContainer,
            theme.colorScheme.onPrimaryContainer,
          )
        : (
            theme.colorScheme.errorContainer,
            theme.colorScheme.onErrorContainer,
          );

    return Card(
      child: ExpansionTile(
        title: Text(strings.submissionReadinessSectionTitle),
        leading: const Icon(Icons.folder_outlined),
        trailing: Chip(
          label: Text(
            readiness.isReady
                ? strings.submissionReadyLabel
                : strings.submissionNotReadyLabel,
          ),
          backgroundColor: readyBg,
          labelStyle: TextStyle(color: readyFg),
          visualDensity: VisualDensity.compact,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Chip(
                      label: Text(
                        strings.requiredDocumentsCountLabel(
                          readiness.requiredCategories.length,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(
                        strings.uploadedDocumentsCountLabel(
                          readiness.uploadedCategories.length,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (readiness.missingCategories.isNotEmpty)
                      Chip(
                        label: Text(
                          strings.missingDocumentsCountLabel(
                            readiness.missingCategories.length,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (readiness.expiredDocuments.isNotEmpty)
                      Chip(
                        label: Text(
                          strings.expiredDocumentsCountLabel(
                            readiness.expiredDocuments.length,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (readiness.pendingReviewDocuments.isNotEmpty)
                      Chip(
                        label: Text(
                          strings.pendingReviewDocumentsCountLabel(
                            readiness.pendingReviewDocuments.length,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (readiness.needsUpdateDocuments.isNotEmpty)
                      Chip(
                        label: Text(
                          strings.needsUpdateDocumentsCountLabel(
                            readiness.needsUpdateDocuments.length,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.suggestionsSectionLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (suggestions.isEmpty)
                  Text(strings.noSuggestionsLabel)
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final suggestion in suggestions)
                        Tooltip(
                          message: strings.documentSuggestionReason(suggestion),
                          child: Chip(
                            label: Text(
                              strings.documentSuggestionTitle(suggestion),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => pushSlideFade(
                    context,
                    DocumentLibraryScreen(proposalId: proposal.id),
                  ),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(strings.manageDocumentsButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCollaboration(
    AppStrings strings,
    Proposal proposal,
    List<ProposalSection> sections,
  ) {
    final theme = Theme.of(context);
    final owner = proposal.assignedTo;
    final approvalStageText = proposal.status == ProposalStatus.readyForReview
        ? strings.approvalStageAwaitingReviewLabel
        : strings.approvalStageInPreparationLabel(
            owner?.isNotEmpty == true ? owner! : strings.unassignedLabel,
          );

    final outstanding = <String>[
      for (final s in sections)
        if (s.status != ProposalSectionStatus.approved)
          strings.sectionNeedsCompletionLabel(s.title),
      for (final s in sections)
        if ((s.assignedTo ?? '').isEmpty)
          strings.sectionNeedsOwnerLabel(s.title),
    ];

    return Card(
      child: ExpansionTile(
        title: Text(strings.teamCollaborationSectionTitle),
        leading: const Icon(Icons.groups_outlined),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.proposalOwnerLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                _ProposalOwnerField(
                  key: ValueKey('owner-${proposal.id}'),
                  proposal: proposal,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(approvalStageText, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.outstandingActionsSectionLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (outstanding.isEmpty)
                  Text(strings.noOutstandingActionsLabel)
                else
                  for (final action in outstanding)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(AppStrings strings, Proposal proposal) {
    final locale = strings.locale.languageCode;
    final dateFormat = DateFormat.yMMMd(locale);

    final entries = <(IconData, String)>[
      (
        Icons.add_circle_outline,
        strings.timelineProposalCreatedLabel(
          dateFormat.format(proposal.createdAt),
        ),
      ),
      if (proposal.readyForReviewAt != null)
        (
          Icons.rate_review_outlined,
          strings.timelineMarkedReadyLabel(
            dateFormat.format(proposal.readyForReviewAt!),
          ),
        ),
      (
        Icons.update_outlined,
        strings.timelineLastActivityLabel(
          dateFormat.format(proposal.updatedAt),
        ),
      ),
    ];

    return Card(
      child: ExpansionTile(
        title: Text(strings.proposalTimelineSectionTitle),
        leading: const Icon(Icons.timeline_outlined),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (icon, label) in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(label)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantPanel(AppStrings strings) {
    final theme = Theme.of(context);
    // "Regenerate section"/"Improve writing" were placeholders here in
    // Milestone 4.1 — Milestone 4.2 made them real, per-section actions on
    // each ProposalSectionCard instead, so they're no longer listed as
    // still-pending here.
    final actions = [
      (Icons.warning_amber_outlined, strings.identifyRisksActionLabel),
      (Icons.lightbulb_outline, strings.suggestMissingContentActionLabel),
      (Icons.psychology_outlined, strings.explainRecommendationsActionLabel),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.aiAssistantPanelSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (icon, label) in actions)
                  Tooltip(
                    message: strings.comingInFutureMilestoneTooltip,
                    child: Chip(
                      avatar: Icon(icon, size: 18),
                      label: Text(label),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap-to-edit proposal title — no separate "rename" dialog, matching the
/// modern-workspace feel the rest of this screen aims for.
class _ProposalTitleField extends ConsumerStatefulWidget {
  const _ProposalTitleField({super.key, required this.proposal});

  final Proposal proposal;

  @override
  ConsumerState<_ProposalTitleField> createState() =>
      _ProposalTitleFieldState();
}

class _ProposalTitleFieldState extends ConsumerState<_ProposalTitleField> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.proposal.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    ref
        .read(proposalServiceProvider)
        .updateTitle(widget.proposal.id, _controller.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: _controller,
        autofocus: true,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
      );
    }
    return InkWell(
      onTap: () => setState(() => _editing = true),
      child: Text(
        widget.proposal.title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

/// Tap-to-edit proposal owner — same pattern as [_ProposalTitleField].
class _ProposalOwnerField extends ConsumerStatefulWidget {
  const _ProposalOwnerField({super.key, required this.proposal});

  final Proposal proposal;

  @override
  ConsumerState<_ProposalOwnerField> createState() =>
      _ProposalOwnerFieldState();
}

class _ProposalOwnerFieldState extends ConsumerState<_ProposalOwnerField> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.proposal.assignedTo);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _controller.text.trim();
    ref
        .read(proposalServiceProvider)
        .updateAssignedTo(widget.proposal.id, value.isEmpty ? null : value);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    if (_editing) {
      return TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
      );
    }
    final owner = widget.proposal.assignedTo;
    return InkWell(
      onTap: () => setState(() => _editing = true),
      child: Text(owner?.isNotEmpty == true ? owner! : strings.unassignedLabel),
    );
  }
}
