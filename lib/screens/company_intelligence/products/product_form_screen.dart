import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_units_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/slugify.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Same create-vs-edit shape as `TechnologyFormScreen` — see that file's
/// doc comment. `Product.businessUnitIds` is a list (a product can belong to
/// more than one Business Unit, e.g. spanning Agribusiness and IT), so its
/// picker is a `RelationshipPicker` multi-select like every other Company
/// Intelligence relationship — no longer the single required dropdown this
/// form used before multi-BU support.
///
/// The `slug` field is auto-derived from the product name on create (see
/// `slugify()`) and hidden behind an "Advanced" section rather than shown
/// as a primary field — it's an internal id-safe identifier, not something
/// a user registering a new software platform needs to think about. If no
/// Business Unit exists yet, saving is blocked with a clear warning and a
/// direct link to create one, rather than letting the form fail silently
/// on a required-field validator.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId, this.businessUnitId});

  final String? productId;

  /// Pre-selects one Business Unit when creating a product from within a
  /// Business Unit Workspace context — optional, still changeable (and
  /// extendable to more than one BU) in the form.
  final String? businessUnitId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storeUrlController = TextEditingController();

  ProductStatus _status = ProductStatus.active;
  Set<String> _businessUnitIds = {};
  Set<String> _capabilityIds = {};
  Set<String> _technologyIds = {};
  Set<String> _industryIds = {};

  bool _saving = false;
  bool _initialized = false;
  bool _slugEditedByUser = false;
  Product? _loaded;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (widget.businessUnitId != null) {
      _businessUnitIds = {widget.businessUnitId!};
    }
    // Auto-derive the slug from the name as the user types, until they
    // touch the slug field themselves (Advanced section) — mirrors how
    // e.g. package managers auto-slug a project name but let you override.
    _nameController.addListener(() {
      if (_isEditing || _slugEditedByUser) return;
      _slugController.text = slugify(_nameController.text);
    });
    _slugController.addListener(() {
      if (_slugController.text != slugify(_nameController.text)) {
        _slugEditedByUser = true;
      }
    });
  }

  void _seedFrom(Product? p) {
    if (_initialized || p == null) return;
    _initialized = true;
    _loaded = p;
    _nameController.text = p.name;
    _slugController.text = p.slug;
    _summaryController.text = p.summary;
    _descriptionController.text = p.description;
    _storeUrlController.text = p.storeUrl ?? '';
    _status = p.status;
    _businessUnitIds = p.businessUnitIds.toSet();
    _capabilityIds = p.capabilityIds.toSet();
    _technologyIds = p.technologyIds.toSet();
    _industryIds = p.industryIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    _storeUrlController.dispose();
    super.dispose();
  }

  Future<void> _save(bool hasBusinessUnits) async {
    if (!_formKey.currentState!.validate()) return;
    if (_businessUnitIds.isEmpty || !hasBusinessUnits) return;
    setState(() => _saving = true);

    final service = ref.read(productServiceProvider);
    final now = DateTime.now();
    final slug = _slugController.text.trim().isEmpty
        ? slugify(_nameController.text)
        : _slugController.text.trim();
    final storeUrl = _storeUrlController.text.trim();

    if (!_isEditing) {
      await service.create(
        Product(
          id: '',
          name: _nameController.text.trim(),
          slug: slug,
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          businessUnitIds: _businessUnitIds.toList(),
          status: _status,
          storeUrl: storeUrl.isEmpty ? null : storeUrl,
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          industryIds: _industryIds.toList(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        Product(
          id: loaded.id,
          name: _nameController.text.trim(),
          slug: slug,
          summary: _summaryController.text.trim(),
          description: _descriptionController.text.trim(),
          businessUnitIds: _businessUnitIds.toList(),
          status: _status,
          storeUrl: storeUrl.isEmpty ? null : storeUrl,
          capabilityIds: _capabilityIds.toList(),
          industryIds: _industryIds.toList(),
          technologyIds: _technologyIds.toList(),
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

  /// Opens the compact quick-add Technology dialog (see
  /// `_QuickAddTechnologyDialog`) and, once the user creates a new
  /// Technology there, adds its id straight into this form's selection —
  /// same `RelationshipPicker` selection state as toggling an existing chip,
  /// no second Firestore round trip needed since `TechnologyService.create`
  /// already returned the id. Never navigates away from the Product form —
  /// the full `TechnologyFormScreen` (Company Intelligence → Technologies)
  /// stays the only place a Technology's full field set is edited.
  Future<void> _addTechnology() async {
    final createdId = await showDialog<String?>(
      context: context,
      builder: (_) => const _QuickAddTechnologyDialog(),
    );
    if (createdId == null || !mounted) return;
    setState(() => _technologyIds = {..._technologyIds, createdId});
  }

  Future<void> _delete() async {
    if (widget.productId == null) return;
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteTooltip),
        content: Text(strings.deleteProductConfirmBody),
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

    await ref.read(productServiceProvider).delete(widget.productId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = _isEditing
        ? ref.watch(productByIdProvider(widget.productId!))
        : null;

    if (productAsync != null) {
      final loaded = productAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);
    final businessUnitsAsync = ref.watch(businessUnitsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editProductTitle : strings.newProductTitle,
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
          : _buildForm(context, strings, businessUnitsAsync),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppStrings strings,
    AsyncValue<List<BusinessUnit>> businessUnitsAsync,
  ) {
    final businessUnits = businessUnitsAsync.value ?? const [];
    final businessUnitsLoaded = businessUnitsAsync.hasValue;
    final hasBusinessUnits = !businessUnitsLoaded || businessUnits.isNotEmpty;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      strings.productFormHintMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (businessUnitsLoaded && businessUnits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Card(
                color: AppStatusColors.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        color: AppStatusColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.noBusinessUnitsForProductMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton(
                              onPressed: () => pushSlideFade(
                                context,
                                const BusinessUnitsScreen(),
                              ),
                              child: Text(strings.goToBusinessUnitsButton),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SectionHeader(
            title: strings.sectionDetails,
            accentColor: AppStatusColors.neutral,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(labelText: strings.fieldProductName),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _summaryController,
            decoration: InputDecoration(
              labelText: strings.fieldProductSummary,
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: strings.fieldDescription),
            minLines: 4,
            maxLines: 8,
          ),
          const SizedBox(height: AppSpacing.md),
          RelationshipPicker<BusinessUnit>(
            label: strings.fieldProductBusinessUnit,
            optionsAsync: businessUnitsAsync,
            idOf: (u) => u.id,
            nameOf: (u) => u.name,
            selectedIds: _businessUnitIds,
            onToggle: (id, selected) => setState(() {
              _businessUnitIds = selected
                  ? {..._businessUnitIds, id}
                  : ({..._businessUnitIds}..remove(id));
            }),
          ),
          if (_businessUnitIds.isEmpty && hasBusinessUnits)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                strings.requiredValidator,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<ProductStatus>(
              initialValue: _status,
              decoration: InputDecoration(labelText: strings.fieldStatus),
              items: ProductStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _storeUrlController,
            decoration: InputDecoration(
              labelText: strings.fieldProductStoreUrl,
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.lg),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(strings.advancedSectionLabel),
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: strings.fieldProductSlug,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionRelationships,
            accentColor: AppStatusColors.technology,
          ),
          const SizedBox(height: AppSpacing.sm),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RelationshipPicker<Technology>(
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
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: _addTechnology,
                icon: const Icon(Icons.add, size: 18),
                label: Text(strings.addTechnologyButton),
              ),
            ],
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
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (_saving || !hasBusinessUnits || _businessUnitIds.isEmpty)
                  ? null
                  : () => _save(hasBusinessUnits),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.saveButton),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "emergency/convenience" Technology creation dialog, opened from
/// the Product form's "+ Add Technology" action — see
/// `_ProductFormScreenState._addTechnology`. Deliberately minimal (name +
/// optional description/category only): the authoritative place to fully
/// maintain a Technology record (status, vendor, website, keywords, tags,
/// notes, Business Unit/Product/Capability relationships) remains the
/// standalone `TechnologyFormScreen` under Company Intelligence →
/// Technologies, which this dialog does not replace, navigate to, or
/// duplicate any logic from. Saving here calls the exact same
/// `TechnologyService.create` the full form uses, so normalized-name
/// duplicate prevention applies identically — creating "Flutter" here when
/// it already exists returns the existing Technology's id rather than
/// making a second record.
class _QuickAddTechnologyDialog extends ConsumerStatefulWidget {
  const _QuickAddTechnologyDialog();

  @override
  ConsumerState<_QuickAddTechnologyDialog> createState() =>
      _QuickAddTechnologyDialogState();
}

class _QuickAddTechnologyDialogState
    extends ConsumerState<_QuickAddTechnologyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final strings = ref.read(appStringsProvider);
    final category = _categoryController.text.trim();
    final now = DateTime.now();

    try {
      final createdId = await ref
          .read(technologyServiceProvider)
          .create(
            Technology(
              id: '',
              name: _nameController.text.trim(),
              slug: '',
              description: _descriptionController.text.trim(),
              category: category.isEmpty ? null : category,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (mounted) Navigator.of(context).pop(createdId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = strings.errorPrefix(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(strings.quickAddTechnologyTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.quickAddTechnologyCaption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyName,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? strings.requiredValidator
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: strings.fieldDescription,
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: strings.fieldTechnologyCategory,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.addTechnologyDialogButton),
        ),
      ],
    );
  }
}
