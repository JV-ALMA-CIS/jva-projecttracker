import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Same create-vs-edit shape as `TechnologyFormScreen` — see that file's
/// doc comment. `ServiceModel.businessUnitIds` is a list (unlike
/// `Product.businessUnitId`), so this uses the same multi-select
/// `RelationshipPicker` pattern Technology already uses for its own
/// Business Unit links.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();

  ServiceStatus _status = ServiceStatus.active;
  Set<String> _businessUnitIds = {};

  bool _saving = false;
  bool _initialized = false;
  ServiceModel? _loaded;

  bool get _isEditing => widget.serviceId != null;

  void _seedFrom(ServiceModel? s) {
    if (_initialized || s == null) return;
    _initialized = true;
    _loaded = s;
    _nameController.text = s.name;
    _slugController.text = s.slug;
    _summaryController.text = s.summary;
    _descriptionController.text = s.description;
    _status = s.status;
    _businessUnitIds = s.businessUnitIds.toSet();
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

    final service = ref.read(serviceServiceProvider);
    final now = DateTime.now();

    if (!_isEditing) {
      await service.create(
        ServiceModel(
          id: '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          businessUnitIds: _businessUnitIds.toList(),
          status: _status,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        ServiceModel(
          id: loaded.id,
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          businessUnitIds: _businessUnitIds.toList(),
          status: _status,
          capabilityIds: loaded.capabilityIds,
          industryIds: loaded.industryIds,
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
    if (widget.serviceId == null) return;
    await ref.read(serviceServiceProvider).delete(widget.serviceId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = _isEditing
        ? ref.watch(serviceByIdProvider(widget.serviceId!))
        : null;

    if (serviceAsync != null) {
      final loaded = serviceAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editServiceTitle : strings.newServiceTitle,
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
            decoration: InputDecoration(labelText: strings.fieldServiceName),
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
                  labelText: strings.fieldServiceSlug,
                ),
              ),
              DropdownButtonFormField<ServiceStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: ServiceStatus.values
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
            decoration: InputDecoration(labelText: strings.fieldServiceSummary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: strings.fieldDescription),
            maxLines: 4,
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
