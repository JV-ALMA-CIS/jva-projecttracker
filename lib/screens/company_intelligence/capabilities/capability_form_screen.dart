import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Same create-vs-edit shape as `TechnologyFormScreen` — see that file's
/// doc comment. `Capability` forward-owns `productIds`/`serviceIds` (like
/// Technology does), but those are edited from the Product/Service side per
/// this app's existing "each entity edits the relationships it forward-owns"
/// convention, not duplicated here.
class CapabilityFormScreen extends ConsumerStatefulWidget {
  const CapabilityFormScreen({super.key, this.capabilityId});

  final String? capabilityId;

  @override
  ConsumerState<CapabilityFormScreen> createState() =>
      _CapabilityFormScreenState();
}

class _CapabilityFormScreenState extends ConsumerState<CapabilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _businessRelevanceController = TextEditingController();

  CapabilityStatus _status = CapabilityStatus.active;

  bool _saving = false;
  bool _initialized = false;
  Capability? _loaded;

  bool get _isEditing => widget.capabilityId != null;

  void _seedFrom(Capability? c) {
    if (_initialized || c == null) return;
    _initialized = true;
    _loaded = c;
    _nameController.text = c.name;
    _slugController.text = c.slug;
    _summaryController.text = c.summary;
    _descriptionController.text = c.description;
    _keywordsController.text = c.keywords.join(', ');
    _tagsController.text = c.tags.join(', ');
    _businessRelevanceController.text = c.businessRelevance ?? '';
    _status = c.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    _keywordsController.dispose();
    _tagsController.dispose();
    _businessRelevanceController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(capabilityServiceProvider);
    final now = DateTime.now();
    final businessRelevance = _businessRelevanceController.text.trim();

    if (!_isEditing) {
      await service.create(
        Capability(
          id: '',
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          keywords: _splitCsv(_keywordsController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          businessRelevance: businessRelevance.isEmpty
              ? null
              : businessRelevance,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        Capability(
          id: loaded.id,
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          keywords: _splitCsv(_keywordsController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          businessRelevance: businessRelevance.isEmpty
              ? null
              : businessRelevance,
          productIds: loaded.productIds,
          serviceIds: loaded.serviceIds,
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
    if (widget.capabilityId == null) return;
    await ref.read(capabilityServiceProvider).delete(widget.capabilityId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final capabilityAsync = _isEditing
        ? ref.watch(capabilityByIdProvider(widget.capabilityId!))
        : null;

    if (capabilityAsync != null) {
      final loaded = capabilityAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editCapabilityTitle : strings.newCapabilityTitle,
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
            decoration: InputDecoration(labelText: strings.fieldCapabilityName),
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
                  labelText: strings.fieldCapabilitySlug,
                ),
              ),
              DropdownButtonFormField<CapabilityStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: CapabilityStatus.values
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
              labelText: strings.fieldCapabilitySummary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: strings.fieldDescription),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _businessRelevanceController,
            decoration: InputDecoration(
              labelText: strings.fieldCapabilityBusinessRelevance,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: strings.sectionKeywordsTags),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _keywordsController,
                decoration: InputDecoration(
                  labelText: strings.fieldCapabilityKeywords,
                ),
              ),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: strings.fieldCapabilityTags,
                ),
              ),
            ],
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
