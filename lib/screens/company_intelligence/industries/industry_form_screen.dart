import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class IndustryFormScreen extends ConsumerStatefulWidget {
  const IndustryFormScreen({super.key, this.industryId});

  final String? industryId;

  @override
  ConsumerState<IndustryFormScreen> createState() => _IndustryFormScreenState();
}

class _IndustryFormScreenState extends ConsumerState<IndustryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sectorController = TextEditingController();
  final _tagsController = TextEditingController();

  IndustryStatus _status = IndustryStatus.active;
  Set<String> _businessUnitIds = {};
  Set<String> _productIds = {};
  Set<String> _capabilityIds = {};
  Set<String> _technologyIds = {};

  // No picker exists for this yet — Experience isn't a built entity in this
  // milestone (see Industry's doc comment). Carried through unedited so
  // saving an Industry never wipes out values a future migration sets.
  List<String> _experienceIds = const [];

  bool _saving = false;
  bool _initialized = false;
  Industry? _loaded;

  bool get _isEditing => widget.industryId != null;

  void _seedFrom(Industry? i) {
    if (_initialized || i == null) return;
    _initialized = true;
    _loaded = i;
    _nameController.text = i.name;
    _descriptionController.text = i.description;
    _sectorController.text = i.sector ?? '';
    _tagsController.text = i.tags.join(', ');
    _status = i.status;
    _businessUnitIds = i.businessUnitIds.toSet();
    _productIds = i.productIds.toSet();
    _capabilityIds = i.capabilityIds.toSet();
    _technologyIds = i.technologyIds.toSet();
    _experienceIds = i.experienceIds;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sectorController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(industryServiceProvider);
    final now = DateTime.now();
    final sector = _sectorController.text.trim();

    if (!_isEditing) {
      await service.create(
        Industry(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          sector: sector.isEmpty ? null : sector,
          tags: _splitCsv(_tagsController.text),
          status: _status,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          experienceIds: _experienceIds,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        Industry(
          id: loaded.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          sector: sector.isEmpty ? null : sector,
          tags: _splitCsv(_tagsController.text),
          status: _status,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          experienceIds: _experienceIds,
          createdAt: loaded.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.industryId == null) return;
    await ref.read(industryServiceProvider).delete(widget.industryId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final industryAsync = _isEditing
        ? ref.watch(industryByIdProvider(widget.industryId!))
        : null;

    if (industryAsync != null) {
      final loaded = industryAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editIndustryTitle : strings.newIndustryTitle,
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
            decoration: InputDecoration(labelText: strings.fieldIndustryName),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
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
                controller: _sectorController,
                decoration: InputDecoration(
                  labelText: strings.fieldIndustrySector,
                ),
              ),
              DropdownButtonFormField<IndustryStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: IndustryStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(labelText: strings.fieldIndustryTags),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionRelationships,
            accentColor: AppEntityColors.industry,
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