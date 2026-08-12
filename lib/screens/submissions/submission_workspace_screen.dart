import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/models/submission_communication.dart';
import 'package:jva_projecttracker/screens/documents/document_library_screen.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/screens/submissions/submission_communication_form.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/submission_review_service.dart';
import 'package:jva_projecttracker/services/submission_transitions.dart';
import 'package:jva_projecttracker/services/submission_validation.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/bullet_list.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/inline_editable_text.dart';
import 'package:jva_projecttracker/widgets/insight_banner.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/priority_style.dart';
import 'package:jva_projecttracker/widgets/proposal_progress_ring.dart';
import 'package:jva_projecttracker/widgets/proposal_progress_tracker.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';
import 'package:jva_projecttracker/widgets/submission_blocker_tile.dart';
import 'package:jva_projecttracker/widgets/submission_status_style.dart';
import 'package:jva_projecttracker/widgets/submission_timeline_view.dart';
import 'package:jva_projecttracker/widgets/submission_validation_style.dart';

IconData _communicationIcon(CommunicationType type) => switch (type) {
  CommunicationType.meeting => Icons.groups_outlined,
  CommunicationType.email => Icons.email_outlined,
  CommunicationType.clarification => Icons.help_outline,
  CommunicationType.addendum => Icons.attach_file,
  CommunicationType.reminder => Icons.notifications_outlined,
};

/// Wraps a hero card in a colored left accent rail — same technique used on
/// the Dashboard and Proposal Workspace.
Widget _heroAccent({required Color color, required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    child: child,
  );
}

/// The Submission Workspace (Milestone 4.5, merged with the Milestone 4.4
/// pre-submission gate) — everything a team needs to answer "is this
/// submission healthy, can we submit today, what's blocking us, who owns
/// what, how many days remain" for one opportunity's bid.
///
/// Before a [Submission] exists, this screen *is* the gate: a Validation
/// Engine (submittability checks), 5-role Internal Approvals, and an AI
/// Submission Review must be satisfied before "Submit" is enabled. Only once
/// submitted does it finalize the [Proposal] (`ProposalStatus.finalized`),
/// transition the opportunity to `OpportunityPipelineStage.submitted`, and
/// create the [Submission] record — closing the gap where a bare
/// `Submission` could previously be created with no validation, no
/// approvals, and no pipeline transition (see ADR-010 and the "two
/// submission concepts" reconciliation note in PROJECT_PROGRESS.md). After
/// submission, the same validation/approvals/AI-review content remains
/// available as a collapsed "Submission Review" reference rather than the
/// primary gate, since it has already been passed. Deliberately orchestrates
/// existing intelligence (AI Classification/Match Analysis/Strategic Review
/// outputs already on [Opportunity], [ProposalSection] progress,
/// [SubmissionReadiness] document gaps, active [Recommendation]s) rather
/// than introducing a new AI pass — the only new data here is the
/// [Submission] record itself and its client-communication log.
class SubmissionWorkspaceScreen extends ConsumerStatefulWidget {
  const SubmissionWorkspaceScreen({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  ConsumerState<SubmissionWorkspaceScreen> createState() =>
      _SubmissionWorkspaceScreenState();
}

class _SubmissionWorkspaceScreenState
    extends ConsumerState<SubmissionWorkspaceScreen> {
  bool _reviewing = false;
  bool _submitting = false;

  Future<void> _runAiReview(String proposalId) async {
    final strings = ref.read(appStringsProvider);
    setState(() => _reviewing = true);
    try {
      await ref
          .read(submissionReviewServiceProvider)
          .generateReview(proposalId: proposalId);
    } on SubmissionReviewException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.aiReviewFailedMessage)));
      }
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _recordApproval(Proposal proposal, ApprovalRole role) async {
    final strings = ref.read(appStringsProvider);
    final result = await showDialog<_ApprovalDialogResult>(
      context: context,
      builder: (dialogContext) => _ApprovalDialog(strings: strings, role: role),
    );
    if (result == null) return;

    final updated = applyApprovalDecision(
      proposal.approvals,
      role: role,
      decision: result.decision,
      approverName: result.approverName,
      comment: result.comment,
      now: DateTime.now(),
    );
    await ref
        .read(proposalServiceProvider)
        .updateApprovals(proposal.id, updated);
  }

  Future<bool> _confirmSubmit(AppStrings strings) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.submitProposalConfirmTitle),
        content: Text(strings.submitProposalConfirmBody),
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

  /// The real "submit" action: finalizes the proposal, transitions the
  /// opportunity's pipeline stage, and only then creates the [Submission]
  /// record — in that order, so a `Submission` never exists for a proposal
  /// that hasn't actually cleared the gate.
  Future<void> _submit(Proposal proposal) async {
    final strings = ref.read(appStringsProvider);
    final confirmed = await _confirmSubmit(strings);
    if (!confirmed) return;

    setState(() => _submitting = true);
    final actor = ref.read(authStateChangesProvider).value?.email;
    await ref
        .read(proposalServiceProvider)
        .updateStatus(proposal.id, ProposalStatus.finalized);
    await ref
        .read(opportunityServiceProvider)
        .transitionStage(
          opportunityId: widget.opportunityId,
          newStage: OpportunityPipelineStage.submitted,
          note: 'Proposal submitted',
          actor: actor,
        );
    final now = DateTime.now();
    await ref
        .read(submissionServiceProvider)
        .create(
          Submission(
            id: '',
            opportunityId: widget.opportunityId,
            proposalId: proposal.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (mounted) setState(() => _submitting = false);
  }

  /// Writes the new [SubmissionStatus] and, for the two outcome statuses
  /// that have a real Opportunity-side counterpart, also moves the
  /// Opportunity's pipeline stage to match — via the same audited
  /// [OpportunityService.transitionStage] `_submit` already uses, so the
  /// stage change and its [OpportunityEvent] land together. Without this,
  /// a Submission could be marked `awarded` while the Opportunity silently
  /// stayed at `submitted` forever, meaning "Start Project" would never
  /// appear on the Opportunity Workspace even though the deal was won —
  /// these two documents are otherwise never reconciled by anything else
  /// in the app.
  Future<void> _updateSubmissionStatus(
    Submission submission,
    SubmissionStatus newStatus,
    Opportunity opportunity,
  ) async {
    await ref
        .read(submissionServiceProvider)
        .updateStatus(submission.id, newStatus);

    final newStage = switch (newStatus) {
      SubmissionStatus.awarded => OpportunityPipelineStage.awarded,
      SubmissionStatus.lost => OpportunityPipelineStage.lost,
      _ => null,
    };
    // No-op if the Opportunity already reflects this outcome — re-selecting
    // the same dropdown value (or a redundant status write) shouldn't add a
    // second identical entry to the Opportunity's audit trail.
    if (newStage == null || opportunity.pipelineStage == newStage) return;

    final actor = ref.read(authStateChangesProvider).value?.email;
    await ref
        .read(opportunityServiceProvider)
        .transitionStage(
          opportunityId: widget.opportunityId,
          newStage: newStage,
          note: 'Submission marked ${newStatus.name}',
          actor: actor,
        );
  }

  /// The status dropdown, constrained to what `submission_transitions.dart`
  /// actually allows from the current status — forward lifecycle steps plus
  /// the one available same-mistake correction, never an arbitrary jump.
  /// Closed submissions (awarded/lost/withdrawn) show a plain read-only
  /// chip with an explanation instead of a dropdown, since there is
  /// nowhere left to transition to.
  Widget _buildStatusControl(
    AppStrings strings,
    Submission submission,
    Opportunity opportunity,
  ) {
    if (submission.status.isClosed) {
      return Tooltip(
        message: strings.submissionStatusClosedMessage,
        child: Chip(
          label: Text(strings.submissionStatusLabel(submission.status)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final allowed = allowedSubmissionTransitions(submission.status);
    return DropdownButton<SubmissionStatus>(
      value: submission.status,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(
          value: submission.status,
          child: Text(strings.submissionStatusLabel(submission.status)),
        ),
        for (final s in allowed)
          DropdownMenuItem(
            value: s,
            child: Text(strings.submissionStatusLabel(s)),
          ),
      ],
      onChanged: (s) {
        if (s == null || s == submission.status) return;
        final check = checkSubmissionTransition(from: submission.status, to: s);
        if (!check.isAllowed) {
          final message = switch (check.blockReason!) {
            SubmissionTransitionBlockReason.notYetSubmitted =>
              strings.submissionStatusNotYetSubmittedMessage,
            SubmissionTransitionBlockReason.alreadyClosed =>
              strings.submissionStatusClosedMessage,
            SubmissionTransitionBlockReason.notAllowedFromCurrentStatus =>
              strings.submissionStatusNotYetSubmittedMessage,
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        _updateSubmissionStatus(submission, s, opportunity);
      },
    );
  }

  String _deadlineText(AppStrings strings, DateTime deadline) {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return strings.deadlineOverdueLabel(-daysLeft);
    if (daysLeft == 0) return strings.deadlineDueTodayLabel;
    return strings.deadlineDueInLabel(daysLeft);
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
              icon: Icons.rocket_launch_outlined,
              title: strings.submissionWorkspaceTitle,
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
          ? EmptyState(
              icon: Icons.description_outlined,
              title: strings.noProposalForSubmissionMessage,
              action: FilledButton.icon(
                onPressed: () => pushSlideFade(
                  context,
                  ProposalWorkspaceScreen(opportunityId: widget.opportunityId),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(strings.openProposalWorkspaceButton),
              ),
            )
          : _buildForProposal(strings, opportunity, proposal),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
    );
  }

  Widget _buildForProposal(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
  ) {
    final submissionAsync = ref.watch(
      submissionByOpportunityIdProvider(widget.opportunityId),
    );

    return submissionAsync.when(
      data: (submission) => submission == null
          ? _buildReadyToSubmit(strings, opportunity, proposal)
          : _buildWorkspace(strings, opportunity, proposal, submission),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
    );
  }

  // ---------------------------------------------------------------------
  // Pre-submission gate (ported from Milestone 4.4's own Submission
  // Workspace, `lib/screens/proposals/submission_workspace_screen.dart`,
  // now deleted — this is its one surviving home).
  // ---------------------------------------------------------------------

  Widget _buildReadyToSubmit(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
  ) {
    final validation = ref.watch(
      submissionValidationProvider(widget.opportunityId),
    );
    final timeline = ref.watch(
      submissionTimelineProvider(widget.opportunityId),
    );
    if (validation == null || timeline == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildExecutiveSummary(strings, opportunity, validation),
        const SizedBox(height: AppSpacing.xl),
        Text(
          strings.submissionTimelineSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        SubmissionTimelineView(entries: timeline, strings: strings),
        const SizedBox(height: AppSpacing.xl),
        _buildValidationStatus(strings, validation),
        const SizedBox(height: AppSpacing.xl),
        _buildInternalApprovals(strings, proposal),
        const SizedBox(height: AppSpacing.xl),
        _buildAiSubmissionReview(strings, proposal),
        const SizedBox(height: AppSpacing.xl),
        _buildSubmitAction(strings, proposal, validation),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildExecutiveSummary(
    AppStrings strings,
    Opportunity opportunity,
    SubmissionValidation validation,
  ) {
    final theme = Theme.of(context);
    return _heroAccent(
      color: theme.colorScheme.primary,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProposalProgressRing(progress: validation.readinessScore),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.executiveSubmissionSummaryTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Chip(
                          label: Text(
                            strings.blockersCountLabel(
                              validation.blockers.length,
                            ),
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
                      ],
                    ),
                    if (opportunity.deadline != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _deadlineText(strings, opportunity.deadline!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationStatus(
    AppStrings strings,
    SubmissionValidation validation,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.validationStatusSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            InsightBanner(
              icon: validation.isSubmittable
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              message: validation.isSubmittable
                  ? strings.validationAllClearMessage
                  : strings.validationBlockedBannerMessage,
              isPositive: validation.isSubmittable,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final check in validation.checks)
                  _ValidationCheckCard(strings: strings, check: check),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalApprovals(AppStrings strings, Proposal proposal) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.internalApprovalsSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final approval in mergedApprovals(proposal.approvals))
                  _ApprovalCard(
                    strings: strings,
                    approval: approval,
                    onTap: () => _recordApproval(proposal, approval.role),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSubmissionReview(AppStrings strings, Proposal proposal) {
    final theme = Theme.of(context);
    final reviewed = proposal.submissionReviewedAt != null;
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.aiSubmissionReviewSectionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _reviewing
                      ? null
                      : () => _runAiReview(proposal.id),
                  icon: _reviewing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    reviewed
                        ? strings.regenerateAiReviewButton
                        : strings.runAiReviewButton,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!reviewed)
              Text(strings.neverReviewedMessage)
            else ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (proposal.submissionReviewReadiness != null)
                    Chip(
                      label: Text(
                        strings.submissionReviewReadinessLabel(
                          proposal.submissionReviewReadiness!,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (proposal.submissionReviewRiskLevel != null)
                    Chip(
                      label: Text(
                        strings.riskLevelLabel(
                          proposal.submissionReviewRiskLevel!,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.lastReviewedLabel(
                  dateFormat.format(proposal.submissionReviewedAt!),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BulletList(
                label: strings.missingEvidenceLabel,
                items: proposal.submissionReviewMissingEvidence,
              ),
              BulletList(
                label: strings.weakSectionsLabel,
                items: proposal.submissionReviewWeakSections,
              ),
              BulletList(
                label: strings.strongSectionsLabel,
                items: proposal.submissionReviewStrongSections,
              ),
              BulletList(
                label: strings.complianceConcernsLabel,
                items: proposal.submissionReviewComplianceConcerns,
              ),
              BulletList(
                label: strings.recommendedImprovementsLabel,
                items: proposal.submissionReviewRecommendedImprovements,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitAction(
    AppStrings strings,
    Proposal proposal,
    SubmissionValidation validation,
  ) {
    final canSubmit = validation.isSubmittable;

    return Center(
      child: Tooltip(
        message: canSubmit ? '' : strings.submitBlockedTooltip,
        child: FilledButton.icon(
          onPressed: _submitting || !canSubmit ? null : () => _submit(proposal),
          icon: _submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(strings.submitProposalButton),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Post-submission workspace (Milestone 4.5).
  // ---------------------------------------------------------------------

  Widget _buildWorkspace(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
    Submission submission,
  ) {
    final sectionsAsync = ref.watch(
      proposalSectionsByProposalIdProvider(proposal.id),
    );

    return sectionsAsync.when(
      data: (sections) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildHeader(strings, opportunity, proposal, submission, sections),
            const SizedBox(height: AppSpacing.xl),
            _buildAiSummary(strings, opportunity),
            const SizedBox(height: AppSpacing.lg),
            _buildBlockers(strings, opportunity, proposal, submission),
            const SizedBox(height: AppSpacing.lg),
            _buildProposalProgress(strings, proposal, sections),
            const SizedBox(height: AppSpacing.lg),
            _buildSubmissionReviewSection(strings, proposal),
            const SizedBox(height: AppSpacing.lg),
            _buildTeamCollaboration(strings, submission),
            const SizedBox(height: AppSpacing.lg),
            _buildTimeline(strings, proposal, submission),
            const SizedBox(height: AppSpacing.lg),
            _buildClientCommunication(strings, submission),
            const SizedBox(height: AppSpacing.lg),
            _buildRelatedKnowledge(strings, opportunity),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(strings.errorPrefix(error))),
    );
  }

  /// The pre-submission gate's validation/approvals/AI-review content,
  /// collapsed by default here — the gate has already been passed by the
  /// time a [Submission] exists, so this is a reference, not an action.
  Widget _buildSubmissionReviewSection(AppStrings strings, Proposal proposal) {
    final validation = ref.watch(
      submissionValidationProvider(widget.opportunityId),
    );
    if (validation == null) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(strings.submissionOverviewSectionTitle),
        subtitle: Text(strings.blockersCountLabel(validation.blockers.length)),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          _buildValidationStatus(strings, validation),
          const SizedBox(height: AppSpacing.lg),
          _buildInternalApprovals(strings, proposal),
          const SizedBox(height: AppSpacing.lg),
          _buildAiSubmissionReview(strings, proposal),
        ],
      ),
    );
  }

  Widget _buildHeader(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
    Submission submission,
    List<ProposalSection> sections,
  ) {
    final theme = Theme.of(context);
    final progress = ref.watch(proposalSectionProgressProvider(proposal.id));
    final statusColor = submissionStatusColor(submission.status);

    return Row(
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
              Text(opportunity.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      strings.submissionStatusLabel(submission.status),
                    ),
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: statusColor),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (opportunity.priority != null)
                    Builder(
                      builder: (context) {
                        final (bg, fg) = priorityColors(
                          theme.colorScheme,
                          opportunity.priority!,
                        );
                        return Chip(
                          label: Text(
                            strings.opportunityPriorityLabel(
                              opportunity.priority!,
                            ),
                          ),
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  if (opportunity.riskLevel != null)
                    Builder(
                      builder: (context) {
                        final (bg, fg) = riskColors(
                          theme.colorScheme,
                          opportunity.riskLevel!,
                        );
                        return Chip(
                          label: Text(
                            strings.riskLevelLabel(opportunity.riskLevel!),
                          ),
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  if (opportunity.deadline != null)
                    Text(
                      _deadlineText(strings, opportunity.deadline!),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildStatusControl(strings, submission, opportunity),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummary(AppStrings strings, Opportunity opportunity) {
    final theme = Theme.of(context);
    final hasStrategicReview = opportunity.strategicReviewedAt != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.sectionExecutiveSummary,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!hasStrategicReview)
              Text(strings.noStrategicReviewForProposalPrompt)
            else ...[
              if (opportunity.executiveSummary?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(opportunity.executiveSummary!),
                ),
              BulletList(
                label: strings.strategicStrengthsLabel,
                items: opportunity.strategicStrengths,
              ),
              BulletList(
                label: strings.missingRequirementsLabel,
                items: opportunity.missingRequirements,
              ),
              BulletList(
                label: strings.nextRecommendedActionsLabel,
                items: opportunity.nextRecommendedActions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockers(
    AppStrings strings,
    Opportunity opportunity,
    Proposal proposal,
    Submission submission,
  ) {
    final theme = Theme.of(context);
    final blockers = ref.watch(
      submissionBlockersProvider((
        opportunityId: widget.opportunityId,
        proposalId: proposal.id,
      )),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  blockers.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.flag_outlined,
                  color: blockers.isEmpty
                      ? AppStatusColors.success
                      : AppStatusColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  strings.sectionSubmissionBlockers,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (blockers.isEmpty)
              Text(strings.noSubmissionBlockersMessage)
            else
              for (final blocker in blockers)
                SubmissionBlockerTile(blocker: blocker),
            const SizedBox(height: AppSpacing.sm),
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
    );
  }

  Widget _buildProposalProgress(
    AppStrings strings,
    Proposal proposal,
    List<ProposalSection> sections,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.proposalProgressSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => pushSlideFade(
                    context,
                    ProposalWorkspaceScreen(
                      opportunityId: widget.opportunityId,
                    ),
                  ),
                  child: Text(strings.proposalWorkspaceTitle),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProposalProgressTracker(sections: sections),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCollaboration(AppStrings strings, Submission submission) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.teamCollaborationSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.submissionOwnerLabel,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            InlineEditableText(
              key: ValueKey('submission-owner-${submission.id}'),
              value: submission.assignedTo,
              placeholder: strings.unassignedLabel,
              onChanged: (value) => ref
                  .read(submissionServiceProvider)
                  .updateAssignedTo(submission.id, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(
    AppStrings strings,
    Proposal proposal,
    Submission submission,
  ) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());
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
      if (submission.submittedAt != null)
        (Icons.send_outlined, dateFormat.format(submission.submittedAt!)),
      if (submission.evaluationDate != null)
        (
          Icons.fact_check_outlined,
          '${strings.evaluationDateLabel}: ${dateFormat.format(submission.evaluationDate!)}',
        ),
      if (submission.outcomeAt != null)
        (Icons.flag_outlined, dateFormat.format(submission.outcomeAt!)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.proposalTimelineSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
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
    );
  }

  Widget _buildClientCommunication(AppStrings strings, Submission submission) {
    final theme = Theme.of(context);
    final communicationsAsync = ref.watch(
      submissionCommunicationsBySubmissionIdProvider(submission.id),
    );
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.sectionClientCommunication,
                  style: theme.textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () =>
                      showAddCommunicationDialog(context, submission.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(strings.logCommunicationButton),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            communicationsAsync.when(
              data: (communications) {
                if (communications.isEmpty) {
                  return Text(strings.noCommunicationsLoggedMessage);
                }
                return Column(
                  children: [
                    for (final c in communications)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_communicationIcon(c.type), size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.subject,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  if (c.notes.isNotEmpty) Text(c.notes),
                                  Text(
                                    dateFormat.format(c.date),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedKnowledge(AppStrings strings, Opportunity opportunity) {
    final theme = Theme.of(context);
    final relatedWins = ref.watch(
      relatedWinningOpportunitiesProvider(widget.opportunityId),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.sectionRelatedKnowledge,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              strings.previousWinningProposalsLabel,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (relatedWins.isEmpty)
              Text(strings.noPreviousWinningProposalsMessage)
            else
              for (final win in relatedWins)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: Text(win.opportunity.title),
                    subtitle: Text(win.reasoning),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
            RecommendedEntityChips<Capability>(
              label: strings.recommendedCapabilitiesLabel,
              ids: opportunity.strategicReviewCapabilityIds,
              optionsAsync: ref.watch(capabilitiesStreamProvider),
              idOf: (c) => c.id,
              nameOf: (c) => c.name,
            ),
            RecommendedEntityChips<Technology>(
              label: strings.recommendedTechnologiesLabel,
              ids: opportunity.strategicReviewTechnologyIds,
              optionsAsync: ref.watch(technologiesStreamProvider),
              idOf: (t) => t.id,
              nameOf: (t) => t.name,
            ),
            RecommendedEntityChips<Experience>(
              label: strings.recommendedExperiencesLabel,
              ids: opportunity.strategicReviewExperienceIds,
              optionsAsync: ref.watch(experiencesStreamProvider),
              idOf: (e) => e.id,
              nameOf: (e) => e.title,
            ),
            RecommendedEntityChips<KnowledgeArticle>(
              label: strings.recommendedKnowledgeLabel,
              ids: opportunity.strategicReviewKnowledgeArticleIds,
              optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
              idOf: (a) => a.id,
              nameOf: (a) => a.title,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationCheckCard extends StatelessWidget {
  const _ValidationCheckCard({required this.strings, required this.check});

  final AppStrings strings;
  final ValidationCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = validationSeverityColors(
      theme.colorScheme,
      check.severity,
    );
    final icon = switch (check.severity) {
      ValidationSeverity.passed => Icons.check_circle_outline,
      ValidationSeverity.warning => Icons.info_outline,
      ValidationSeverity.blocker => Icons.block_outlined,
    };

    return SizedBox(
      width: 240,
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: foreground, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      strings.validationCheckLabel(check.id),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                strings.validationCheckExplanation(check.id),
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.strings,
    required this.approval,
    required this.onTap,
  });

  final AppStrings strings;
  final ProposalApproval approval;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = switch (approval.decision) {
      ApprovalDecision.approved => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      ApprovalDecision.rejected => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      ApprovalDecision.pending => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return SizedBox(
      width: 220,
      child: Card(
        color: background,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.approvalRoleLabel(approval.role),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.approvalDecisionLabel(approval.decision),
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
                if (approval.approverName?.isNotEmpty ?? false)
                  Text(
                    approval.approverName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _ApprovalDialogResult = ({
  ApprovalDecision decision,
  String? approverName,
  String? comment,
});

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.strings, required this.role});

  final AppStrings strings;
  final ApprovalRole role;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit(ApprovalDecision decision) {
    Navigator.of(context).pop<_ApprovalDialogResult>((
      decision: decision,
      approverName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(
        '${strings.recordApprovalTitle} — ${strings.approvalRoleLabel(widget.role)}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: strings.fieldApproverName),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: strings.fieldApprovalComment,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        OutlinedButton(
          onPressed: () => _submit(ApprovalDecision.rejected),
          child: Text(strings.rejectButton),
        ),
        FilledButton(
          onPressed: () => _submit(ApprovalDecision.approved),
          child: Text(strings.approveButton),
        ),
      ],
    );
  }
}
