import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/proposal_generation_service.dart';
import 'package:jva_projecttracker/services/proposal_section_suggestions.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/proposal_section_style.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';

/// One section of a proposal, collapsed to a single glanceable row by
/// default (title, status chip, one-line preview) and expanding in place
/// to an inline editor — no separate editor screen/navigation hop, so
/// editing a proposal feels like a modern workspace document rather than a
/// page of CRUD forms. Content and title auto-save on a short debounce (and
/// immediately on blur), the same "no explicit save button" feel as
/// Notion/Google Docs. See ADR-008.
///
/// Milestone 4.2 (AI Proposal Generation Engine) adds real AI authoring:
/// Generate/Regenerate/Improve/Expand/Shorten call
/// `ProposalGenerationService`, which reasons over the opportunity's full
/// AI chain + Company Knowledge Graph (never the opportunity alone) and
/// writes back provenance (`aiSource*Ids`, rendered via
/// `RecommendedEntityChips`) and a confidence score. Overwriting a section
/// with real human edits (`edited`/`approved`) always asks for confirmation
/// first; the server always keeps a single-slot previous version so
/// "Restore previous version" is possible either way.
class ProposalSectionCard extends ConsumerStatefulWidget {
  const ProposalSectionCard({
    super.key,
    required this.section,
    required this.opportunity,
    required this.dragHandleIndex,
    this.onDelete,
  });

  final ProposalSection section;
  final Opportunity opportunity;
  final int dragHandleIndex;
  final VoidCallback? onDelete;

  @override
  ConsumerState<ProposalSectionCard> createState() =>
      _ProposalSectionCardState();
}

class _ProposalSectionCardState extends ConsumerState<ProposalSectionCard> {
  static const _debounceDelay = Duration(milliseconds: 600);

  bool _expanded = false;
  ProposalGenerationMode? _generatingMode;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _assignedToController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  late final FocusNode _assignedToFocusNode;
  Timer? _titleDebounce;
  Timer? _contentDebounce;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.section.title);
    _contentController = TextEditingController(text: widget.section.content);
    _assignedToController = TextEditingController(
      text: widget.section.assignedTo,
    );
    _titleFocusNode = FocusNode()..addListener(_onTitleFocusChange);
    _contentFocusNode = FocusNode()..addListener(_onContentFocusChange);
    _assignedToFocusNode = FocusNode()..addListener(_onAssignedToFocusChange);
  }

  @override
  void didUpdateWidget(covariant ProposalSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The card is keyed per section id and stays alive across rebuilds, so
    // an externally-driven change (AI generation writing new content, a
    // restore, another device's edit) needs to be reflected into the
    // controllers explicitly — but never while the user is actively typing
    // in that same field.
    if (widget.section.content != oldWidget.section.content &&
        !_contentFocusNode.hasFocus) {
      _contentController.text = widget.section.content;
    }
    if (widget.section.title != oldWidget.section.title &&
        !_titleFocusNode.hasFocus) {
      _titleController.text = widget.section.title;
    }
    if (widget.section.assignedTo != oldWidget.section.assignedTo &&
        !_assignedToFocusNode.hasFocus) {
      _assignedToController.text = widget.section.assignedTo ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _assignedToController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _assignedToFocusNode.dispose();
    _titleDebounce?.cancel();
    _contentDebounce?.cancel();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus) _flushTitle();
  }

  void _onContentFocusChange() {
    if (!_contentFocusNode.hasFocus) _flushContent();
  }

  void _onAssignedToFocusChange() {
    if (!_assignedToFocusNode.hasFocus) _flushAssignedTo();
  }

  void _flushAssignedTo() {
    final value = _assignedToController.text.trim();
    ref
        .read(proposalSectionServiceProvider)
        .updateAssignedTo(widget.section.id, value.isEmpty ? null : value);
  }

  void _flushTitle() {
    _titleDebounce?.cancel();
    ref
        .read(proposalSectionServiceProvider)
        .updateTitle(widget.section.id, _titleController.text);
  }

  void _flushContent() {
    _contentDebounce?.cancel();
    ref
        .read(proposalSectionServiceProvider)
        .updateContent(widget.section.id, _contentController.text);
  }

  void _onTitleChanged(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(_debounceDelay, _flushTitle);
  }

  void _onContentChanged(String value) {
    _contentDebounce?.cancel();
    _contentDebounce = Timer(_debounceDelay, _flushContent);
  }

  Future<bool> _confirmOverwriteIfNeeded() async {
    final section = widget.section;
    final protectedStatus =
        section.status == ProposalSectionStatus.edited ||
        section.status == ProposalSectionStatus.approved;
    if (!protectedStatus) return true;

    final strings = ref.read(appStringsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.overwriteConfirmTitle),
        content: Text(strings.overwriteConfirmBody),
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

  Future<void> _runGeneration(ProposalGenerationMode mode) async {
    final proceed = await _confirmOverwriteIfNeeded();
    if (!proceed) return;

    setState(() => _generatingMode = mode);
    try {
      await ref
          .read(proposalGenerationServiceProvider)
          .generateSection(sectionId: widget.section.id, mode: mode);
    } on ProposalGenerationException catch (e) {
      if (mounted) {
        final strings = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.proposalGenerationFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingMode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final section = widget.section;
    final (background, foreground, icon) = proposalSectionStatusStyle(
      theme.colorScheme,
      section.status,
    );
    final isGenerating = _generatingMode != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.dragHandleIndex,
                  child: const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.drag_indicator, size: 20),
                  ),
                ),
                Icon(
                  proposalSectionTypeIcon(section.type),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Chip(
                  avatar: Icon(icon, size: 16, color: foreground),
                  label: Text(
                    strings.proposalSectionStatusLabel(section.status),
                  ),
                  backgroundColor: background,
                  labelStyle: TextStyle(color: foreground),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            if (!_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: AppSpacing.xs),
                child: Text(
                  section.content.isEmpty
                      ? strings.sectionEmptyPreview
                      : section.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: theme.textTheme.titleSmall,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: strings.fieldSectionTitle,
                ),
                onChanged: _onTitleChanged,
                onSubmitted: (_) => _flushTitle(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                minLines: 4,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: strings.sectionContentHint,
                ),
                onChanged: _onContentChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _assignedToController,
                focusNode: _assignedToFocusNode,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: strings.fieldAssignedTo,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
                onSubmitted: (_) => _flushAssignedTo(),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (section.status == ProposalSectionStatus.edited)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    strings.manuallyEditedLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (section.aiConfidence != null || section.aiGeneratedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (section.aiConfidence != null)
                        Chip(
                          label: Text(
                            strings.confidenceScoreChipLabel(
                              section.aiConfidence!,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (section.aiGeneratedAt != null)
                        Text(
                          strings.lastAiGenerationLabel(
                            DateFormat.yMMMd(
                              strings.locale.languageCode,
                            ).format(section.aiGeneratedAt!),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              if (section.aiGeneratedAt != null) ...[
                Text(
                  strings.generatedFromLabel,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                RecommendedEntityChips<BusinessUnit>(
                  label: strings.relatedBusinessUnitsLabel,
                  ids: section.aiSourceBusinessUnitIds,
                  optionsAsync: ref.watch(businessUnitsStreamProvider),
                  idOf: (b) => b.id,
                  nameOf: (b) => b.name,
                ),
                RecommendedEntityChips<Product>(
                  label: strings.relatedProductsLabel,
                  ids: section.aiSourceProductIds,
                  optionsAsync: ref.watch(productsStreamProvider),
                  idOf: (p) => p.id,
                  nameOf: (p) => p.name,
                ),
                RecommendedEntityChips<ServiceModel>(
                  label: strings.servicesTitle,
                  ids: section.aiSourceServiceIds,
                  optionsAsync: ref.watch(servicesStreamProvider),
                  idOf: (s) => s.id,
                  nameOf: (s) => s.name,
                ),
                RecommendedEntityChips<Capability>(
                  label: strings.relatedCapabilitiesLabel,
                  ids: section.aiSourceCapabilityIds,
                  optionsAsync: ref.watch(capabilitiesStreamProvider),
                  idOf: (c) => c.id,
                  nameOf: (c) => c.name,
                ),
                RecommendedEntityChips<Technology>(
                  label: strings.relatedTechnologiesLabel,
                  ids: section.aiSourceTechnologyIds,
                  optionsAsync: ref.watch(technologiesStreamProvider),
                  idOf: (t) => t.id,
                  nameOf: (t) => t.name,
                ),
                RecommendedEntityChips<Industry>(
                  label: strings.relatedIndustriesLabel,
                  ids: section.aiSourceIndustryIds,
                  optionsAsync: ref.watch(industriesStreamProvider),
                  idOf: (i) => i.id,
                  nameOf: (i) => i.name,
                ),
                RecommendedEntityChips<Experience>(
                  label: strings.relatedExperiencesLabel,
                  ids: section.aiSourceExperienceIds,
                  optionsAsync: ref.watch(experiencesStreamProvider),
                  idOf: (e) => e.id,
                  nameOf: (e) => e.title,
                ),
                RecommendedEntityChips<KnowledgeArticle>(
                  label: strings.relatedKnowledgeArticlesLabel,
                  ids: section.aiSourceKnowledgeArticleIds,
                  optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
                  idOf: (k) => k.id,
                  nameOf: (k) => k.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildSuggestions(context, strings),
              ],
              const SizedBox(height: AppSpacing.sm),
              _buildGenerationActions(strings, isGenerating),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (section.status == ProposalSectionStatus.approved)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(proposalSectionServiceProvider)
                          .updateStatus(
                            section.id,
                            ProposalSectionStatus.edited,
                          ),
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(strings.reopenSectionButton),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => ref
                          .read(proposalSectionServiceProvider)
                          .updateStatus(
                            section.id,
                            ProposalSectionStatus.approved,
                          ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(strings.markSectionApprovedButton),
                    ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: strings.deleteTooltip,
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, AppStrings strings) {
    final suggestions = deriveSectionSuggestions(
      opportunity: widget.opportunity,
      section: widget.section,
      experiences: ref.watch(experiencesStreamProvider).value ?? const [],
      technologies: ref.watch(technologiesStreamProvider).value ?? const [],
      knowledgeArticles:
          ref.watch(knowledgeArticlesStreamProvider).value ?? const [],
      capabilities: ref.watch(capabilitiesStreamProvider).value ?? const [],
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.suggestionsSectionLabel,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final suggestion in suggestions)
                Chip(
                  label: Text(
                    strings.suggestionLabel(
                      suggestion.category,
                      suggestion.entityName,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationActions(AppStrings strings, bool isGenerating) {
    final section = widget.section;

    if (section.content.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: isGenerating
              ? null
              : () => _runGeneration(ProposalGenerationMode.generate),
          icon: _generatingMode == ProposalGenerationMode.generate
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(strings.generateWithAiButton),
        ),
      );
    }

    Widget actionButton(
      ProposalGenerationMode mode,
      IconData icon,
      String label,
    ) {
      return OutlinedButton.icon(
        onPressed: isGenerating ? null : () => _runGeneration(mode),
        icon: _generatingMode == mode
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        actionButton(
          ProposalGenerationMode.regenerate,
          Icons.auto_awesome,
          strings.regenerateButton,
        ),
        actionButton(
          ProposalGenerationMode.improve,
          Icons.auto_fix_high_outlined,
          strings.improveButton,
        ),
        actionButton(
          ProposalGenerationMode.expand,
          Icons.unfold_more,
          strings.expandButton,
        ),
        actionButton(
          ProposalGenerationMode.shorten,
          Icons.unfold_less,
          strings.shortenButton,
        ),
        if (section.previousContent != null)
          TextButton.icon(
            onPressed: isGenerating
                ? null
                : () => ref
                      .read(proposalSectionServiceProvider)
                      .restorePreviousVersion(section),
            icon: const Icon(Icons.history, size: 18),
            label: Text(strings.restorePreviousVersionButton),
          ),
      ],
    );
  }
}
