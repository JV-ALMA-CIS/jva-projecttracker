import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// One relationship-suggestion category (Business Units, Industries, ...) —
/// binds the extracted ID list to the knowledge-graph stream that resolves
/// each ID to a display name, and to the [Project] field the accepted IDs
/// eventually get merged into.
class _RelationshipCategory {
  const _RelationshipCategory({
    required this.key,
    required this.label,
    required this.extractedIds,
    required this.currentIds,
    required this.optionsAsync,
    required this.idOf,
    required this.nameOf,
  });

  final String key;
  final String label;
  final List<String> extractedIds;
  final List<String> currentIds;
  final AsyncValue<List<dynamic>> optionsAsync;
  final String Function(dynamic) idOf;
  final String Function(dynamic) nameOf;
}

/// Step 3 of Upload -> Extract -> Review -> Approve: shows what
/// `extractProjectDocumentKnowledge` found in one document and lets the
/// user selectively accept it. Basic-info fields are only offered where the
/// [Project] doesn't already have a value (never silently overwrites what a
/// human already entered — the same rule `_addAsExperience` in
/// `project_form_screen.dart` already follows for its own mapping).
/// Relationship suggestions are additive (merged with the project's
/// existing IDs, never replacing them). Narrative fields have no home on
/// [Project] itself — they're shown for awareness only; a future promotion
/// to a Company Experience (`project_form_screen.dart`'s
/// `_addAsExperience`) is where they get a permanent home.
class ProjectExtractionReviewScreen extends ConsumerStatefulWidget {
  const ProjectExtractionReviewScreen({
    super.key,
    required this.documentId,
    required this.projectId,
  });

  final String documentId;
  final String projectId;

  @override
  ConsumerState<ProjectExtractionReviewScreen> createState() =>
      _ProjectExtractionReviewScreenState();
}

class _ProjectExtractionReviewScreenState
    extends ConsumerState<ProjectExtractionReviewScreen> {
  final Set<String> _acceptedBasicFields = {};
  final Map<String, Set<String>> _acceptedRelationshipIds = {};
  bool _applying = false;
  bool _seededDefaults = false;

  /// Suggestion names the user has already accepted ("Create & link") for
  /// this review session — keyed the same way as [_acceptedRelationshipIds]
  /// (`businessUnitIds`/`industryIds`/`serviceIds`/`capabilityIds`) so a
  /// suggestion chip can flip to its "created" state and never be created
  /// twice if the widget rebuilds. The new entity's real ID is added
  /// directly into [_acceptedRelationshipIds] the moment it's created —
  /// this set only tracks which *names* are now spoken for, for the UI.
  final Map<String, Set<String>> _acceptedSuggestionNames = {};
  final Set<String> _creatingSuggestion = {};

  /// True once a project name still looks like an uploaded file name rather
  /// than a real title — e.g. "CPAR_Ross_I_2019.pdf" or its
  /// `_titleFromFileName` result "CPAR Ross I 2019". Heuristic, not exact:
  /// used only to decide whether offering `aiExtractedProjectTitle` as a
  /// replacement is worth showing, never to silently overwrite a name a
  /// human actually typed.
  bool _looksLikeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(
      r'\.(pdf|docx?|xlsx?|txt|png|jpe?g|webp|heic)$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  void _seedDefaults(LibraryDocument doc, Project project) {
    if (_seededDefaults) return;
    _seededDefaults = true;
    // Pre-check every suggestion that has somewhere honest to go — the user
    // is reviewing/deselecting, not building the selection from scratch.
    if (_looksLikeFileName(project.name) &&
        (doc.aiExtractedProjectTitle ?? '').trim().isNotEmpty) {
      _acceptedBasicFields.add('title');
    }
    if (project.client.trim().isEmpty && doc.aiExtractedClient != null) {
      _acceptedBasicFields.add('client');
    }
    if (project.fundingAgency.trim().isEmpty &&
        doc.aiExtractedFundingAgency != null) {
      _acceptedBasicFields.add('fundingAgency');
    }
    if (project.location.trim().isEmpty && doc.aiExtractedLocation != null) {
      _acceptedBasicFields.add('location');
    }
    if (project.contractValueAmount == null &&
        doc.aiExtractedContractValueAmount != null) {
      _acceptedBasicFields.add('contractValue');
    }
    if (project.contractValueAmount == null &&
        doc.aiExtractedContractValueCurrency != null) {
      _acceptedBasicFields.add('contractValueCurrency');
    }
    if (project.startDate == null && doc.aiExtractedStartDate != null) {
      _acceptedBasicFields.add('startDate');
    }
    if (project.endDate == null && doc.aiExtractedCompletionDate != null) {
      _acceptedBasicFields.add('completionDate');
    }
    if (project.scopeOfWorks.trim().isEmpty &&
        doc.aiExtractedDeliverables.isNotEmpty) {
      _acceptedBasicFields.add('scopeOfWorks');
    }
    if (project.description.trim().isEmpty &&
        (doc.aiExtractedDescription ?? '').trim().isNotEmpty) {
      _acceptedBasicFields.add('description');
    }
    // A completion date already in the past is strong, direct evidence the
    // job is done — offered regardless of the project's current status
    // (including already-`past`, where it's simply a no-op accept).
    if (project.status != ProjectStatus.past &&
        doc.aiExtractedCompletionDate != null &&
        doc.aiExtractedCompletionDate!.isBefore(DateTime.now())) {
      _acceptedBasicFields.add('statusPast');
    }
    if (project.lessonsLearned.trim().isEmpty &&
        (doc.aiExtractedLessonsLearned.isNotEmpty ||
            doc.aiExtractedKeyAchievements.isNotEmpty)) {
      _acceptedBasicFields.add('lessonsLearned');
    }
    for (final category in _relationshipKeys) {
      _acceptedRelationshipIds[category] = {};
    }
  }

  static const _relationshipKeys = [
    'businessUnitIds',
    'industryIds',
    'technologyIds',
    'serviceIds',
    'capabilityIds',
    'productIds',
  ];

  String _slugify(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return slug.isEmpty ? 'entity' : slug;
  }

  /// Creates one Company Intelligence entity from a suggested name and adds
  /// its real ID straight into [_acceptedRelationshipIds], as if it had
  /// been an existing-ID chip all along — so `_apply` doesn't need to know
  /// the difference between "matched an existing graph entity" and "the
  /// user just created one from a suggestion." Any authenticated user who
  /// can reach this screen can call this (same `isAuthenticated()` write
  /// rule as every other Company Intelligence collection — no admin role
  /// involved), since create-and-link is the primary, everyday path for
  /// keeping the graph populated, not an admin tool.
  Future<void> _createAndLink({
    required String relationshipKey,
    required String suggestionKey,
    required String name,
  }) async {
    setState(() => _creatingSuggestion.add('$relationshipKey::$name'));
    final now = DateTime.now();
    String newId;

    switch (relationshipKey) {
      case 'businessUnitIds':
        newId = await ref
            .read(businessUnitServiceProvider)
            .create(
              BusinessUnit(
                id: '',
                name: name,
                slug: _slugify(name),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'industryIds':
        newId = await ref
            .read(industryServiceProvider)
            .create(
              Industry(id: '', name: name, createdAt: now, updatedAt: now),
            );
      case 'serviceIds':
        newId = await ref
            .read(serviceServiceProvider)
            .create(
              ServiceModel(
                id: '',
                name: name,
                slug: _slugify(name),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'capabilityIds':
        newId = await ref
            .read(capabilityServiceProvider)
            .create(
              Capability(
                id: '',
                name: name,
                slug: _slugify(name),
                createdAt: now,
                updatedAt: now,
              ),
            );
      default:
        setState(() => _creatingSuggestion.remove('$relationshipKey::$name'));
        return;
    }

    if (!mounted) return;
    setState(() {
      _creatingSuggestion.remove('$relationshipKey::$name');
      _acceptedSuggestionNames.putIfAbsent(suggestionKey, () => {}).add(name);
      _acceptedRelationshipIds
          .putIfAbsent(relationshipKey, () => {})
          .add(newId);
    });
  }

  Future<void> _apply(LibraryDocument doc, Project project) async {
    setState(() => _applying = true);

    List<String>? merge(
      String key,
      List<String> extracted,
      List<String> current,
    ) {
      final accepted = _acceptedRelationshipIds[key] ?? const {};
      if (accepted.isEmpty) return null;
      return {...current, ...accepted}.toList();
    }

    // Joins the extraction's lessons-learned + key-achievements bullets into
    // one free-text block — Project.lessonsLearned is a single string (see
    // its own doc comment: the seed content for a future Experience/
    // KnowledgeArticle promotion), not a list, so this is where the two
    // extracted lists collapse into it. Achievements are kept alongside
    // lessons here (rather than dropped) since Project has no separate
    // "achievements" field of its own — promoteProjectToExperience still
    // reads the richer per-list `aiExtractedKeyAchievements`/
    // `aiExtractedLessonsLearned` fields directly off the reviewed document
    // for Experience.achievements/Experience.lessonsLearned, so nothing is
    // lost there; this joined text is purely for the Project's own record.
    String? joinedLessonsLearned() {
      final lines = [
        ...doc.aiExtractedLessonsLearned,
        ...doc.aiExtractedKeyAchievements,
      ];
      return lines.isEmpty ? null : lines.map((l) => '- $l').join('\n');
    }

    // A single copyWith call — every field not explicitly passed here falls
    // through to `?? this.<field>` inside copyWith itself, so every other
    // Project field (projectManager, plannedBudgetAmount,
    // currentExpenditureAmount, forecastAmount, knowledgeArticleIds, notes,
    // teamMembers, etc.) survives Apply untouched. A prior version of this
    // method reconstructed a second `Project(...)` by hand to layer in
    // startDate/endDate (copyWith already accepts both — that reconstruction
    // was unnecessary) and silently dropped every field it forgot to list
    // explicitly on every Apply. Never hand-reconstruct Project here again.
    final updated = project.copyWith(
      name: _acceptedBasicFields.contains('title')
          ? doc.aiExtractedProjectTitle
          : null,
      client: _acceptedBasicFields.contains('client')
          ? doc.aiExtractedClient
          : null,
      fundingAgency: _acceptedBasicFields.contains('fundingAgency')
          ? doc.aiExtractedFundingAgency
          : null,
      location: _acceptedBasicFields.contains('location')
          ? doc.aiExtractedLocation
          : null,
      contractValueAmount: _acceptedBasicFields.contains('contractValue')
          ? doc.aiExtractedContractValueAmount
          : null,
      contractValueCurrency:
          _acceptedBasicFields.contains('contractValueCurrency')
          ? doc.aiExtractedContractValueCurrency
          : null,
      startDate: _acceptedBasicFields.contains('startDate')
          ? doc.aiExtractedStartDate
          : null,
      endDate: _acceptedBasicFields.contains('completionDate')
          ? doc.aiExtractedCompletionDate
          : null,
      scopeOfWorks: _acceptedBasicFields.contains('scopeOfWorks')
          ? doc.aiExtractedDeliverables.map((d) => '- $d').join('\n')
          : null,
      description: _acceptedBasicFields.contains('description')
          ? doc.aiExtractedDescription
          : null,
      status: _acceptedBasicFields.contains('statusPast')
          ? ProjectStatus.past
          : null,
      lessonsLearned: _acceptedBasicFields.contains('lessonsLearned')
          ? joinedLessonsLearned()
          : null,
      businessUnitIds: merge(
        'businessUnitIds',
        doc.aiExtractedBusinessUnitIds,
        project.businessUnitIds,
      ),
      industryIds: merge(
        'industryIds',
        doc.aiExtractedIndustryIds,
        project.industryIds,
      ),
      technologyIds: merge(
        'technologyIds',
        doc.aiExtractedTechnologyIds,
        project.technologyIds,
      ),
      serviceIds: merge(
        'serviceIds',
        doc.aiExtractedServiceIds,
        project.serviceIds,
      ),
      capabilityIds: merge(
        'capabilityIds',
        doc.aiExtractedCapabilityIds,
        project.capabilityIds,
      ),
      productIds: merge(
        'productIds',
        doc.aiExtractedProductIds,
        project.productIds,
      ),
    );

    await ref.read(projectServiceProvider).update(updated);
    await ref
        .read(libraryDocumentServiceProvider)
        .update(
          doc.copyWithExtractionStatus(DocumentExtractionStatus.reviewed),
        );

    if (!mounted) return;
    final strings = ref.read(appStringsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.extractionAppliedMessage)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final docAsync = ref.watch(libraryDocumentByIdProvider(widget.documentId));
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: PageHeader(
              icon: Icons.fact_check_outlined,
              title: strings.projectExtractionReviewTitle,
              subtitle: null,
              accentColor: AppStatusColors.operations,
            ),
          ),
          Expanded(
            child: docAsync.when(
              data: (doc) => projectAsync.when(
                data: (project) {
                  if (doc == null || project == null) {
                    return const SizedBox.shrink();
                  }
                  _seedDefaults(doc, project);
                  return _buildBody(strings, doc, project);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppStrings strings, LibraryDocument doc, Project project) {
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SectionHeader(
          title: strings.extractionBasicInfoSectionTitle,
          accentColor: AppStatusColors.info,
        ),
        _buildBasicInfoCard(strings, doc, project, dateFormat),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: strings.extractionRelationshipsSectionTitle,
          accentColor: AppStatusColors.info,
        ),
        ..._buildRelationshipCategories(strings, doc, project),
        ..._buildSuggestedNewEntities(strings, doc),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: strings.extractionNarrativeSectionTitle,
          accentColor: AppStatusColors.ai,
        ),
        _buildNarrativeCard(strings, doc),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: FilledButton.icon(
            onPressed: _applying ? null : () => _apply(doc, project),
            icon: _applying
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(strings.applyButton),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildBasicInfoCard(
    AppStrings strings,
    LibraryDocument doc,
    Project project,
    DateFormat dateFormat,
  ) {
    final rows = <Widget>[];

    void addCheckable({
      required String key,
      required String label,
      required String? currentValue,
      required String? extractedValue,
      List<String> alsoToggles = const [],
    }) {
      if (extractedValue == null || extractedValue.trim().isEmpty) return;
      final alreadySet = currentValue != null && currentValue.trim().isNotEmpty;
      rows.add(
        CheckboxListTile(
          value: _acceptedBasicFields.contains(key),
          onChanged: alreadySet
              ? null
              : (checked) => setState(() {
                  for (final k in [key, ...alsoToggles]) {
                    if (checked ?? false) {
                      _acceptedBasicFields.add(k);
                    } else {
                      _acceptedBasicFields.remove(k);
                    }
                  }
                }),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label),
          subtitle: Text(
            alreadySet
                ? '${strings.alreadySetFieldNote} ($extractedValue)'
                : extractedValue,
          ),
        ),
      );
    }

    // Ordered per the bid-foundation priority: title, then the three
    // bid-foundation fields (contract value, funding agency, scope of
    // works) ahead of the more contextual client/location/dates/
    // description/lessons fields.
    addCheckable(
      key: 'title',
      label: strings.fieldProjectName,
      currentValue: _looksLikeFileName(project.name) ? null : project.name,
      extractedValue: doc.aiExtractedProjectTitle,
    );
    addCheckable(
      key: 'contractValue',
      label: strings.fieldContractValue,
      currentValue: project.contractValueAmount?.toStringAsFixed(0),
      extractedValue: doc.aiExtractedContractValueAmount == null
          ? null
          : '${doc.aiExtractedContractValueAmount!.toStringAsFixed(0)} ${doc.aiExtractedContractValueCurrency ?? project.contractValueCurrency}',
      alsoToggles: const ['contractValueCurrency'],
    );
    addCheckable(
      key: 'fundingAgency',
      label: strings.fieldFundingAgency,
      currentValue: project.fundingAgency.trim().isEmpty
          ? null
          : project.fundingAgency,
      extractedValue: doc.aiExtractedFundingAgency,
    );
    addCheckable(
      key: 'scopeOfWorks',
      label: strings.fieldScopeOfWorks,
      currentValue: project.scopeOfWorks.trim().isEmpty
          ? null
          : project.scopeOfWorks,
      extractedValue: doc.aiExtractedDeliverables.isEmpty
          ? null
          : doc.aiExtractedDeliverables.join('; '),
    );
    addCheckable(
      key: 'client',
      label: strings.fieldClient,
      currentValue: project.client,
      extractedValue: doc.aiExtractedClient,
    );
    addCheckable(
      key: 'location',
      label: strings.fieldLocation,
      currentValue: project.location,
      extractedValue: doc.aiExtractedLocation,
    );
    addCheckable(
      key: 'startDate',
      label: strings.fieldStartDate,
      currentValue: project.startDate == null
          ? null
          : dateFormat.format(project.startDate!),
      extractedValue: doc.aiExtractedStartDate == null
          ? null
          : dateFormat.format(doc.aiExtractedStartDate!),
    );
    addCheckable(
      key: 'completionDate',
      label: strings.fieldEndDate,
      currentValue: project.endDate == null
          ? null
          : dateFormat.format(project.endDate!),
      extractedValue: doc.aiExtractedCompletionDate == null
          ? null
          : dateFormat.format(doc.aiExtractedCompletionDate!),
    );
    addCheckable(
      key: 'description',
      label: strings.fieldDescription,
      currentValue: project.description.trim().isEmpty
          ? null
          : project.description,
      extractedValue: doc.aiExtractedDescription,
    );
    addCheckable(
      key: 'lessonsLearned',
      label: strings.fieldLessonsLearned,
      currentValue: project.lessonsLearned.trim().isEmpty
          ? null
          : project.lessonsLearned,
      extractedValue:
          [
            ...doc.aiExtractedLessonsLearned,
            ...doc.aiExtractedKeyAchievements,
          ].isEmpty
          ? null
          : [
              ...doc.aiExtractedLessonsLearned,
              ...doc.aiExtractedKeyAchievements,
            ].join('; '),
    );
    // Status is a boolean toggle, not a "was already set" string comparison
    // like the others — offered whenever the extraction found a completion
    // date already in the past, and stays checkable even if the project is
    // already `past` (a harmless no-op accept in that case).
    if (project.status != ProjectStatus.past &&
        doc.aiExtractedCompletionDate != null &&
        doc.aiExtractedCompletionDate!.isBefore(DateTime.now())) {
      rows.add(
        CheckboxListTile(
          value: _acceptedBasicFields.contains('statusPast'),
          onChanged: (checked) => setState(() {
            if (checked ?? false) {
              _acceptedBasicFields.add('statusPast');
            } else {
              _acceptedBasicFields.remove('statusPast');
            }
          }),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(strings.fieldStatus),
          subtitle: Text(
            '${strings.projectStatusLabel(project.status)} → '
            '${strings.projectStatusLabel(ProjectStatus.past)}',
          ),
        ),
      );
    }

    // Country/contract duration have no matching Project field — shown as
    // read-only context (they carry forward into an Experience promotion
    // instead), not a checkable field that silently goes nowhere.
    final infoOnly = <Widget>[];
    if ((doc.aiExtractedCountry ?? '').trim().isNotEmpty) {
      infoOnly.add(
        ListTile(
          dense: true,
          title: Text(strings.fieldCountry),
          subtitle: Text(doc.aiExtractedCountry!),
        ),
      );
    }
    if ((doc.aiExtractedContractDuration ?? '').trim().isNotEmpty) {
      infoOnly.add(
        ListTile(
          dense: true,
          title: Text(strings.fieldContractDuration),
          subtitle: Text(doc.aiExtractedContractDuration!),
        ),
      );
    }

    if (rows.isEmpty && infoOnly.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(strings.noExtractionDataMessage),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [...rows, ...infoOnly]),
    );
  }

  List<Widget> _buildRelationshipCategories(
    AppStrings strings,
    LibraryDocument doc,
    Project project,
  ) {
    final categories = <_RelationshipCategory>[
      _RelationshipCategory(
        key: 'businessUnitIds',
        label: strings.businessUnitsTitle,
        extractedIds: doc.aiExtractedBusinessUnitIds,
        currentIds: project.businessUnitIds,
        optionsAsync: ref.watch(businessUnitsStreamProvider),
        idOf: (b) => (b as BusinessUnit).id,
        nameOf: (b) => (b as BusinessUnit).name,
      ),
      _RelationshipCategory(
        key: 'industryIds',
        label: strings.industriesTitle,
        extractedIds: doc.aiExtractedIndustryIds,
        currentIds: project.industryIds,
        optionsAsync: ref.watch(industriesStreamProvider),
        idOf: (i) => (i as Industry).id,
        nameOf: (i) => (i as Industry).name,
      ),
      _RelationshipCategory(
        key: 'technologyIds',
        label: strings.technologiesTitle,
        extractedIds: doc.aiExtractedTechnologyIds,
        currentIds: project.technologyIds,
        optionsAsync: ref.watch(technologiesStreamProvider),
        idOf: (t) => (t as Technology).id,
        nameOf: (t) => (t as Technology).name,
      ),
      _RelationshipCategory(
        key: 'serviceIds',
        label: strings.servicesTitle,
        extractedIds: doc.aiExtractedServiceIds,
        currentIds: project.serviceIds,
        optionsAsync: ref.watch(servicesStreamProvider),
        idOf: (s) => (s as ServiceModel).id,
        nameOf: (s) => (s as ServiceModel).name,
      ),
      _RelationshipCategory(
        key: 'capabilityIds',
        label: strings.capabilitiesTitle,
        extractedIds: doc.aiExtractedCapabilityIds,
        currentIds: project.capabilityIds,
        optionsAsync: ref.watch(capabilitiesStreamProvider),
        idOf: (c) => (c as Capability).id,
        nameOf: (c) => (c as Capability).name,
      ),
      _RelationshipCategory(
        key: 'productIds',
        label: strings.productsTitle,
        extractedIds: doc.aiExtractedProductIds,
        currentIds: project.productIds,
        optionsAsync: ref.watch(productsStreamProvider),
        idOf: (p) => (p as Product).id,
        nameOf: (p) => (p as Product).name,
      ),
    ];
    final widgets = <Widget>[];
    for (final category in categories) {
      final newIds = category.extractedIds
          .where((id) => !category.currentIds.contains(id))
          .toList();
      if (newIds.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  category.optionsAsync.when(
                    data: (options) {
                      final byId = {
                        for (final o in options)
                          category.idOf(o): category.nameOf(o),
                      };
                      return Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final id in newIds)
                            FilterChip(
                              label: Text(byId[id] ?? id),
                              selected:
                                  _acceptedRelationshipIds[category.key]
                                      ?.contains(id) ??
                                  false,
                              onSelected: (selected) => setState(() {
                                final set = _acceptedRelationshipIds
                                    .putIfAbsent(category.key, () => {});
                                if (selected) {
                                  set.add(id);
                                } else {
                                  set.remove(id);
                                }
                              }),
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Renders one "Suggested — not yet in the company graph" card per
  /// category with a non-empty `aiSuggested*Names` list — the create-and-
  /// link path (see [_createAndLink]) for a kind of work the document
  /// clearly implies but that had no adequate match in the knowledge graph
  /// at extraction time. Distinct from [_buildRelationshipCategories]:
  /// those chips link to entities that already exist; these chips create a
  /// new one only on explicit accept, never automatically.
  List<Widget> _buildSuggestedNewEntities(
    AppStrings strings,
    LibraryDocument doc,
  ) {
    final categories = [
      (
        relationshipKey: 'businessUnitIds',
        suggestionKey: 'businessUnitNames',
        label: strings.businessUnitsTitle,
        names: doc.aiSuggestedBusinessUnitNames,
      ),
      (
        relationshipKey: 'industryIds',
        suggestionKey: 'industryNames',
        label: strings.industriesTitle,
        names: doc.aiSuggestedIndustryNames,
      ),
      (
        relationshipKey: 'serviceIds',
        suggestionKey: 'serviceNames',
        label: strings.servicesTitle,
        names: doc.aiSuggestedServiceNames,
      ),
      (
        relationshipKey: 'capabilityIds',
        suggestionKey: 'capabilityNames',
        label: strings.capabilitiesTitle,
        names: doc.aiSuggestedCapabilityNames,
      ),
    ];

    final anyNames = categories.any((c) => c.names.isNotEmpty);
    if (!anyNames) return const [];

    final widgets = <Widget>[
      const SizedBox(height: AppSpacing.md),
      Text(
        strings.suggestedNewEntitiesSectionTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        strings.suggestedNewEntitiesHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];

    for (final category in categories) {
      if (category.names.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final name in category.names)
                        _buildSuggestionChip(
                          strings: strings,
                          relationshipKey: category.relationshipKey,
                          suggestionKey: category.suggestionKey,
                          name: name,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSuggestionChip({
    required AppStrings strings,
    required String relationshipKey,
    required String suggestionKey,
    required String name,
  }) {
    final accepted =
        _acceptedSuggestionNames[suggestionKey]?.contains(name) ?? false;
    final creating = _creatingSuggestion.contains('$relationshipKey::$name');

    if (accepted) {
      return Chip(
        avatar: const Icon(Icons.check_circle_outline, size: 18),
        label: Text('$name — ${strings.suggestionCreatedAndLinkedLabel}'),
      );
    }

    return ActionChip(
      avatar: creating
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_circle_outline, size: 18),
      label: Text('$name — ${strings.createAndLinkButton}'),
      onPressed: creating
          ? null
          : () => _createAndLink(
              relationshipKey: relationshipKey,
              suggestionKey: suggestionKey,
              name: name,
            ),
    );
  }

  Widget _buildNarrativeCard(AppStrings strings, LibraryDocument doc) {
    final groups = <(String, List<String>)>[
      (strings.teamDisciplinesLabel, doc.aiExtractedTeamDisciplines),
      (strings.deliverablesLabel, doc.aiExtractedDeliverables),
      (strings.equipmentLabel, doc.aiExtractedEquipment),
      (strings.extractionRisksLabel, doc.aiExtractedRisks),
      (strings.successFactorsLabel, doc.aiExtractedSuccessFactors),
      (strings.extractionLessonsLearnedLabel, doc.aiExtractedLessonsLearned),
      (strings.certificationsLabel, doc.aiExtractedCertifications),
      (strings.standardsLabel, doc.aiExtractedStandards),
      (strings.keyAchievementsLabel, doc.aiExtractedKeyAchievements),
    ].where((g) => g.$2.isNotEmpty).toList();

    if (groups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(strings.noExtractionDataMessage),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, items) in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
