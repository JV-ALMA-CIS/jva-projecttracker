import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:jva_projecttracker/services/ai_classification_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Manual editor for the Opportunity Intelligence fields added in
/// Milestone 3.1 (classification status, confidence/risk/priority,
/// estimated budget/duration/complexity, and the knowledge-graph
/// relationships), now also the home of Milestone 3.3's "Run AI
/// Classification" action. AI and manual edits share every field below on
/// purpose: running AI just populates the same fields the user could
/// already edit by hand, and the result stays fully editable afterward —
/// see [_runAIClassification] and ADR-003. `aiReviewedAt` itself still
/// isn't exposed for manual editing — it's a signal of when AI last
/// touched the record, not something a person should be able to fake.
class OpportunityClassificationScreen extends ConsumerStatefulWidget {
  const OpportunityClassificationScreen({
    super.key,
    required this.opportunityId,
  });

  final String opportunityId;

  @override
  ConsumerState<OpportunityClassificationScreen> createState() =>
      _OpportunityClassificationScreenState();
}

class _OpportunityClassificationScreenState
    extends ConsumerState<OpportunityClassificationScreen> {
  final _classificationSummaryController = TextEditingController();
  final _opportunityTypeController = TextEditingController();
  final _estimatedBudgetController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _confidenceScoreController = TextEditingController();

  ClassificationStatus _classificationStatus =
      ClassificationStatus.notClassified;
  EstimatedComplexity? _estimatedComplexity;
  RiskLevel? _riskLevel;
  OpportunityPriority? _priority;
  Set<String> _industryIds = {};
  Set<String> _technologyIds = {};
  Set<String> _businessUnitIds = {};
  Set<String> _productIds = {};
  Set<String> _serviceIds = {};
  Set<String> _capabilityIds = {};
  Set<String> _experienceIds = {};
  Set<String> _knowledgeArticleIds = {};

  bool _saving = false;
  bool _classifying = false;
  bool _initialized = false;
  Opportunity? _loaded;
  DateTime? _aiReviewedAt;

  void _seedFrom(Opportunity? o) {
    if (_initialized || o == null) return;
    _initialized = true;
    _loaded = o;
    _classificationSummaryController.text = o.classificationSummary ?? '';
    _opportunityTypeController.text = o.opportunityType ?? '';
    _estimatedBudgetController.text = o.estimatedBudget == null
        ? ''
        : o.estimatedBudget!.toStringAsFixed(0);
    _estimatedDurationController.text = o.estimatedDuration ?? '';
    _confidenceScoreController.text = o.confidenceScore?.toString() ?? '';
    _classificationStatus = o.classificationStatus;
    _estimatedComplexity = o.estimatedComplexity;
    _riskLevel = o.riskLevel;
    _priority = o.priority;
    _industryIds = o.industryIds.toSet();
    _technologyIds = o.technologyIds.toSet();
    _businessUnitIds = o.businessUnitIds.toSet();
    _productIds = o.productIds.toSet();
    _serviceIds = o.serviceIds.toSet();
    _capabilityIds = o.capabilityIds.toSet();
    _experienceIds = o.experienceIds.toSet();
    _knowledgeArticleIds = o.knowledgeArticleIds.toSet();
    _aiReviewedAt = o.aiReviewedAt;
  }

  /// Runs AI classification via [AIClassificationService], then applies the
  /// returned result directly to this screen's own state — rather than
  /// waiting for the live Firestore stream to catch up — so the user sees
  /// the new summary/relationships/confidence immediately. Every field it
  /// touches remains exactly as editable afterward as it was before; AI
  /// just fills in a starting point (see the class doc comment and
  /// ADR-003).
  Future<void> _runAIClassification() async {
    setState(() => _classifying = true);
    final strings = ref.read(appStringsProvider);
    try {
      final result = await ref
          .read(aiClassificationServiceProvider)
          .classifyOpportunity(widget.opportunityId);
      if (!mounted) return;
      setState(() {
        _classificationSummaryController.text = result.classificationSummary;
        _industryIds = result.industryIds.toSet();
        _technologyIds = result.technologyIds.toSet();
        _businessUnitIds = result.businessUnitIds.toSet();
        _productIds = result.productIds.toSet();
        _serviceIds = result.serviceIds.toSet();
        _capabilityIds = result.capabilityIds.toSet();
        _experienceIds = result.experienceIds.toSet();
        _knowledgeArticleIds = result.knowledgeArticleIds.toSet();
        _estimatedComplexity = result.estimatedComplexity;
        _priority = result.priority;
        _riskLevel = result.riskLevel;
        _confidenceScoreController.text =
            result.confidenceScore?.toString() ?? '';
        _classificationStatus = result.classificationStatus;
        _aiReviewedAt = result.aiReviewedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.aiClassificationSucceeded)),
      );
    } on AIClassificationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiClassificationFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  @override
  void dispose() {
    _classificationSummaryController.dispose();
    _opportunityTypeController.dispose();
    _estimatedBudgetController.dispose();
    _estimatedDurationController.dispose();
    _confidenceScoreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loaded = _loaded;
    if (loaded == null) return;
    setState(() => _saving = true);

    final classificationSummary = _classificationSummaryController.text.trim();
    final opportunityType = _opportunityTypeController.text.trim();
    final estimatedDuration = _estimatedDurationController.text.trim();
    final estimatedBudget = double.tryParse(
      _estimatedBudgetController.text.trim(),
    );
    final confidenceScore = int.tryParse(
      _confidenceScoreController.text.trim(),
    );

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
            classificationStatus: _classificationStatus,
            classificationSummary: classificationSummary.isEmpty
                ? null
                : classificationSummary,
            industryIds: _industryIds.toList(),
            technologyIds: _technologyIds.toList(),
            businessUnitIds: _businessUnitIds.toList(),
            productIds: _productIds.toList(),
            serviceIds: _serviceIds.toList(),
            capabilityIds: _capabilityIds.toList(),
            experienceIds: _experienceIds.toList(),
            knowledgeArticleIds: _knowledgeArticleIds.toList(),
            opportunityType: opportunityType.isEmpty ? null : opportunityType,
            estimatedBudget: estimatedBudget,
            estimatedDuration: estimatedDuration.isEmpty
                ? null
                : estimatedDuration,
            estimatedComplexity: _estimatedComplexity,
            confidenceScore: confidenceScore,
            riskLevel: _riskLevel,
            priority: _priority,
            aiReviewedAt: _aiReviewedAt,
          ),
        );

    if (mounted) Navigator.of(context).pop();
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
                    icon: Icons.psychology_outlined,
                    title: strings.editClassificationTitle,
                  ),
                ),
                Expanded(child: _buildForm(context, strings)),
              ],
            ),
    );
  }

  Widget _buildForm(BuildContext context, AppStrings strings) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SectionHeader(title: strings.sectionClassification),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _classifying ? null : _runAIClassification,
              icon: _classifying
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(strings.runAiClassificationButton),
            ),
            if (_confidenceScoreController.text.isNotEmpty)
              Chip(
                label: Text(
                  strings.confidenceScoreChipLabel(
                    int.parse(_confidenceScoreController.text),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _aiReviewedAt != null
              ? strings.lastAiReviewLabel(
                  DateFormat.yMMMd(
                    strings.locale.toString(),
                  ).add_Hm().format(_aiReviewedAt!),
                )
              : strings.neverReviewedByAiLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<ClassificationStatus>(
          initialValue: _classificationStatus,
          decoration: InputDecoration(
            labelText: strings.fieldClassificationStatus,
          ),
          items: ClassificationStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(strings.classificationStatusLabel(s)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(
            () => _classificationStatus = v ?? _classificationStatus,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _classificationSummaryController,
          decoration: InputDecoration(
            labelText: strings.fieldClassificationSummary,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AdaptiveFieldRow(
          children: [
            DropdownButtonFormField<OpportunityPriority?>(
              initialValue: _priority,
              decoration: InputDecoration(labelText: strings.fieldPriority),
              items: [
                DropdownMenuItem(value: null, child: Text(strings.notSetLabel)),
                for (final p in OpportunityPriority.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(strings.opportunityPriorityLabel(p)),
                  ),
              ],
              onChanged: (v) => setState(() => _priority = v),
            ),
            DropdownButtonFormField<RiskLevel?>(
              initialValue: _riskLevel,
              decoration: InputDecoration(labelText: strings.fieldRiskLevel),
              items: [
                DropdownMenuItem(value: null, child: Text(strings.notSetLabel)),
                for (final r in RiskLevel.values)
                  DropdownMenuItem(
                    value: r,
                    child: Text(strings.riskLevelLabel(r)),
                  ),
              ],
              onChanged: (v) => setState(() => _riskLevel = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AdaptiveFieldRow(
          children: [
            DropdownButtonFormField<EstimatedComplexity?>(
              initialValue: _estimatedComplexity,
              decoration: InputDecoration(
                labelText: strings.fieldEstimatedComplexity,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(strings.notSetLabel)),
                for (final c in EstimatedComplexity.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text(strings.estimatedComplexityLabel(c)),
                  ),
              ],
              onChanged: (v) => setState(() => _estimatedComplexity = v),
            ),
            TextFormField(
              controller: _confidenceScoreController,
              decoration: InputDecoration(
                labelText: strings.fieldConfidenceScore,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.sectionDetails),
        AdaptiveFieldRow(
          children: [
            TextFormField(
              controller: _opportunityTypeController,
              decoration: InputDecoration(
                labelText: strings.fieldOpportunityType,
              ),
            ),
            TextFormField(
              controller: _estimatedDurationController,
              decoration: InputDecoration(
                labelText: strings.fieldEstimatedDuration,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _estimatedBudgetController,
          decoration: InputDecoration(labelText: strings.fieldEstimatedBudget),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: strings.sectionRelationships),
        RelationshipPicker<BusinessUnit>(
          label: strings.relatedBusinessUnitsLabel,
          optionsAsync: ref.watch(businessUnitsStreamProvider),
          idOf: (u) => u.id,
          nameOf: (u) => u.name,
          selectedIds: _businessUnitIds,
          onToggle: (id, selected) => setState(() {
            _businessUnitIds = selected
                ? {..._businessUnitIds, id}
                : ({..._businessUnitIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<Product>(
          label: strings.relatedProductsLabel,
          optionsAsync: ref.watch(productsStreamProvider),
          idOf: (p) => p.id,
          nameOf: (p) => p.name,
          selectedIds: _productIds,
          onToggle: (id, selected) => setState(() {
            _productIds = selected
                ? {..._productIds, id}
                : ({..._productIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<ServiceModel>(
          label: strings.relatedServicesLabel,
          optionsAsync: ref.watch(servicesStreamProvider),
          idOf: (s) => s.id,
          nameOf: (s) => s.name,
          selectedIds: _serviceIds,
          onToggle: (id, selected) => setState(() {
            _serviceIds = selected
                ? {..._serviceIds, id}
                : ({..._serviceIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<Capability>(
          label: strings.relatedCapabilitiesLabel,
          optionsAsync: ref.watch(capabilitiesStreamProvider),
          idOf: (c) => c.id,
          nameOf: (c) => c.name,
          selectedIds: _capabilityIds,
          onToggle: (id, selected) => setState(() {
            _capabilityIds = selected
                ? {..._capabilityIds, id}
                : ({..._capabilityIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<Technology>(
          label: strings.relatedTechnologiesLabel,
          optionsAsync: ref.watch(technologiesStreamProvider),
          idOf: (t) => t.id,
          nameOf: (t) => t.name,
          selectedIds: _technologyIds,
          onToggle: (id, selected) => setState(() {
            _technologyIds = selected
                ? {..._technologyIds, id}
                : ({..._technologyIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<Industry>(
          label: strings.relatedIndustriesLabel,
          optionsAsync: ref.watch(industriesStreamProvider),
          idOf: (i) => i.id,
          nameOf: (i) => i.name,
          selectedIds: _industryIds,
          onToggle: (id, selected) => setState(() {
            _industryIds = selected
                ? {..._industryIds, id}
                : ({..._industryIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<Experience>(
          label: strings.relatedExperiencesLabel,
          optionsAsync: ref.watch(experiencesStreamProvider),
          idOf: (e) => e.id,
          nameOf: (e) => e.title,
          selectedIds: _experienceIds,
          onToggle: (id, selected) => setState(() {
            _experienceIds = selected
                ? {..._experienceIds, id}
                : ({..._experienceIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        RelationshipPicker<KnowledgeArticle>(
          label: strings.relatedKnowledgeArticlesLabel,
          optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
          idOf: (a) => a.id,
          nameOf: (a) => a.title,
          selectedIds: _knowledgeArticleIds,
          onToggle: (id, selected) => setState(() {
            _knowledgeArticleIds = selected
                ? {..._knowledgeArticleIds, id}
                : ({..._knowledgeArticleIds}..remove(id));
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
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
