import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Standalone Technology create/edit form — the authoritative place to
/// fully maintain a Technology record (Company Intelligence →
/// Technologies). A Product form's "+ Add Technology" action uses its own
/// compact quick-add dialog instead of this screen (see
/// `ProductFormScreen._addTechnology`), so this form's full field set stays
/// reserved for deliberate, complete Technology maintenance.
class TechnologyFormScreen extends ConsumerStatefulWidget {
  const TechnologyFormScreen({super.key, this.technologyId});

  final String? technologyId;

  @override
  ConsumerState<TechnologyFormScreen> createState() =>
      _TechnologyFormScreenState();
}

class _TechnologyFormScreenState extends ConsumerState<TechnologyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _vendorController = TextEditingController();
  final _websiteController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _notesController = TextEditingController();

  TechnologyStatus _status = TechnologyStatus.active;
  Set<String> _businessUnitIds = {};
  Set<String> _productIds = {};
  Set<String> _capabilityIds = {};

  bool _saving = false;
  bool _initialized = false;
  Technology? _loaded;

  bool get _isEditing => widget.technologyId != null;

  void _seedFrom(Technology? t) {
    if (_initialized || t == null) return;
    _initialized = true;
    _loaded = t;
    _nameController.text = t.name;
    _slugController.text = t.slug;
    _summaryController.text = t.summary;
    _descriptionController.text = t.description;
    _categoryController.text = t.category ?? '';
    _vendorController.text = t.vendor ?? '';
    _websiteController.text = t.website ?? '';
    _keywordsController.text = t.keywords.join(', ');
    _tagsController.text = t.tags.join(', ');
    _notesController.text = t.notes ?? '';
    _status = t.status;
    _businessUnitIds = t.businessUnitIds.toSet();
    _productIds = t.productIds.toSet();
    _capabilityIds = t.capabilityIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _vendorController.dispose();
    _websiteController.dispose();
    _keywordsController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(technologyServiceProvider);
    final now = DateTime.now();
    final category = _categoryController.text.trim();
    final vendor = _vendorController.text.trim();
    final website = _websiteController.text.trim();
    final notes = _notesController.text.trim();

    if (!_isEditing) {
      await service.create(
        Technology(
          id: '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          category: category.isEmpty ? null : category,
          vendor: vendor.isEmpty ? null : vendor,
          website: website.isEmpty ? null : website,
          keywords: _splitCsv(_keywordsController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          notes: notes.isEmpty ? null : notes,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        Technology(
          id: loaded.id,
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          category: category.isEmpty ? null : category,
          vendor: vendor.isEmpty ? null : vendor,
          website: website.isEmpty ? null : website,
          keywords: _splitCsv(_keywordsController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          notes: notes.isEmpty ? null : notes,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          createdAt: loaded.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.technologyId == null) return;
    await ref.read(technologyServiceProvider).delete(widget.technologyId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final technologyAsync = _isEditing
        ? ref.watch(technologyByIdProvider(widget.technologyId!))
        : null;

    if (technologyAsync != null) {
      final loaded = technologyAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editTechnologyTitle : strings.newTechnologyTitle,
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
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(labelText: strings.fieldTechnologyName),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologySlug,
                ),
              ),
              TextFormField(
                controller: _summaryController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologySummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: strings.fieldDescription),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionClassification,
            accentColor: AppStatusColors.neutral,
          ),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyCategory,
                ),
              ),
              DropdownButtonFormField<TechnologyStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: TechnologyStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _vendorController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyVendor,
                ),
              ),
              TextFormField(
                controller: _websiteController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyWebsite,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionKeywordsTags,
            accentColor: AppStatusColors.neutral,
          ),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _keywordsController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyKeywords,
                ),
              ),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyTags,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionRelationships,
            accentColor: AppStatusColors.technology,
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
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionNotes,
            accentColor: AppStatusColors.neutral,
          ),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: strings.fieldTechnologyNotes,
            ),
            maxLines: 4,
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
