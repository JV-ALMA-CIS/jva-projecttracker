import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/currency_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _projectSizeController = TextEditingController();
  final _scopeOfWorksController = TextEditingController();
  final _notesController = TextEditingController();
  final _contractValueController = TextEditingController();

  ProjectStatus _status = ProjectStatus.planned;
  ProjectCategory _category = ProjectCategory.other;
  ContractorRole _contractorRole = ContractorRole.mainContractor;
  ClientType _clientType = ClientType.privateClient;
  String _currency = 'EUR';

  bool _saving = false;
  bool _initialized = false;
  Project? _loadedProject;

  bool get _isEditing => widget.projectId != null;

  void _seedFrom(Project? p) {
    if (_initialized || p == null) return;
    _initialized = true;
    _loadedProject = p;
    _nameController.text = p.name;
    _clientController.text = p.client;
    _descriptionController.text = p.description;
    _locationController.text = p.location;
    _projectSizeController.text = p.projectSize;
    _scopeOfWorksController.text = p.scopeOfWorks;
    _notesController.text = p.notes;
    _contractValueController.text = p.contractValueAmount == null
        ? ''
        : p.contractValueAmount!.toStringAsFixed(0);
    _status = p.status;
    _category = p.category;
    _contractorRole = p.contractorRole;
    _clientType = p.clientType;
    _currency = p.contractValueCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _projectSizeController.dispose();
    _scopeOfWorksController.dispose();
    _notesController.dispose();
    _contractValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(projectServiceProvider);
    final amount = double.tryParse(_contractValueController.text.trim());

    if (!_isEditing) {
      final now = DateTime.now();
      await service.create(
        Project(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          client: _clientController.text.trim(),
          status: _status,
          notes: _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
          category: _category,
          location: _locationController.text.trim(),
          contractValueAmount: amount,
          contractValueCurrency: _currency,
          scopeOfWorks: _scopeOfWorksController.text.trim(),
          contractorRole: _contractorRole,
          projectSize: _projectSizeController.text.trim(),
          clientType: _clientType,
        ),
      );
    } else if (_loadedProject != null) {
      await service.update(
        _loadedProject!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          client: _clientController.text.trim(),
          status: _status,
          notes: _notesController.text.trim(),
          category: _category,
          location: _locationController.text.trim(),
          contractValueAmount: amount,
          clearContractValueAmount: amount == null,
          contractValueCurrency: _currency,
          scopeOfWorks: _scopeOfWorksController.text.trim(),
          contractorRole: _contractorRole,
          projectSize: _projectSizeController.text.trim(),
          clientType: _clientType,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.projectId == null) return;
    await ref.read(projectServiceProvider).delete(widget.projectId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = _isEditing
        ? ref.watch(projectByIdProvider(widget.projectId!))
        : null;

    if (projectAsync != null) {
      final loaded = projectAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Project' : 'New Project'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Details'),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Project name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clientController,
            decoration: const InputDecoration(labelText: 'Client'),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Classification'),
          DropdownButtonFormField<ProjectCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ProjectCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          Text(
            'Contractor role',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ContractorRole>(
            segments: ContractorRole.values
                .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                .toList(),
            selected: {_contractorRole},
            onSelectionChanged: (s) =>
                setState(() => _contractorRole = s.first),
          ),
          const SizedBox(height: 16),
          Text('Client type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ClientType>(
            segments: ClientType.values
                .map((c) => ButtonSegment(value: c, label: Text(c.label)))
                .toList(),
            selected: {_clientType},
            onSelectionChanged: (s) => setState(() => _clientType = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: ProjectStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Scope & Scale'),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location / site',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _projectSizeController,
            decoration: const InputDecoration(
              labelText: 'Project size',
              helperText: 'e.g. 12,500 sq.m · 4.2 km · 80 units',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _scopeOfWorksController,
            decoration: const InputDecoration(labelText: 'Scope of works'),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          _ContractValueField(
            currency: _currency,
            amountController: _contractValueController,
            onCurrencyChanged: (c) => setState(() => _currency = c),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Notes'),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Currency-selectable contract value amount, with live converted
/// equivalents in the other supported currencies shown once an amount is
/// entered. Conversion is display-only — never persisted.
class _ContractValueField extends ConsumerStatefulWidget {
  const _ContractValueField({
    required this.currency,
    required this.amountController,
    required this.onCurrencyChanged,
  });

  final String currency;
  final TextEditingController amountController;
  final ValueChanged<String> onCurrencyChanged;

  @override
  ConsumerState<_ContractValueField> createState() =>
      _ContractValueFieldState();
}

class _ContractValueFieldState extends ConsumerState<_ContractValueField> {
  @override
  void initState() {
    super.initState();
    widget.amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_onAmountChanged);
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(widget.amountController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                initialValue: widget.currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: CurrencyService.supportedCurrencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) widget.onCurrencyChanged(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: widget.amountController,
                decoration: const InputDecoration(labelText: 'Contract value'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ),
          ],
        ),
        if (amount != null) ...[
          const SizedBox(height: 8),
          _ConvertedEquivalents(amount: amount, currency: widget.currency),
        ],
      ],
    );
  }
}

class _ConvertedEquivalents extends ConsumerWidget {
  const _ConvertedEquivalents({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesProvider(currency));

    return ratesAsync.when(
      data: (rates) {
        if (rates.isEmpty) return const SizedBox.shrink();
        final parts = rates.entries.map((e) {
          final converted = amount * e.value;
          return NumberFormat.simpleCurrency(
            name: e.key,
            decimalDigits: 0,
          ).format(converted);
        });
        return Text(
          '≈ ${parts.join('  ·  ')}  (live rates via open.er-api.com)',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
      loading: () => Row(
        children: [
          const SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Fetching live rates…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      // Never show a fabricated/fallback conversion when the rate fetch fails.
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
