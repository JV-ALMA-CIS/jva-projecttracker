import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class KnowledgeFormScreen extends ConsumerStatefulWidget {
  const KnowledgeFormScreen({super.key, this.articleId});

  final String? articleId;

  @override
  ConsumerState<KnowledgeFormScreen> createState() =>
      _KnowledgeFormScreenState();
}

class _KnowledgeFormScreenState extends ConsumerState<KnowledgeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  KnowledgeArticleStatus _status = KnowledgeArticleStatus.active;
  Set<String> _businessUnitIds = {};
  Set<String> _productIds = {};
  Set<String> _serviceIds = {};
  Set<String> _capabilityIds = {};
  Set<String> _technologyIds = {};
  Set<String> _industryIds = {};
  Set<String> _experienceIds = {};

  bool _saving = false;
  bool _initialized = false;
  KnowledgeArticle? _loaded;

  bool get _isEditing => widget.articleId != null;

  void _seedFrom(KnowledgeArticle? a) {
    if (_initialized || a == null) return;
    _initialized = true;
    _loaded = a;
    _titleController.text = a.title;
    _categoryController.text = a.category;
    _summaryController.text = a.summary;
    _contentController.text = a.content;
    _tagsController.text = a.tags.join(', ');
    _status = a.status;
    _businessUnitIds = a.businessUnitIds.toSet();
    _productIds = a.productIds.toSet();
    _serviceIds = a.serviceIds.toSet();
    _capabilityIds = a.capabilityIds.toSet();
    _technologyIds = a.technologyIds.toSet();
    _industryIds = a.industryIds.toSet();
    _experienceIds = a.experienceIds.toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(knowledgeServiceProvider);
    final now = DateTime.now();

    if (!_isEditing) {
      await service.create(
        KnowledgeArticle(
          id: '',
          title: _titleController.text.trim(),
          category: _categoryController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          tags: _splitCsv(_tagsController.text),
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          serviceIds: _serviceIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          industryIds: _industryIds.toList(),
          experienceIds: _experienceIds.toList(),
          status: _status,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        KnowledgeArticle(
          id: loaded.id,
          title: _titleController.text.trim(),
          category: _categoryController.text.trim(),
          summary: _summaryController.text.trim(),
          content: _contentController.text.trim(),
          tags: _splitCsv(_tagsController.text),
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          serviceIds: _serviceIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          industryIds: _industryIds.toList(),
          experienceIds: _experienceIds.toList(),
          status: _status,
          createdAt: loaded.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.articleId == null) return;
    await ref.read(knowledgeServiceProvider).delete(widget.articleId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final articleAsync = _isEditing
        ? ref.watch(knowledgeArticleByIdProvider(widget.articleId!))
        : null;

    if (articleAsync != null) {
      final loaded = articleAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? strings.editKnowledgeArticleTitle
              : strings.newKnowledgeArticleTitle,
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.deleteTooltip,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(context, strings),
    );
  }

  Widget _buildForm(BuildContext context, AppStrings strings) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SectionHeader(
            title: strings.sectionDetails,
            accentColor: AppStatusColors.neutral,
          ),
          TextFormField(
            controller: _titleController,
            autofocus: !_isEditing,
            decoration: InputDecoration(labelText: strings.fieldArticleTitle),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _summaryController,
            decoration: InputDecoration(labelText: strings.fieldArticleSummary),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _contentController,
            decoration: InputDecoration(labelText: strings.fieldArticleContent),
            maxLines: 10,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionClassification,
            accentColor: AppStatusColors.neutral,
          ),
          TextFormField(
            controller: _categoryController,
            decoration: InputDecoration(labelText: strings.fieldCategory),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            strings.suggestedCategoriesLabel,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in suggestedKnowledgeCategories)
                ActionChip(
                  label: Text(category),
                  onPressed: () =>
                      setState(() => _categoryController.text = category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<KnowledgeArticleStatus>(
            initialValue: _status,
            decoration: InputDecoration(labelText: strings.fieldStatus),
            items: KnowledgeArticleStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(labelText: strings.fieldArticleTags),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionRelationships,
            accentColor: AppEntityColors.knowledgeBase,
          ),
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
      ),
    );
  }
}