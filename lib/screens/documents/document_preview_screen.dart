import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/recommended_entity_chips.dart';
import 'package:jva_projecttracker/widgets/relationship_picker.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// A single document's information panel — metadata first, editing
/// secondary. Implemented as a pushed screen rather than a literal side
/// panel: this app has no master-detail/side-panel layout infrastructure
/// yet, and every other "detail" view (Company Intelligence entities,
/// Opportunity Workspace, Proposal Workspace) is already a focused full
/// screen reached the same way. See the Document Library (Milestone 4.3),
/// Decision 9.
class DocumentPreviewScreen extends ConsumerWidget {
  const DocumentPreviewScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final documentAsync = ref.watch(libraryDocumentByIdProvider(documentId));

    return Scaffold(
      appBar: AppBar(),
      body: documentAsync.when(
        data: (document) => document == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      icon: Icons.description_outlined,
                      title: document.title,
                      subtitle: strings.documentDetailsTitle,
                      accentColor: AppStatusColors.neutral,
                    ),
                  ),
                  Expanded(child: _DocumentPreviewBody(document: document)),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
      ),
    );
  }
}

class _DocumentPreviewBody extends ConsumerWidget {
  const _DocumentPreviewBody({required this.document});

  final LibraryDocument document;

  void _updateField(WidgetRef ref, LibraryDocument Function() build) {
    ref.read(libraryDocumentServiceProvider).update(build());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(strings.locale.languageCode);
    final now = DateTime.now();
    final isExpired =
        document.expiryDate != null && document.expiryDate!.isBefore(now);

    final proposals = ref.watch(proposalsStreamProvider);
    final linkedOpportunityIds = <String>{
      for (final p in proposals.value ?? const [])
        if (document.relatedProposalIds.contains(p.id)) p.opportunityId,
    }.toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        strings.documentCategoryLabel(document.category),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(
                        isExpired
                            ? strings.expiredDocumentsCountLabel(1)
                            : strings.documentStatusLabel(document.status),
                      ),
                      backgroundColor: isExpired
                          ? theme.colorScheme.errorContainer
                          : null,
                      labelStyle: isExpired
                          ? TextStyle(color: theme.colorScheme.onErrorContainer)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (document.version.isNotEmpty)
                      Chip(
                        label: Text(document.version),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (document.issueDate != null)
                  Text(
                    '${strings.fieldIssueDate}: ${dateFormat.format(document.issueDate!)}',
                  ),
                if (document.expiryDate != null)
                  Text(
                    '${strings.fieldExpiryDate}: ${dateFormat.format(document.expiryDate!)}',
                  ),
                if (document.owner != null && document.owner!.isNotEmpty)
                  Text('${strings.proposalOwnerLabel}: ${document.owner}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: strings.linkedProposalsLabel,
          accentColor: AppStatusColors.operations,
        ),
        const SizedBox(height: AppSpacing.sm),
        RelationshipPicker(
          label: strings.linkedProposalsLabel,
          optionsAsync: proposals,
          idOf: (p) => p.id,
          nameOf: (p) => p.title,
          selectedIds: document.relatedProposalIds.toSet(),
          onToggle: (id, selected) => _updateField(ref, () {
            final ids = {...document.relatedProposalIds};
            if (selected) {
              ids.add(id);
            } else {
              ids.remove(id);
            }
            return _copyWith(relatedProposalIds: ids.toList());
          }),
        ),
        if (linkedOpportunityIds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          RecommendedEntityChips(
            label: strings.relatedOpportunitiesLabel,
            ids: linkedOpportunityIds,
            optionsAsync: ref.watch(opportunitiesStreamProvider),
            idOf: (o) => o.id,
            nameOf: (o) => o.title,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: strings.sectionRelationships,
          accentColor: AppStatusColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        RelationshipPicker(
          label: strings.relatedBusinessUnitsLabel,
          optionsAsync: ref.watch(businessUnitsStreamProvider),
          idOf: (b) => b.id,
          nameOf: (b) => b.name,
          selectedIds: document.businessUnitIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.businessUnitIds,
              id,
              selected,
              (v) => _copyWith(businessUnitIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedProductsLabel,
          optionsAsync: ref.watch(productsStreamProvider),
          idOf: (p) => p.id,
          nameOf: (p) => p.name,
          selectedIds: document.productIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.productIds,
              id,
              selected,
              (v) => _copyWith(productIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.servicesTitle,
          optionsAsync: ref.watch(servicesStreamProvider),
          idOf: (s) => s.id,
          nameOf: (s) => s.name,
          selectedIds: document.serviceIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.serviceIds,
              id,
              selected,
              (v) => _copyWith(serviceIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedCapabilitiesLabel,
          optionsAsync: ref.watch(capabilitiesStreamProvider),
          idOf: (c) => c.id,
          nameOf: (c) => c.name,
          selectedIds: document.capabilityIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.capabilityIds,
              id,
              selected,
              (v) => _copyWith(capabilityIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedTechnologiesLabel,
          optionsAsync: ref.watch(technologiesStreamProvider),
          idOf: (t) => t.id,
          nameOf: (t) => t.name,
          selectedIds: document.technologyIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.technologyIds,
              id,
              selected,
              (v) => _copyWith(technologyIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedIndustriesLabel,
          optionsAsync: ref.watch(industriesStreamProvider),
          idOf: (i) => i.id,
          nameOf: (i) => i.name,
          selectedIds: document.industryIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.industryIds,
              id,
              selected,
              (v) => _copyWith(industryIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedExperiencesLabel,
          optionsAsync: ref.watch(experiencesStreamProvider),
          idOf: (e) => e.id,
          nameOf: (e) => e.title,
          selectedIds: document.experienceIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.experienceIds,
              id,
              selected,
              (v) => _copyWith(experienceIds: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RelationshipPicker(
          label: strings.relatedKnowledgeArticlesLabel,
          optionsAsync: ref.watch(knowledgeArticlesStreamProvider),
          idOf: (k) => k.id,
          nameOf: (k) => k.title,
          selectedIds: document.knowledgeArticleIds.toSet(),
          onToggle: (id, selected) => _updateField(
            ref,
            () => _toggle(
              document.knowledgeArticleIds,
              id,
              selected,
              (v) => _copyWith(knowledgeArticleIds: v),
            ),
          ),
        ),
      ],
    );
  }

  LibraryDocument _toggle(
    List<String> current,
    String id,
    bool selected,
    LibraryDocument Function(List<String>) apply,
  ) {
    final ids = {...current};
    if (selected) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    return apply(ids.toList());
  }

  LibraryDocument _copyWith({
    List<String>? businessUnitIds,
    List<String>? productIds,
    List<String>? serviceIds,
    List<String>? capabilityIds,
    List<String>? technologyIds,
    List<String>? industryIds,
    List<String>? experienceIds,
    List<String>? knowledgeArticleIds,
    List<String>? relatedProposalIds,
  }) {
    return LibraryDocument(
      id: document.id,
      title: document.title,
      category: document.category,
      description: document.description,
      version: document.version,
      status: document.status,
      issueDate: document.issueDate,
      expiryDate: document.expiryDate,
      owner: document.owner,
      storagePath: document.storagePath,
      downloadUrl: document.downloadUrl,
      fileName: document.fileName,
      contentType: document.contentType,
      fileSizeBytes: document.fileSizeBytes,
      businessUnitIds: businessUnitIds ?? document.businessUnitIds,
      productIds: productIds ?? document.productIds,
      serviceIds: serviceIds ?? document.serviceIds,
      capabilityIds: capabilityIds ?? document.capabilityIds,
      technologyIds: technologyIds ?? document.technologyIds,
      industryIds: industryIds ?? document.industryIds,
      experienceIds: experienceIds ?? document.experienceIds,
      knowledgeArticleIds: knowledgeArticleIds ?? document.knowledgeArticleIds,
      relatedProposalIds: relatedProposalIds ?? document.relatedProposalIds,
      createdAt: document.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
