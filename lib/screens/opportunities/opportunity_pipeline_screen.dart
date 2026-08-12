import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/opportunity_timeline.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/pipeline_stage_badge.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:jva_projecttracker/widgets/stage_transition_dialog.dart';

/// Editor for an opportunity's workflow: current pipeline stage (changed via
/// [showStageTransitionDialog], which also writes the corresponding
/// [OpportunityEvent] — see [OpportunityService.transitionStage]), plus the
/// review/qualification notes, assignment, and dates that accompany that
/// workflow. The [OpportunityTimeline] at the bottom is the read-only
/// pipeline history built from those same transitions.
class OpportunityPipelineScreen extends ConsumerStatefulWidget {
  const OpportunityPipelineScreen({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  ConsumerState<OpportunityPipelineScreen> createState() =>
      _OpportunityPipelineScreenState();
}

class _OpportunityPipelineScreenState
    extends ConsumerState<OpportunityPipelineScreen> {
  final _assignedToController = TextEditingController();
  final _reviewNotesController = TextEditingController();
  final _qualificationNotesController = TextEditingController();
  final _closedReasonController = TextEditingController();

  DateTime? _submittedDate;
  DateTime? _decisionDate;

  bool _saving = false;
  bool _initialized = false;
  Opportunity? _loaded;

  void _seedFrom(Opportunity? o) {
    if (_initialized || o == null) return;
    _initialized = true;
    _loaded = o;
    _assignedToController.text = o.assignedTo ?? '';
    _reviewNotesController.text = o.reviewNotes ?? '';
    _qualificationNotesController.text = o.qualificationNotes ?? '';
    _closedReasonController.text = o.closedReason ?? '';
    _submittedDate = o.submittedDate;
    _decisionDate = o.decisionDate;
  }

  @override
  void dispose() {
    _assignedToController.dispose();
    _reviewNotesController.dispose();
    _qualificationNotesController.dispose();
    _closedReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isSubmitted}) async {
    final initial =
        (isSubmitted ? _submittedDate : _decisionDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isSubmitted) {
        _submittedDate = picked;
      } else {
        _decisionDate = picked;
      }
    });
  }

  Future<void> _changeStage() async {
    final loaded = _loaded;
    if (loaded == null) return;
    final result = await showStageTransitionDialog(
      context,
      currentStage: loaded.pipelineStage,
    );
    if (result == null) return;

    final actor = ref.read(authStateChangesProvider).value?.email;
    await ref
        .read(opportunityServiceProvider)
        .transitionStage(
          opportunityId: widget.opportunityId,
          newStage: result.stage,
          note: result.note,
          actor: actor,
        );
  }

  Future<void> _save() async {
    final loaded = _loaded;
    if (loaded == null) return;
    setState(() => _saving = true);

    final assignedTo = _assignedToController.text.trim();
    final reviewNotes = _reviewNotesController.text.trim();
    final qualificationNotes = _qualificationNotesController.text.trim();
    final closedReason = _closedReasonController.text.trim();

    await ref
        .read(opportunityServiceProvider)
        .update(
          Opportunity(
            id: loaded.id,
            title: loaded.title,
            description: loaded.description,
            sourceUrl: loaded.sourceUrl,
            client: loaded.client,
            deadline: loaded.deadline,
            status: loaded.status,
            fitScorePercent: loaded.fitScorePercent,
            fitReasoning: loaded.fitReasoning,
            tags: loaded.tags,
            discoveredAt: loaded.discoveredAt,
            updatedAt: DateTime.now(),
            classificationStatus: loaded.classificationStatus,
            classificationSummary: loaded.classificationSummary,
            industryIds: loaded.industryIds,
            technologyIds: loaded.technologyIds,
            businessUnitIds: loaded.businessUnitIds,
            productIds: loaded.productIds,
            serviceIds: loaded.serviceIds,
            capabilityIds: loaded.capabilityIds,
            experienceIds: loaded.experienceIds,
            knowledgeArticleIds: loaded.knowledgeArticleIds,
            opportunityType: loaded.opportunityType,
            estimatedBudget: loaded.estimatedBudget,
            estimatedDuration: loaded.estimatedDuration,
            estimatedComplexity: loaded.estimatedComplexity,
            confidenceScore: loaded.confidenceScore,
            riskLevel: loaded.riskLevel,
            priority: loaded.priority,
            aiReviewedAt: loaded.aiReviewedAt,
            pipelineStage: loaded.pipelineStage,
            assignedTo: assignedTo.isEmpty ? null : assignedTo,
            reviewNotes: reviewNotes.isEmpty ? null : reviewNotes,
            qualificationNotes: qualificationNotes.isEmpty
                ? null
                : qualificationNotes,
            submittedDate: _submittedDate,
            decisionDate: _decisionDate,
            closedReason: closedReason.isEmpty ? null : closedReason,
            lastStageUpdated: loaded.lastStageUpdated,
          ),
        );

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final opportunityAsync = ref.watch(
      opportunityByIdProvider(widget.opportunityId),
    );
    final loaded = opportunityAsync.value;
    if (loaded != null) _seedFrom(loaded);

    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: PageHeader(
                    icon: Icons.timeline_outlined,
                    title: strings.pipelineScreenTitle,
                  ),
                ),
                Expanded(
                  child: _buildBody(context, strings, loaded ?? _loaded!),
                ),
              ],
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppStrings strings,
    Opportunity opportunity,
  ) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          strings.currentStageLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            PipelineStageBadge(stage: opportunity.pipelineStage),
            const SizedBox(width: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: _changeStage,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(strings.changeStageButton),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.sectionPipelineDetails),
        TextFormField(
          controller: _assignedToController,
          decoration: InputDecoration(labelText: strings.fieldAssignedTo),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _reviewNotesController,
          decoration: InputDecoration(labelText: strings.fieldReviewNotes),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _qualificationNotesController,
          decoration: InputDecoration(
            labelText: strings.fieldQualificationNotes,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AdaptiveFieldRow(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.input),
              onTap: () => _pickDate(isSubmitted: true),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: strings.fieldSubmittedDate,
                ),
                child: Text(
                  _submittedDate == null
                      ? ''
                      : dateFormat.format(_submittedDate!),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.input),
              onTap: () => _pickDate(isSubmitted: false),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: strings.fieldDecisionDate,
                ),
                child: Text(
                  _decisionDate == null
                      ? ''
                      : dateFormat.format(_decisionDate!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _closedReasonController,
          decoration: InputDecoration(labelText: strings.fieldClosedReason),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.pipelineHistoryTitle),
        OpportunityTimeline(opportunityId: widget.opportunityId),
      ],
    );
  }
}
