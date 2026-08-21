import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experience_form_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_extraction_review_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/screens/projects/upload_project_document_dialog.dart';
import 'package:jva_projecttracker/services/currency_service.dart';
import 'package:jva_projecttracker/services/project_experience_promotion.dart';
import 'package:jva_projecttracker/services/project_extraction_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({
    super.key,
    this.projectId,
    this.sourceOpportunityId,
    this.initialName,
    this.initialClient,
    this.initialDescription,
  });

  final String? projectId;

  /// The opportunity this project is being started from — used only when
  /// [projectId] is null (a brand-new project). The user still reviews and
  /// saves the form themselves; nothing is auto-created silently, since
  /// fields like category/contractor role/location have no honest source
  /// on the opportunity.
  final String? sourceOpportunityId;
  final String? initialName;
  final String? initialClient;
  final String? initialDescription;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _fundingAgencyController = TextEditingController();
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
  String? _extractingDocumentId;

  bool get _isEditing => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing) {
      _nameController.text = widget.initialName ?? '';
      _clientController.text = widget.initialClient ?? '';
      _descriptionController.text = widget.initialDescription ?? '';
    }
  }

  void _seedFrom(Project? p) {
    if (_initialized || p == null) return;
    _initialized = true;
    _loadedProject = p;
    _nameController.text = p.name;
    _clientController.text = p.client;
    _fundingAgencyController.text = p.fundingAgency;
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
    // Rebuild so dropdowns / segmented buttons pick up seeded values.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientController.dispose();
    _fundingAgencyController.dispose();
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

    String? createdProjectId;
    if (!_isEditing) {
      final sourceOpportunityId = widget.sourceOpportunityId;

      // Re-verify both business invariants immediately before writing,
      // rather than trusting that the Opportunity Workspace's "Start
      // Project" tile still reflects the true state. This is a
      // query-then-branch check, not a Firestore transaction — it narrows
      // the previously-identified double-tap/cross-tab race window
      // (there was previously no check here at all) without introducing a
      // new architecture the rest of this codebase's "one per parent"
      // relationships (Proposal, Submission) don't already use.
      if (sourceOpportunityId != null) {
        final opportunity = await ref.read(
          opportunityByIdProvider(sourceOpportunityId).future,
        );
        final awardEligible =
            opportunity != null &&
            (opportunity.pipelineStage == OpportunityPipelineStage.awarded ||
                opportunity.pipelineStage ==
                    OpportunityPipelineStage.projectStarted ||
                opportunity.pipelineStage ==
                    OpportunityPipelineStage.completed);
        if (!awardEligible) {
          if (mounted) {
            final strings = ref.read(appStringsProvider);
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.projectRequiresAwardMessage)),
            );
          }
          return;
        }

        final existingProject = await ref.read(
          projectByOpportunityIdProvider(sourceOpportunityId).future,
        );
        if (existingProject != null) {
          // Someone else already started this project (another tab/device,
          // or a prior click that landed before this one) — never create a
          // second Project doc; open the one that already exists instead.
          if (mounted) {
            setState(() => _saving = false);
            Navigator.of(context).pop();
            pushSlideFade(
              context,
              ProjectWorkspaceScreen(projectId: existingProject.id),
            );
          }
          return;
        }
      }

      final now = DateTime.now();
      createdProjectId = await service.create(
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
          fundingAgency: _fundingAgencyController.text.trim(),
          contractorRole: _contractorRole,
          projectSize: _projectSizeController.text.trim(),
          clientType: _clientType,
          sourceOpportunityId: sourceOpportunityId,
        ),
      );

      if (sourceOpportunityId != null) {
        final opportunity = await ref.read(
          opportunityByIdProvider(sourceOpportunityId).future,
        );
        if (opportunity != null &&
            opportunity.pipelineStage.index <
                OpportunityPipelineStage.projectStarted.index) {
          final actor = ref.read(authStateChangesProvider).value?.email;
          await ref
              .read(opportunityServiceProvider)
              .transitionStage(
                opportunityId: sourceOpportunityId,
                newStage: OpportunityPipelineStage.projectStarted,
                note: 'Project started',
                actor: actor,
              );
        }
      }
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
          fundingAgency: _fundingAgencyController.text.trim(),
          contractorRole: _contractorRole,
          projectSize: _projectSizeController.text.trim(),
          clientType: _clientType,
        ),
      );
    }

    if (!mounted) return;
    // When a project is created from an awarded Opportunity, go straight
    // into the operational Project Workspace instead of just popping back
    // to the Opportunity Workspace — the whole point of "Start Project" is
    // to begin working in the new project immediately, not to re-discover
    // it via the (now-updated) project tile a second time.
    if (createdProjectId != null && widget.sourceOpportunityId != null) {
      Navigator.of(context).pop();
      pushSlideFade(
        context,
        ProjectWorkspaceScreen(projectId: createdProjectId),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.projectId == null) return;
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteTooltip),
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

    try {
      await ref.read(projectServiceProvider).delete(widget.projectId!);
      if (!mounted) return;
      // Pop form, then workspace if present
      Navigator.of(context).pop();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
    }
  }

  /// Deterministically maps the fields with an honest source on [project]
  /// into a new `Experience`. Relationship IDs and the outcome/achievements/
  /// lessons-learned narrative are never fabricated from thin air — but
  /// when this project has a *reviewed* AI Knowledge Extraction
  /// (`documentsForProjectProvider`, `aiExtractionStatus == reviewed`),
  /// those honestly-extracted-and-human-approved values pre-fill the same
  /// fields that would otherwise be left blank for manual entry. The user
  /// still completes/edits the rest on the Experience's own form
  /// immediately after. Idempotent: `ProjectService.linkExperience` records
  /// the result so this can't be run twice for the same project.
  Future<void> _addAsExperience(Project project) async {
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.addAsExperienceConfirmTitle),
        content: Text(strings.addAsExperienceConfirmBody),
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
    if (confirmed != true) return;

    final experienceId = await promoteProjectToExperience(ref, project);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.experienceCreatedFromProjectMessage)),
    );
    pushSlideFade(context, ExperienceFormScreen(experienceId: experienceId));
  }

  Future<void> _extractKnowledge(String documentId) async {
    final strings = ref.read(appStringsProvider);
    setState(() => _extractingDocumentId = documentId);
    try {
      await ref
          .read(projectExtractionServiceProvider)
          .extract(documentId: documentId);
    } on ProjectExtractionException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.extractionFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _extractingDocumentId = null);
    }
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
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? strings.editProjectTitle : strings.newProjectTitle,
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

  Widget _buildSourceOpportunityBanner(AppStrings strings) {
    final sourceOpportunityId = _loadedProject?.sourceOpportunityId;
    if (sourceOpportunityId == null) return const SizedBox.shrink();
    final opportunity = ref
        .watch(opportunityByIdProvider(sourceOpportunityId))
        .value;
    if (opportunity == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ActionChip(
        avatar: const Icon(Icons.travel_explore_outlined, size: 18),
        label: Text(strings.sourceOpportunityLabel(opportunity.title)),
        onPressed: () => pushSlideFade(
          context,
          OpportunityWorkspaceScreen(opportunityId: sourceOpportunityId),
        ),
      ),
    );
  }

  /// Upload -> Extract -> Review -> Approve. Lists every document uploaded
  /// against this project (`documentsForProjectProvider`) with its
  /// extraction status, plus an upload action — see
  /// `upload_project_document_dialog.dart` / `project_extraction_review_screen.dart`.
  Widget _buildAiKnowledgeExtractionSection(
    AppStrings strings,
    Project project,
  ) {
    final documentsAsync = ref.watch(documentsForProjectProvider(project.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: strings.aiKnowledgeExtractionSectionTitle,
          accentColor: AppStatusColors.ai,
          trailing: TextButton.icon(
            onPressed: () =>
                showUploadProjectDocumentDialog(context, projectId: project.id),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(strings.uploadDocumentButton),
          ),
        ),
        documentsAsync.when(
          data: (documents) {
            if (documents.isEmpty) {
              return Text(strings.noProjectDocumentsMessage);
            }
            return Column(
              children: [
                for (final doc in documents)
                  _ProjectDocumentTile(
                    document: doc,
                    strings: strings,
                    isExtracting: _extractingDocumentId == doc.id,
                    onExtract: () => _extractKnowledge(doc.id),
                    onReview: () => pushSlideFade(
                      context,
                      ProjectExtractionReviewScreen(
                        documentId: doc.id,
                        projectId: project.id,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(strings.errorPrefix(e)),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, AppStrings strings) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSourceOpportunityBanner(strings),
          SectionHeader(
            title: strings.sectionDetails,
            accentColor: AppStatusColors.operations,
          ),
          TextFormField(
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(labelText: strings.fieldProjectName),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: strings.fieldDescription),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clientController,
            decoration: InputDecoration(labelText: strings.fieldClient),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fundingAgencyController,
            decoration: InputDecoration(labelText: strings.fieldFundingAgency),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: strings.sectionClassification,
            accentColor: AppStatusColors.operations,
          ),
          AdaptiveFieldRow(
            children: [
              DropdownButtonFormField<ProjectCategory>(
                initialValue: _category,
                decoration: InputDecoration(labelText: strings.fieldCategory),
                items: ProjectCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(strings.projectCategoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              DropdownButtonFormField<ProjectStatus>(
                initialValue: _status,
                decoration: InputDecoration(labelText: strings.fieldStatus),
                items: ProjectStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(strings.projectStatusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdaptiveFieldRow(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.contractorRoleFieldLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ContractorRole>(
                    segments: ContractorRole.values
                        .map(
                          (r) => ButtonSegment(
                            value: r,
                            label: Text(strings.contractorRoleLabel(r)),
                          ),
                        )
                        .toList(),
                    selected: {_contractorRole},
                    onSelectionChanged: (s) =>
                        setState(() => _contractorRole = s.first),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.clientTypeFieldLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ClientType>(
                    segments: ClientType.values
                        .map(
                          (c) => ButtonSegment(
                            value: c,
                            label: Text(strings.clientTypeLabel(c)),
                          ),
                        )
                        .toList(),
                    selected: {_clientType},
                    onSelectionChanged: (s) =>
                        setState(() => _clientType = s.first),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: strings.sectionScopeScale,
            accentColor: AppStatusColors.operations,
          ),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: strings.fieldLocation,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              TextFormField(
                controller: _projectSizeController,
                decoration: InputDecoration(
                  labelText: strings.fieldProjectSize,
                  helperText: strings.projectSizeHelper,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _scopeOfWorksController,
            decoration: InputDecoration(labelText: strings.fieldScopeOfWorks),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          _ContractValueField(
            currency: _currency,
            amountController: _contractValueController,
            onCurrencyChanged: (c) => setState(() => _currency = c),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: strings.sectionNotes,
            accentColor: AppStatusColors.neutral,
          ),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(labelText: strings.fieldNotes),
            maxLines: 4,
          ),
          if (_isEditing && _loadedProject != null) ...[
            const SizedBox(height: 24),
            _buildAiKnowledgeExtractionSection(strings, _loadedProject!),
          ],
          if (_isEditing &&
              _loadedProject != null &&
              _loadedProject!.status == ProjectStatus.past) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: strings.projectSectionTitle,
              accentColor: AppStatusColors.success,
            ),
            _loadedProject!.experienceId == null
                ? OutlinedButton.icon(
                    onPressed: () => _addAsExperience(_loadedProject!),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(strings.addAsExperienceButton),
                  )
                : OutlinedButton.icon(
                    onPressed: () => pushSlideFade(
                      context,
                      ExperienceFormScreen(
                        experienceId: _loadedProject!.experienceId,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(strings.viewExperienceButton),
                  ),
          ],
          const SizedBox(height: 24),
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
    final strings = ref.watch(appStringsProvider);
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
                decoration: InputDecoration(labelText: strings.fieldCurrency),
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
    final strings = ref.watch(appStringsProvider);
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
          strings.liveRatesCaption(parts.join('  ·  ')),
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
            strings.fetchingRates,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      // Never show a fabricated/fallback conversion when the rate fetch fails.
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// One uploaded project document's row in the AI Knowledge Extraction
/// section — its extraction status drives which action is offered next:
/// not yet extracted -> "Extract knowledge"; extracted or reviewed ->
/// "Review & apply" (re-openable even after review, so the user can see
/// what was applied).
class _ProjectDocumentTile extends StatelessWidget {
  const _ProjectDocumentTile({
    required this.document,
    required this.strings,
    required this.isExtracting,
    required this.onExtract,
    required this.onReview,
  });

  final LibraryDocument document;
  final AppStrings strings;
  final bool isExtracting;
  final VoidCallback onExtract;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final canExtract =
        document.aiExtractionStatus == DocumentExtractionStatus.none;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(
          document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          strings.documentExtractionStatusLabel(document.aiExtractionStatus),
        ),
        trailing: canExtract
            ? OutlinedButton.icon(
                onPressed: isExtracting ? null : onExtract,
                icon: isExtracting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  isExtracting
                      ? strings.extractingLabel
                      : strings.extractKnowledgeButton,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(strings.reviewAndApplyButton),
              ),
      ),
    );
  }
}
