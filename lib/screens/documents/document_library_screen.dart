import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/screens/documents/document_preview_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';

/// The company-wide Document Library — a 9th Company Intelligence-graph
/// entity (see `library_document.dart`). Optionally scoped to one proposal
/// (mirrors `ProductsScreen`'s optional `businessUnitId` scoping): when
/// [proposalId] is set, only documents already linked to that proposal are
/// shown, and newly-added documents are linked to it automatically.
class DocumentLibraryScreen extends ConsumerStatefulWidget {
  const DocumentLibraryScreen({super.key, this.proposalId});

  final String? proposalId;

  @override
  ConsumerState<DocumentLibraryScreen> createState() =>
      _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends ConsumerState<DocumentLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LibraryDocument> _applyFilter(List<LibraryDocument> documents) {
    if (_query.isEmpty) return documents;
    final query = _query.toLowerCase();
    return documents
        .where(
          (d) =>
              d.title.toLowerCase().contains(query) ||
              d.description.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final documentsAsync = widget.proposalId != null
        ? ref.watch(documentsForProposalProvider(widget.proposalId!))
        : ref.watch(libraryDocumentsStreamProvider);

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
              icon: Icons.folder_open_outlined,
              title: strings.documentLibraryTitle,
              subtitle: null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SearchBar(
              controller: _searchController,
              hintText: strings.searchDocumentsHint,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: documentsAsync.when(
              data: (documents) {
                final filtered = _applyFilter(documents);
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: documents.isEmpty
                        ? strings.noDocumentsYet
                        : strings.noDocumentsMatchFilter,
                  );
                }
                return AdaptiveListGrid<LibraryDocument>(
                  items: filtered,
                  itemBuilder: (context, doc) => _DocumentTile(document: doc),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(strings.errorPrefix(e))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AddDocumentDialog(proposalId: widget.proposalId),
        ),
        tooltip: strings.addDocumentTitle,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document});

  final LibraryDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired =
        document.expiryDate != null && document.expiryDate!.isBefore(now);

    return EntityCard(
      title: document.title,
      subtitle: strings.documentCategoryLabel(document.category),
      onTap: () => pushSlideFade(
        context,
        DocumentPreviewScreen(documentId: document.id),
      ),
      statusBadge: Chip(
        label: Text(
          isExpired
              ? strings.expiredDocumentsCountLabel(1)
              : strings.documentStatusLabel(document.status),
        ),
        backgroundColor: isExpired ? theme.colorScheme.errorContainer : null,
        labelStyle: isExpired
            ? TextStyle(color: theme.colorScheme.onErrorContainer)
            : null,
        visualDensity: VisualDensity.compact,
      ),
      metaChips: [
        if (document.version.isNotEmpty)
          Chip(
            label: Text(document.version),
            visualDensity: VisualDensity.compact,
          ),
        if (document.expiryDate != null)
          Chip(
            label: Text(
              DateFormat.yMMMd(
                strings.locale.languageCode,
              ).format(document.expiryDate!),
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _AddDocumentDialog extends ConsumerStatefulWidget {
  const _AddDocumentDialog({this.proposalId});

  final String? proposalId;

  @override
  ConsumerState<_AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends ConsumerState<_AddDocumentDialog> {
  final _titleController = TextEditingController();
  final _versionController = TextEditingController();
  DocumentCategory _category = DocumentCategory.other;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  PlatformFile? _chosenFile;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _chosenFile = result.files.first);
  }

  Future<void> _pickDate({required bool isIssueDate}) async {
    final initial = (isIssueDate ? _issueDate : _expiryDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isIssueDate) {
        _issueDate = picked;
      } else {
        _expiryDate = picked;
      }
    });
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _chosenFile != null;

  Future<void> _submit() async {
    final file = _chosenFile;
    if (!_canSave || file == null || file.bytes == null) return;

    setState(() => _saving = true);
    final service = ref.read(libraryDocumentServiceProvider);
    final now = DateTime.now();

    try {
      final id = await service.create(
        LibraryDocument(
          id: '',
          title: _titleController.text.trim(),
          category: _category,
          version: _versionController.text.trim(),
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          relatedProposalIds: widget.proposalId != null
              ? [widget.proposalId!]
              : const [],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final downloadUrl = await service.uploadFile(
        documentId: id,
        bytes: file.bytes!,
        fileName: file.name,
        contentType: 'application/octet-stream',
      );

      await service.update(
        LibraryDocument(
          id: id,
          title: _titleController.text.trim(),
          category: _category,
          version: _versionController.text.trim(),
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          storagePath: 'documents/$id/${file.name}',
          downloadUrl: downloadUrl,
          fileName: file.name,
          fileSizeBytes: file.size,
          relatedProposalIds: widget.proposalId != null
              ? [widget.proposalId!]
              : const [],
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dateFormat = DateFormat.yMMMd(strings.locale.languageCode);

    return AlertDialog(
      title: Text(strings.addDocumentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.fieldDocumentTitle,
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<DocumentCategory>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: strings.fieldDocumentCategory,
              ),
              items: DocumentCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(strings.documentCategoryLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _versionController,
              decoration: InputDecoration(
                labelText: strings.fieldDocumentVersion,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => _pickDate(isIssueDate: true),
              child: InputDecorator(
                decoration: InputDecoration(labelText: strings.fieldIssueDate),
                child: Text(
                  _issueDate == null ? '' : dateFormat.format(_issueDate!),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => _pickDate(isIssueDate: false),
              child: InputDecorator(
                decoration: InputDecoration(labelText: strings.fieldExpiryDate),
                child: Text(
                  _expiryDate == null ? '' : dateFormat.format(_expiryDate!),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_chosenFile?.name ?? strings.chooseFileButton),
            ),
            if (_chosenFile == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  strings.noFileChosenLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving || !_canSave ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.addDocumentButton),
        ),
      ],
    );
  }
}
