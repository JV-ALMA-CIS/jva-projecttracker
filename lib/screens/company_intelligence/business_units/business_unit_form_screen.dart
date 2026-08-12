import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Same create-vs-edit shape as `TechnologyFormScreen`/`IndustryFormScreen`
/// — this entity type never had a form at all (only a read-only list +
/// workspace), which meant the only way to create a Business Unit was the
/// AI extraction "create & link" suggestion chips or the CI empty-state
/// setup dialog. This restores the normal manual path every other entity
/// already had.
class BusinessUnitFormScreen extends ConsumerStatefulWidget {
  const BusinessUnitFormScreen({super.key, this.businessUnitId});

  final String? businessUnitId;

  @override
  ConsumerState<BusinessUnitFormScreen> createState() =>
      _BusinessUnitFormScreenState();
}

class _BusinessUnitFormScreenState
    extends ConsumerState<BusinessUnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();

  BusinessUnitStatus _status = BusinessUnitStatus.active;

  bool _saving = false;
  bool _initialized = false;
  BusinessUnit? _loaded;

  bool get _isEditing => widget.businessUnitId != null;

  void _seedFrom(BusinessUnit? b) {
    if (_initialized || b == null) return;
    _initialized = true;
    _loaded = b;
    _nameController.text = b.name;
    _slugController.text = b.slug;
    _summaryController.text = b.summary;
    _descriptionController.text = b.description;
    _status = b.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(businessUnitServiceProvider);
    final now = DateTime.now();

    if (!_isEditing) {
      await service.create(
        BusinessUnit(
          id: '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        BusinessUnit(
          id: loaded.id,
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          productIds: loaded.productIds,
          serviceIds: loaded.serviceIds,
          capabilityIds: loaded.capabilityIds,
          industryIds: loaded.industryIds,
          technologyIds: loaded.technologyIds,
          pastProjectIds: loaded.pastProjectIds,
          aiExpertiseSummary: loaded.aiExpertiseSummary,
          aiExpertiseHighlights: loaded.aiExpertiseHighlights,
          aiExpertiseSummaryGeneratedAt: loaded.aiExpertiseSummaryGeneratedAt,
          createdAt: loaded.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.businessUnitId == null) return;
    await ref.read(businessUnitServiceProvider).delete(widget.businessUnitId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final businessUnitAsync = _isEditing
        ? ref.watch(businessUnitByIdProvider(widget.businessUnitId!))
        : null;

    if (businessUnitAsync != null) {
      final loaded = businessUnitAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? strings.editBusinessUnitTitle
              : strings.newBusinessUnitTitle,
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
          SectionHeader(title: strings.sectionDetails),
          TextFormField(
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: strings.fieldBusinessUnitName,
            ),
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
                  labelText: strings.fieldBusinessUnitSlug,
                ),
              ),
              DropdownButtonFormField<BusinessUnitStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: BusinessUnitStatus.values
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
            controller: _summaryController,
            decoration: InputDecoration(
              labelText: strings.fieldBusinessUnitSummary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: strings.fieldBusinessUnitDescription,
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
