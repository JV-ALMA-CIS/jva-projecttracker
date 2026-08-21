import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/project_deliverable.dart';
import 'package:jva_projecttracker/models/project_event.dart';
import 'package:jva_projecttracker/models/project_milestone.dart';
import 'package:jva_projecttracker/models/project_risk.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_form_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_extraction_review_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/screens/projects/upload_project_document_dialog.dart';
import 'package:jva_projecttracker/services/project_experience_promotion.dart';
import 'package:jva_projecttracker/services/project_extraction_service.dart';
import 'package:jva_projecttracker/services/project_health.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/hover_lift.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

Color _healthColor(ColorScheme scheme, ProjectHealthLevel status) =>
    switch (status) {
      ProjectHealthLevel.healthy => AppStatusColors.success,
      ProjectHealthLevel.atRisk => AppStatusColors.warning,
      ProjectHealthLevel.critical => scheme.error,
    };

/// The operational center for an awarded/in-progress project — the primary
/// destination once a project exists, per the "Opportunities become
/// Projects" lifecycle. [ProjectFormScreen] remains the create/edit form,
/// reached from here via the app bar's edit action, never opened directly
/// from the Projects list anymore.
///
/// Milestones/Deliverables/Risks/Recent Activity have real backing
/// (`ProjectMilestone`/`ProjectDeliverable`/`ProjectRisk`/`ProjectEvent` +
/// their services/providers) and render live data here, with full add/edit
/// dialogs (`_MilestoneDialog`/`_DeliverableDialog`/`_RiskDialog`) — each
/// dialog's "create from extracted text" strip pre-fills a title from the
/// project's uploaded documents' `aiExtractedDeliverables`/`aiExtractedRisks`
/// when creating a new item, but every field remains manually editable; no
/// AI extraction returns structured per-item dates/severities/statuses to
/// auto-populate those. "AI Project Insights" is the one section still
/// genuinely unimplemented — no project-insight AI service exists anywhere
/// in this codebase, so it shows an honest "coming later" card rather than
/// a fabricated one.
class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState
    extends ConsumerState<ProjectWorkspaceScreen> {
  String? _extractingDocumentId;
  bool _publishingExperience = false;

  Future<void> _extractKnowledge(String documentId) async {
    final strings = ref.read(appStringsProvider);
    setState(() => _extractingDocumentId = documentId);
    try {
      await ref
          .read(projectExtractionServiceProvider)
          .extract(documentId: documentId);
    } on ProjectExtractionException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.extractionFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _extractingDocumentId = null);
    }
  }

  /// Calls the same [promoteProjectToExperience] logic
  /// project_form_screen.dart uses — see that function's doc for why this
  /// is shared rather than reimplemented per screen.
  Future<void> _publishAsExperience(Project project) async {
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.addAsExperienceConfirmTitle),
        content: Text(strings.addAsExperienceConfirmBody),
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
    if (confirmed != true) return;

    setState(() => _publishingExperience = true);
    final experienceId = await promoteProjectToExperience(ref, project);
    if (!mounted) return;
    setState(() => _publishingExperience = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.experienceCreatedFromProjectMessage)),
    );
    pushSlideFade(context, ExperienceFormScreen(experienceId: experienceId));
  }

  Future<void> _editBudget(Project project) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditBudgetDialog(project: project),
    );
  }

  Future<void> _editLessonsLearned(Project project) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditLessonsLearnedDialog(project: project),
    );
  }

  Future<void> _addOrEditMilestone(
    String projectId, [
    ProjectMilestone? milestone,
  ]) async {
    // Only fetched (and only worth fetching) when creating a brand new
    // milestone — an existing one is being edited, not seeded from the
    // document's extracted narrative.
    final candidates = milestone == null
        ? _extractedCandidates(
            await ref.read(documentsForProjectProvider(projectId).future),
            (doc) => doc.aiExtractedDeliverables,
          )
        : const <String>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MilestoneDialog(
        projectId: projectId,
        milestone: milestone,
        extractedCandidates: candidates,
      ),
    );
  }

  Future<void> _addOrEditDeliverable(
    String projectId, [
    ProjectDeliverable? deliverable,
  ]) async {
    final candidates = deliverable == null
        ? _extractedCandidates(
            await ref.read(documentsForProjectProvider(projectId).future),
            (doc) => doc.aiExtractedDeliverables,
          )
        : const <String>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _DeliverableDialog(
        projectId: projectId,
        deliverable: deliverable,
        extractedCandidates: candidates,
      ),
    );
  }

  Future<void> _addOrEditRisk(String projectId, [ProjectRisk? risk]) async {
    final candidates = risk == null
        ? _extractedCandidates(
            await ref.read(documentsForProjectProvider(projectId).future),
            (doc) => doc.aiExtractedRisks,
          )
        : const <String>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _RiskDialog(
        projectId: projectId,
        risk: risk,
        extractedCandidates: candidates,
      ),
    );
  }

  Future<void> _delete(AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteTooltip),
        content: Text(strings.deleteProjectConfirmBody),
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
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(projectServiceProvider).delete(widget.projectId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.projectDeletedMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(projectAsync.value?.name ?? strings.projectWorkspaceTitle),
        actions: [
          IconButton(
            onPressed: () => pushSlideFade(
              context,
              ProjectFormScreen(projectId: widget.projectId),
            ),
            icon: const Icon(Icons.edit_outlined),
            tooltip: strings.editProjectTitle,
          ),
          IconButton(
            onPressed: () => _delete(strings),
            icon: const Icon(Icons.delete_outline),
            tooltip: strings.deleteTooltip,
          ),
        ],
      ),
      body: projectAsync.when(
        data: (project) => project == null
            ? const SizedBox.shrink()
            : _buildBody(context, strings, project),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppStrings strings, Project project) {
    final theme = Theme.of(context);
    final health = ref.watch(projectHealthProvider(project.id));
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // --- Executive overview ---
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  if (project.client.isNotEmpty)
                    Text(
                      project.client,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Chip(
                        label: Text(strings.projectStatusLabel(project.status)),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          strings.projectCategoryLabel(project.category),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          strings.contractorRoleLabel(project.contractorRole),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          strings.clientTypeLabel(project.clientType),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (project.location.isNotEmpty)
                        Chip(
                          avatar: const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                          ),
                          label: Text(project.location),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (project.projectSize.isNotEmpty)
                        Chip(
                          label: Text(project.projectSize),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (project.fundingAgency.isNotEmpty)
                        Chip(
                          avatar: const Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                          ),
                          label: Text(project.fundingAgency),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (project.scopeOfWorks.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(project.scopeOfWorks),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // --- Delivery tracking: full detail for planned/running projects
        // (especially those with a sourceOpportunityId, i.e. started from
        // an awarded Opportunity); collapsed by default — but never
        // removed — for Past/evidence projects, where cost, funding
        // agency, and scope (above) are the primary story, not delivery
        // health. Nothing here is deleted or hidden permanently; a user
        // can still expand it on a Past project to see/edit the same
        // milestone/deliverable/risk/team data.
        if (project.status == ProjectStatus.past)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text(strings.deliveryTrackingOptionalSectionTitle),
              subtitle: Text(strings.deliveryTrackingOptionalSectionCaption),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                _buildDeliverySection(
                  strings,
                  theme,
                  project,
                  health,
                  dateFormat,
                ),
              ],
            ),
          )
        else
          _buildDeliverySection(strings, theme, project, health, dateFormat),
        const SizedBox(height: AppSpacing.xl),
        _buildRestOfBody(strings, project),
      ],
    );
  }

  /// Budget/Timeline/Deliverables/Risks/Team — the full "Operational
  /// Delivery Workspace" content, extracted into its own method so
  /// [_buildBody] can either inline it (planned/running projects) or wrap
  /// it in a collapsed [ExpansionTile] (Past/evidence projects) without
  /// duplicating any of the section bodies themselves.
  Widget _buildDeliverySection(
    AppStrings strings,
    ThemeData theme,
    Project project,
    ProjectHealth health,
    DateFormat dateFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Status & progress (health) ---
        SectionHeader(
          title: strings.overallHealthLabel,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _healthColor(theme.colorScheme, health.overall),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        health.overall == ProjectHealthLevel.healthy
                            ? strings.projectOnTrackMessage
                            : health.overall == ProjectHealthLevel.atRisk
                            ? strings.healthAtRiskLabel
                            : strings.healthCriticalLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _HealthChip(
                        label: strings.scheduleHealthLabel,
                        status: health.scheduleHealth,
                        strings: strings,
                      ),
                      _HealthChip(
                        label: strings.budgetHealthLabel,
                        status: health.budgetHealth,
                        strings: strings,
                      ),
                      _HealthChip(
                        label: strings.riskHealthLabel,
                        status: health.riskHealth,
                        strings: strings,
                      ),
                    ],
                  ),
                  if (project.endDate != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      // Once a project is marked Past, its endDate is a
                      // historical fact, not a projection — labeling it
                      // "Expected" (even for a date years in the past) was
                      // misleading. Only Planned/Running projects show it as
                      // an expectation still ahead of them.
                      '${project.status == ProjectStatus.past ? strings.actualCompletionLabel : strings.expectedCompletionLabel}: '
                      '${dateFormat.format(project.endDate!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Operational Delivery Workspace divider ---
        // Groups Budget/Timeline/Deliverables/Risks/Team under one visual
        // heading so this screen reads as "evidence first, delivery
        // tracking second" rather than presenting delivery fields as the
        // primary purpose of a historical project record. Nothing below is
        // removed or hidden — every field/service here is unchanged.
        Text(
          strings.deliveryWorkspaceSectionTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          strings.deliveryWorkspaceSectionCaption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(),
        const SizedBox(height: AppSpacing.md),

        // --- Budget ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.budgetSectionTitle,
                accentColor: AppStatusColors.operations,
              ),
            ),
            TextButton.icon(
              onPressed: () => _editBudget(project),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(strings.editBudgetButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _BudgetCard(project: project, strings: strings),
        const SizedBox(height: AppSpacing.xl),

        // --- Timeline / Milestones (real) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.timelineSectionTitle,
                accentColor: AppStatusColors.operations,
              ),
            ),
            IconButton(
              onPressed: () => _addOrEditMilestone(project.id),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: strings.addMilestoneButton,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (context, ref, _) {
            final milestonesAsync = ref.watch(
              projectMilestonesByProjectIdProvider(project.id),
            );
            return milestonesAsync.when(
              data: (milestones) {
                if (milestones.isEmpty) {
                  return _PlaceholderCard(
                    message: strings.noMilestonesMessage,
                    actionLabel: strings.addMilestoneButton,
                    strings: strings,
                    onAdd: () => _addOrEditMilestone(project.id),
                  );
                }
                return Column(
                  children: [
                    for (final milestone in milestones)
                      _MilestoneTile(
                        milestone: milestone,
                        strings: strings,
                        onTap: () => _addOrEditMilestone(project.id, milestone),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Deliverables (real) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.deliverablesSectionTitle,
                accentColor: AppStatusColors.operations,
              ),
            ),
            IconButton(
              onPressed: () => _addOrEditDeliverable(project.id),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: strings.addDeliverableButton,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (context, ref, _) {
            final deliverablesAsync = ref.watch(
              projectDeliverablesByProjectIdProvider(project.id),
            );
            return deliverablesAsync.when(
              data: (deliverables) {
                if (deliverables.isEmpty) {
                  return _PlaceholderCard(
                    message: strings.noDeliverablesMessage,
                    actionLabel: strings.addDeliverableButton,
                    strings: strings,
                    onAdd: () => _addOrEditDeliverable(project.id),
                  );
                }
                return Column(
                  children: [
                    for (final deliverable in deliverables)
                      _DeliverableTile(
                        deliverable: deliverable,
                        strings: strings,
                        onTap: () =>
                            _addOrEditDeliverable(project.id, deliverable),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Risks (real) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.risksSectionTitle,
                accentColor: AppStatusColors.warning,
              ),
            ),
            IconButton(
              onPressed: () => _addOrEditRisk(project.id),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: strings.addRiskButton,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (context, ref, _) {
            final risksAsync = ref.watch(
              projectRisksByProjectIdProvider(project.id),
            );
            return risksAsync.when(
              data: (risks) {
                if (risks.isEmpty) {
                  return _PlaceholderCard(
                    message: strings.noRisksMessage,
                    actionLabel: strings.addRiskButton,
                    strings: strings,
                    onAdd: () => _addOrEditRisk(project.id),
                  );
                }
                final sorted = [...risks]
                  ..sort((a, b) => b.priorityRank.compareTo(a.priorityRank));
                return Column(
                  children: [
                    for (final risk in sorted)
                      _RiskTile(
                        risk: risk,
                        strings: strings,
                        onTap: () => _addOrEditRisk(project.id, risk),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Team ---
        SectionHeader(
          title: strings.teamSectionTitle,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.projectManagerLabel,
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(project.projectManager ?? strings.notSetLabel),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.teamMembersLabel,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  project.teamMembers.isEmpty
                      ? Text(strings.notSetLabel)
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final member in project.teamMembers)
                              Chip(
                                label: Text(member),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestOfBody(AppStrings strings, Project project) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Documents & AI Knowledge Extraction (real) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.aiKnowledgeExtractionSectionTitle,
                accentColor: AppStatusColors.ai,
              ),
            ),
            TextButton.icon(
              onPressed: () => showUploadProjectDocumentDialog(
                context,
                projectId: project.id,
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(strings.uploadDocumentButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (context, ref, _) {
            final documentsAsync = ref.watch(
              documentsForProjectProvider(project.id),
            );
            return documentsAsync.when(
              data: (documents) {
                if (documents.isEmpty) {
                  return Text(strings.noProjectDocumentsMessage);
                }
                return Column(
                  children: [
                    for (final doc in documents)
                      _WorkspaceDocumentTile(
                        document: doc,
                        strings: strings,
                        isExtracting: _extractingDocumentId == doc.id,
                        onExtract: () => _extractKnowledge(doc.id),
                        onReview: () => pushSlideFade(
                          context,
                          ProjectExtractionReviewScreen(
                            documentId: doc.id,
                            projectId: project.id,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Lessons Learned (real field, no prior edit path — small
        // inline editor added here since it's genuinely missing, not
        // duplicated from anywhere) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SectionHeader(
                title: strings.lessonsLearnedSectionTitle,
                accentColor: AppStatusColors.success,
              ),
            ),
            IconButton(
              onPressed: () => _editLessonsLearned(project),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: strings.editButton,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                project.lessonsLearned.isEmpty
                    ? strings.lessonsLearnedHint
                    : project.lessonsLearned,
                style: project.lessonsLearned.isEmpty
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Experience & Knowledge publishing (real) ---
        SectionHeader(
          title: strings.relatedKnowledgeSectionTitle,
          accentColor: AppStatusColors.ai,
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (project.experienceId != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppStatusColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            strings.alreadyPublishedAsExperienceLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => pushSlideFade(
                        context,
                        ExperienceFormScreen(
                          experienceId: project.experienceId,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(strings.viewExperienceButton),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: _publishingExperience
                          ? null
                          : () => _publishAsExperience(project),
                      icon: _publishingExperience
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(strings.publishAsExperienceButton),
                    ),
                  if (project.knowledgeArticleIds.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${project.knowledgeArticleIds.length} '
                      '${strings.knowledgeBaseTitle}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.similarProjectsLabel,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Consumer(
                    builder: (context, ref, _) {
                      final related = ref.watch(
                        relatedProjectsProvider(project.id),
                      );
                      if (related.isEmpty) {
                        return Text(strings.noSimilarProjectsMessage);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final r in related)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: InkWell(
                                onTap: () => pushSlideFade(
                                  context,
                                  ProjectWorkspaceScreen(
                                    projectId: r.project.id,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.project.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      r.reasoning,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- Recent activity (real) ---
        SectionHeader(
          title: strings.recentActivityLabel,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (context, ref, _) {
            final eventsAsync = ref.watch(
              projectEventsByProjectIdProvider(project.id),
            );
            return eventsAsync.when(
              data: (events) {
                if (events.isEmpty) return Text(strings.noRecentActivity);
                final sorted = [...events]
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
                return Column(
                  children: [
                    for (final event in sorted.take(10))
                      _EventTile(event: event, strings: strings),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(strings.errorPrefix(e)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // --- AI Project Insights (no service exists yet) ---
        SectionHeader(
          title: strings.aiExecutiveSummaryTitle,
          accentColor: AppStatusColors.ai,
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      strings.comingInFutureMilestoneTooltip,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _milestoneStateLabel(ProjectMilestoneState state) => switch (state) {
  ProjectMilestoneState.upcoming => 'Upcoming',
  ProjectMilestoneState.dueSoon => 'Due soon',
  ProjectMilestoneState.delayed => 'Delayed',
  ProjectMilestoneState.completed => 'Completed',
};

Color _milestoneStateColor(ColorScheme scheme, ProjectMilestoneState state) =>
    switch (state) {
      ProjectMilestoneState.completed => AppStatusColors.success,
      ProjectMilestoneState.delayed => scheme.error,
      ProjectMilestoneState.dueSoon => AppStatusColors.warning,
      ProjectMilestoneState.upcoming => scheme.outline,
    };

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.strings,
    required this.onTap,
  });

  final ProjectMilestone milestone;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = milestone.state();
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            state == ProjectMilestoneState.completed
                ? Icons.check_circle_outline
                : Icons.flag_outlined,
            color: _milestoneStateColor(theme.colorScheme, state),
          ),
          title: Text(milestone.title),
          subtitle: milestone.dueDate != null
              ? Text(dateFormat.format(milestone.dueDate!))
              : null,
          trailing: Chip(
            label: Text(_milestoneStateLabel(state)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _DeliverableTile extends StatelessWidget {
  const _DeliverableTile({
    required this.deliverable,
    required this.strings,
    required this.onTap,
  });

  final ProjectDeliverable deliverable;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());
    final color = switch (deliverable.status) {
      ProjectDeliverableStatus.completed => AppStatusColors.success,
      ProjectDeliverableStatus.blocked => theme.colorScheme.error,
      ProjectDeliverableStatus.pending =>
        deliverable.isOverdue
            ? theme.colorScheme.error
            : theme.colorScheme.outline,
    };

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.task_alt_outlined, color: color),
          title: Text(deliverable.title),
          subtitle: Text(
            [
              if (deliverable.dueDate != null)
                dateFormat.format(deliverable.dueDate!),
              if (deliverable.status == ProjectDeliverableStatus.blocked &&
                  deliverable.blockedReason != null)
                deliverable.blockedReason!,
            ].join(' · '),
          ),
          trailing: Chip(
            label: Text(
              deliverable.isOverdue &&
                      deliverable.status == ProjectDeliverableStatus.pending
                  ? strings.overdueLabel
                  : deliverable.status.label,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _RiskTile extends StatelessWidget {
  const _RiskTile({
    required this.risk,
    required this.strings,
    required this.onTap,
  });

  final ProjectRisk risk;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (risk.severity) {
      RiskSeverity.critical => theme.colorScheme.error,
      RiskSeverity.high => AppStatusColors.warning,
      RiskSeverity.medium => AppStatusColors.warning,
      RiskSeverity.low => theme.colorScheme.outline,
    };

    return HoverLift(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.warning_amber_outlined, color: color),
          title: Text(risk.title),
          subtitle: Text('${risk.severity.label} · ${risk.likelihood.label}'),
          trailing: Chip(
            label: Text(risk.status.label),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.strings});

  final ProjectEvent event;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString()).add_Hm();

    return ListTile(
      dense: true,
      leading: const Icon(Icons.circle, size: 8),
      title: Text(event.summary),
      subtitle: Text(
        [
          dateFormat.format(event.occurredAt),
          event.actor,
        ].whereType<String>().join(' · '),
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.label,
    required this.status,
    required this.strings,
  });

  final String label;
  final ProjectHealthLevel status;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = switch (status) {
      ProjectHealthLevel.healthy => strings.healthOnTrackLabel,
      ProjectHealthLevel.atRisk => strings.healthAtRiskLabel,
      ProjectHealthLevel.critical => strings.healthCriticalLabel,
    };
    return Chip(
      avatar: Icon(
        Icons.circle,
        size: 10,
        color: _healthColor(theme.colorScheme, status),
      ),
      label: Text('$label: $statusLabel'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.project, required this.strings});

  final Project project;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = project.contractValueCurrency;
    String fmt(double? v) =>
        v == null ? strings.notSetLabel : '$currency ${v.toStringAsFixed(0)}';

    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _BudgetStat(
                label: strings.fieldContractValue,
                value: fmt(project.contractValueAmount),
                theme: theme,
              ),
              _BudgetStat(
                label: strings.budgetSectionTitle,
                value: fmt(project.plannedBudgetAmount),
                theme: theme,
              ),
              _BudgetStat(
                label: strings.currentExpenditureLabel,
                value: fmt(project.currentExpenditureAmount),
                theme: theme,
              ),
              _BudgetStat(
                label: strings.forecastAmountLabel,
                value: fmt(project.forecastAmount),
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  const _BudgetStat({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shown for Milestones/Deliverables/Risks — sections named in the brief
/// with no backing data model anywhere in this codebase. The action button
/// is present (matching the string set already reserved for these
/// features) but only surfaces a "coming later" message rather than
/// silently doing nothing or writing to a collection that doesn't exist.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.message,
    required this.actionLabel,
    required this.strings,
    required this.onAdd,
  });

  final String message;
  final String actionLabel;
  final AppStrings strings;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              TextButton(onPressed: onAdd, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equivalent to project_form_screen.dart's private `_ProjectDocumentTile`
/// — recreated here since that class is private to its own file, but
/// calling the exact same providers/services (no logic duplication, just
/// the same small ListTile shape).
class _WorkspaceDocumentTile extends StatelessWidget {
  const _WorkspaceDocumentTile({
    required this.document,
    required this.strings,
    required this.isExtracting,
    required this.onExtract,
    required this.onReview,
  });

  final LibraryDocument document;
  final AppStrings strings;
  final bool isExtracting;
  final VoidCallback onExtract;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final canExtract =
        document.aiExtractionStatus == DocumentExtractionStatus.none;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(
          document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          strings.documentExtractionStatusLabel(document.aiExtractionStatus),
        ),
        trailing: canExtract
            ? OutlinedButton.icon(
                onPressed: isExtracting ? null : onExtract,
                icon: isExtracting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  isExtracting
                      ? strings.extractingLabel
                      : strings.extractKnowledgeButton,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(strings.reviewAndApplyButton),
              ),
      ),
    );
  }
}

/// Small, genuinely-new dialog — no existing screen edits
/// plannedBudgetAmount/currentExpenditureAmount/forecastAmount (only
/// contractValueAmount is on ProjectFormScreen), so this isn't duplicating
/// anything; it's exposing existing Project/ProjectService fields that
/// have never had a write path.
class _EditBudgetDialog extends ConsumerStatefulWidget {
  const _EditBudgetDialog({required this.project});

  final Project project;

  @override
  ConsumerState<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends ConsumerState<_EditBudgetDialog> {
  late final _plannedController = TextEditingController(
    text: widget.project.plannedBudgetAmount?.toStringAsFixed(0),
  );
  late final _expenditureController = TextEditingController(
    text: widget.project.currentExpenditureAmount?.toStringAsFixed(0),
  );
  late final _forecastController = TextEditingController(
    text: widget.project.forecastAmount?.toStringAsFixed(0),
  );
  bool _saving = false;

  @override
  void dispose() {
    _plannedController.dispose();
    _expenditureController.dispose();
    _forecastController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final planned = double.tryParse(_plannedController.text.trim());
    final expenditure = double.tryParse(_expenditureController.text.trim());
    final forecast = double.tryParse(_forecastController.text.trim());

    await ref
        .read(projectServiceProvider)
        .update(
          widget.project.copyWith(
            plannedBudgetAmount: planned,
            clearPlannedBudgetAmount: planned == null,
            currentExpenditureAmount: expenditure,
            clearCurrentExpenditureAmount: expenditure == null,
            forecastAmount: forecast,
            clearForecastAmount: forecast == null,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(strings.editBudgetButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _plannedController,
            decoration: InputDecoration(labelText: strings.budgetSectionTitle),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _expenditureController,
            decoration: InputDecoration(
              labelText: strings.currentExpenditureLabel,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _forecastController,
            decoration: InputDecoration(labelText: strings.forecastAmountLabel),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}

/// Same rationale as [_EditBudgetDialog] — `lessonsLearned` has been a
/// [Project] field with no write path anywhere in this codebase.
class _EditLessonsLearnedDialog extends ConsumerStatefulWidget {
  const _EditLessonsLearnedDialog({required this.project});

  final Project project;

  @override
  ConsumerState<_EditLessonsLearnedDialog> createState() =>
      _EditLessonsLearnedDialogState();
}

class _EditLessonsLearnedDialogState
    extends ConsumerState<_EditLessonsLearnedDialog> {
  late final _controller = TextEditingController(
    text: widget.project.lessonsLearned,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(projectServiceProvider)
        .update(
          widget.project.copyWith(lessonsLearned: _controller.text.trim()),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(strings.lessonsLearnedSectionTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: strings.lessonsLearnedHint),
          maxLines: 6,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}

/// Reduces every project document's `aiExtracted*` narrative list matching
/// [pick] to one flat, de-duplicated list of candidate titles — the "create
/// from extracted text" chips shown at the top of the Add Milestone/
/// Deliverable/Risk dialogs. Purely a UI convenience for pre-filling the
/// title field with wording the AI already pulled from the document; it
/// never writes anything on its own, and a chosen chip remains fully
/// editable afterward like any manually-typed title.
List<String> _extractedCandidates(
  List<LibraryDocument> documents,
  List<String> Function(LibraryDocument) pick,
) {
  final seen = <String>{};
  final result = <String>[];
  for (final doc in documents) {
    for (final item in pick(doc)) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      result.add(trimmed);
    }
  }
  return result;
}

/// Shared "create from extracted text" strip — shown above the manual-entry
/// fields in each Add dialog so a user working from an uploaded document can
/// tap a bullet the AI already found (a deliverable, a risk) instead of
/// re-typing it, while still being free to type something else entirely.
class _ExtractedCandidatesPicker extends StatelessWidget {
  const _ExtractedCandidatesPicker({
    required this.strings,
    required this.candidates,
    required this.onPicked,
  });

  final AppStrings strings;
  final List<String> candidates;
  final void Function(String) onPicked;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.createFromExtractedSectionLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          strings.createFromExtractedHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final candidate in candidates)
              ActionChip(
                label: Text(
                  candidate.length > 60
                      ? '${candidate.substring(0, 60)}…'
                      : candidate,
                ),
                onPressed: () => onPicked(candidate),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Add/edit a [ProjectMilestone]. Same create-vs-edit shape as
/// [_EditBudgetDialog]: `milestone == null` means creating a new one against
/// [projectId], non-null means editing that milestone in place. Reuses
/// [ProjectMilestoneService] directly — no parallel milestone-writing logic.
class _MilestoneDialog extends ConsumerStatefulWidget {
  const _MilestoneDialog({
    required this.projectId,
    this.milestone,
    this.extractedCandidates = const [],
  });

  final String projectId;
  final ProjectMilestone? milestone;
  final List<String> extractedCandidates;

  @override
  ConsumerState<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends ConsumerState<_MilestoneDialog> {
  late final _titleController = TextEditingController(
    text: widget.milestone?.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.milestone?.description,
  );
  DateTime? _dueDate;
  late bool _completed = widget.milestone?.completedAt != null;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.milestone?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(projectMilestoneServiceProvider);
    final now = DateTime.now();
    final existing = widget.milestone;

    final milestone = ProjectMilestone(
      id: existing?.id ?? '',
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      completedAt: _completed ? (existing?.completedAt ?? now) : null,
      order: existing?.order ?? 0,
      dependsOnMilestoneIds: existing?.dependsOnMilestoneIds ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (existing == null) {
      await service.create(milestone);
    } else {
      await service.update(milestone);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return AlertDialog(
      title: Text(
        widget.milestone == null
            ? strings.addMilestoneButton
            : strings.editMilestoneTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.milestone == null)
              _ExtractedCandidatesPicker(
                strings: strings,
                candidates: widget.extractedCandidates,
                onPicked: (text) => setState(() {
                  _titleController.text = text;
                }),
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: strings.fieldTitle),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: strings.fieldDescription),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.fieldDueDate),
              subtitle: Text(
                _dueDate == null
                    ? strings.notSetLabel
                    : dateFormat.format(_dueDate!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: _pickDueDate,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _completed,
              onChanged: (checked) =>
                  setState(() => _completed = checked ?? false),
              title: Text(strings.fieldMarkCompleted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}

/// Add/edit a [ProjectDeliverable] — same shape as [_MilestoneDialog].
class _DeliverableDialog extends ConsumerStatefulWidget {
  const _DeliverableDialog({
    required this.projectId,
    this.deliverable,
    this.extractedCandidates = const [],
  });

  final String projectId;
  final ProjectDeliverable? deliverable;
  final List<String> extractedCandidates;

  @override
  ConsumerState<_DeliverableDialog> createState() => _DeliverableDialogState();
}

class _DeliverableDialogState extends ConsumerState<_DeliverableDialog> {
  late final _titleController = TextEditingController(
    text: widget.deliverable?.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.deliverable?.description,
  );
  late final _assignedToController = TextEditingController(
    text: widget.deliverable?.assignedTo,
  );
  late final _blockedReasonController = TextEditingController(
    text: widget.deliverable?.blockedReason,
  );
  DateTime? _dueDate;
  late ProjectDeliverableStatus _status =
      widget.deliverable?.status ?? ProjectDeliverableStatus.pending;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.deliverable?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assignedToController.dispose();
    _blockedReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(projectDeliverableServiceProvider);
    final now = DateTime.now();
    final existing = widget.deliverable;

    final deliverable = ProjectDeliverable(
      id: existing?.id ?? '',
      projectId: widget.projectId,
      milestoneId: existing?.milestoneId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      completedAt: _status == ProjectDeliverableStatus.completed
          ? (existing?.completedAt ?? now)
          : null,
      status: _status,
      assignedTo: _assignedToController.text.trim().isEmpty
          ? null
          : _assignedToController.text.trim(),
      blockedReason: _status == ProjectDeliverableStatus.blocked
          ? (_blockedReasonController.text.trim().isEmpty
                ? null
                : _blockedReasonController.text.trim())
          : null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (existing == null) {
      await service.create(deliverable);
    } else {
      await service.update(deliverable);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return AlertDialog(
      title: Text(
        widget.deliverable == null
            ? strings.addDeliverableButton
            : strings.editDeliverableTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.deliverable == null)
              _ExtractedCandidatesPicker(
                strings: strings,
                candidates: widget.extractedCandidates,
                onPicked: (text) => setState(() {
                  _titleController.text = text;
                }),
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: strings.fieldTitle),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: strings.fieldDescription),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.fieldDueDate),
              subtitle: Text(
                _dueDate == null
                    ? strings.notSetLabel
                    : dateFormat.format(_dueDate!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _assignedToController,
              decoration: InputDecoration(labelText: strings.fieldAssignedTo),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ProjectDeliverableStatus>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: strings.fieldDeliverableStatus,
              ),
              items: ProjectDeliverableStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(strings.deliverableStatusLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
            if (_status == ProjectDeliverableStatus.blocked) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _blockedReasonController,
                decoration: InputDecoration(
                  labelText: strings.fieldBlockedReason,
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}

/// Add/edit a [ProjectRisk] — same shape as [_MilestoneDialog]/
/// [_DeliverableDialog].
class _RiskDialog extends ConsumerStatefulWidget {
  const _RiskDialog({
    required this.projectId,
    this.risk,
    this.extractedCandidates = const [],
  });

  final String projectId;
  final ProjectRisk? risk;
  final List<String> extractedCandidates;

  @override
  ConsumerState<_RiskDialog> createState() => _RiskDialogState();
}

class _RiskDialogState extends ConsumerState<_RiskDialog> {
  late final _titleController = TextEditingController(text: widget.risk?.title);
  late final _descriptionController = TextEditingController(
    text: widget.risk?.description,
  );
  late final _ownerController = TextEditingController(text: widget.risk?.owner);
  late final _mitigationController = TextEditingController(
    text: widget.risk?.mitigationActions.join('\n'),
  );
  late RiskSeverity _severity = widget.risk?.severity ?? RiskSeverity.medium;
  late RiskLikelihood _likelihood =
      widget.risk?.likelihood ?? RiskLikelihood.medium;
  late RiskStatus _status = widget.risk?.status ?? RiskStatus.open;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ownerController.dispose();
    _mitigationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(projectRiskServiceProvider);
    final now = DateTime.now();
    final existing = widget.risk;

    final risk = ProjectRisk(
      id: existing?.id ?? '',
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      severity: _severity,
      likelihood: _likelihood,
      status: _status,
      owner: _ownerController.text.trim().isEmpty
          ? null
          : _ownerController.text.trim(),
      mitigationActions: _mitigationController.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(),
      identifiedAt: existing?.identifiedAt ?? now,
      resolvedAt: _status == RiskStatus.closed
          ? (existing?.resolvedAt ?? now)
          : null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (existing == null) {
      await service.create(risk);
    } else {
      await service.update(risk);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(
        widget.risk == null ? strings.addRiskButton : strings.editRiskTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.risk == null)
              _ExtractedCandidatesPicker(
                strings: strings,
                candidates: widget.extractedCandidates,
                onPicked: (text) => setState(() {
                  _titleController.text = text;
                }),
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: strings.fieldTitle),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: strings.fieldDescription),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<RiskSeverity>(
              initialValue: _severity,
              decoration: InputDecoration(labelText: strings.fieldSeverity),
              items: RiskSeverity.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(strings.riskSeverityLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() => _severity = s ?? _severity),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<RiskLikelihood>(
              initialValue: _likelihood,
              decoration: InputDecoration(labelText: strings.fieldLikelihood),
              items: RiskLikelihood.values
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(strings.riskLikelihoodLabel(l)),
                    ),
                  )
                  .toList(),
              onChanged: (l) => setState(() => _likelihood = l ?? _likelihood),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<RiskStatus>(
              initialValue: _status,
              decoration: InputDecoration(labelText: strings.fieldRiskStatus),
              items: RiskStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(strings.riskStatusLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ownerController,
              decoration: InputDecoration(labelText: strings.fieldOwner),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _mitigationController,
              decoration: InputDecoration(
                labelText: strings.fieldMitigationActions,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}
