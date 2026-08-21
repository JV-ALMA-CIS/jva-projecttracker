import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/currency_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class ExperienceFormScreen extends ConsumerStatefulWidget {
  const ExperienceFormScreen({super.key, this.experienceId});

  final String? experienceId;

  @override
  ConsumerState<ExperienceFormScreen> createState() =>
      _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends ConsumerState<ExperienceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _partnerNameController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _contractValueController = TextEditingController();
  final _fundingSourceController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _achievementsController = TextEditingController();
  final _lessonsLearnedController = TextEditingController();
  final _tagsController = TextEditingController();

  ExperienceStatus _status = ExperienceStatus.active;
  DateTime? _startDate;
  DateTime? _endDate;
  String _currency = 'EUR';
  Set<String> _businessUnitIds = {};
  Set<String> _productIds = {};
  Set<String> _capabilityIds = {};
  Set<String> _technologyIds = {};
  Set<String> _industryIds = {};

  bool _saving = false;
  bool _initialized = false;
  Experience? _loaded;

  bool get _isEditing => widget.experienceId != null;

  void _seedFrom(Experience? e) {
    if (_initialized || e == null) return;
    _initialized = true;
    _loaded = e;
    _titleController.text = e.title;
    _summaryController.text = e.summary;
    _clientNameController.text = e.clientName ?? '';
    _partnerNameController.text = e.partnerName ?? '';
    _countryController.text = e.country ?? '';
    _regionController.text = e.region ?? '';
    _contractValueController.text = e.contractValue == null
        ? ''
        : e.contractValue!.toStringAsFixed(0);
    _fundingSourceController.text = e.fundingSource ?? '';
    _outcomeController.text = e.outcome;
    _achievementsController.text = e.achievements.join('\n');
    _lessonsLearnedController.text = e.lessonsLearned.join('\n');
    _tagsController.text = e.tags.join(', ');
    _status = e.status;
    _startDate = e.startDate;
    _endDate = e.endDate;
    _currency = e.currency;
    _businessUnitIds = e.businessUnitIds.toSet();
    _productIds = e.productIds.toSet();
    _capabilityIds = e.capabilityIds.toSet();
    _technologyIds = e.technologyIds.toSet();
    _industryIds = e.industryIds.toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _clientNameController.dispose();
    _partnerNameController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _contractValueController.dispose();
    _fundingSourceController.dispose();
    _outcomeController.dispose();
    _achievementsController.dispose();
    _lessonsLearnedController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> _splitLines(String v) =>
      v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(experienceServiceProvider);
    final now = DateTime.now();
    final clientName = _clientNameController.text.trim();
    final partnerName = _partnerNameController.text.trim();
    final country = _countryController.text.trim();
    final region = _regionController.text.trim();
    final fundingSource = _fundingSourceController.text.trim();
    final contractValue = double.tryParse(_contractValueController.text.trim());

    if (!_isEditing) {
      await service.create(
        Experience(
          id: '',
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          clientName: clientName.isEmpty ? null : clientName,
          partnerName: partnerName.isEmpty ? null : partnerName,
          country: country.isEmpty ? null : country,
          region: region.isEmpty ? null : region,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          industryIds: _industryIds.toList(),
          startDate: _startDate,
          endDate: _endDate,
          contractValue: contractValue,
          currency: _currency,
          fundingSource: fundingSource.isEmpty ? null : fundingSource,
          outcome: _outcomeController.text.trim(),
          achievements: _splitLines(_achievementsController.text),
          lessonsLearned: _splitLines(_lessonsLearnedController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      final loaded = _loaded!;
      await service.update(
        Experience(
          id: loaded.id,
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          clientName: clientName.isEmpty ? null : clientName,
          partnerName: partnerName.isEmpty ? null : partnerName,
          country: country.isEmpty ? null : country,
          region: region.isEmpty ? null : region,
          businessUnitIds: _businessUnitIds.toList(),
          productIds: _productIds.toList(),
          capabilityIds: _capabilityIds.toList(),
          technologyIds: _technologyIds.toList(),
          industryIds: _industryIds.toList(),
          startDate: _startDate,
          endDate: _endDate,
          contractValue: contractValue,
          currency: _currency,
          fundingSource: fundingSource.isEmpty ? null : fundingSource,
          outcome: _outcomeController.text.trim(),
          achievements: _splitLines(_achievementsController.text),
          lessonsLearned: _splitLines(_lessonsLearnedController.text),
          tags: _splitCsv(_tagsController.text),
          status: _status,
          createdAt: loaded.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.experienceId == null) return;
    await ref.read(experienceServiceProvider).delete(widget.experienceId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final experienceAsync = _isEditing
        ? ref.watch(experienceByIdProvider(widget.experienceId!))
        : null;

    if (experienceAsync != null) {
      final loaded = experienceAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editExperienceTitle : strings.newExperienceTitle,
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
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

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
            decoration: InputDecoration(
              labelText: strings.fieldExperienceTitle,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _summaryController,
            decoration: InputDecoration(
              labelText: strings.fieldExperienceSummary,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionClientLocation,
            accentColor: AppStatusColors.neutral,
          ),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _clientNameController,
                decoration: InputDecoration(labelText: strings.fieldClient),
              ),
              TextFormField(
                controller: _partnerNameController,
                decoration: InputDecoration(labelText: strings.fieldPartner),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _countryController,
                decoration: InputDecoration(labelText: strings.fieldCountry),
              ),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: strings.fieldRegion),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionEngagementDetails,
            accentColor: AppStatusColors.neutral,
          ),
          AdaptiveFieldRow(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.input),
                onTap: () => _pickDate(isStart: true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: strings.fieldStartDate,
                  ),
                  child: Text(
                    _startDate == null ? '' : dateFormat.format(_startDate!),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.input),
                onTap: () => _pickDate(isStart: false),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: strings.fieldEndDate),
                  child: Text(
                    _endDate == null ? '' : dateFormat.format(_endDate!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(labelText: strings.fieldCurrency),
                  items: CurrencyService.supportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
              ),
              TextFormField(
                controller: _contractValueController,
                decoration: InputDecoration(
                  labelText: strings.fieldContractValue,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _fundingSourceController,
                decoration: InputDecoration(
                  labelText: strings.fieldFundingSource,
                ),
              ),
              DropdownButtonFormField<ExperienceStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: ExperienceStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: strings.sectionOutcomes,
            accentColor: AppStatusColors.neutral,
          ),
          TextFormField(
            controller: _outcomeController,
            decoration: InputDecoration(labelText: strings.fieldOutcome),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _achievementsController,
            decoration: InputDecoration(labelText: strings.fieldAchievements),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _lessonsLearnedController,
            decoration: InputDecoration(labelText: strings.fieldLessonsLearned),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(labelText: strings.fieldExperienceTags),
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
