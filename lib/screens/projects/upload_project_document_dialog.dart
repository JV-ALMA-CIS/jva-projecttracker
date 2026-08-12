import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Best-effort file-extension -> MIME type mapping. Unlike the Document
/// Library's own upload dialog (which hardcodes `application/octet-stream`
/// since nothing there ever reads the file's *content*), an accurate
/// content type here is load-bearing: `extractProjectDocumentKnowledge`
/// sends it to Gemini as `inlineData.mimeType`, and a wrong/generic type
/// can make the model unable to read the attachment at all.
String _guessMimeType(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'txt' => 'text/plain',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}

/// Uploads a document against a Project for AI Knowledge Extraction —
/// same two-phase create-then-upload-then-update flow as the Document
/// Library's own `_AddDocumentDialog` (`document_library_screen.dart`),
/// reusing `LibraryDocumentService`/`LibraryDocument` directly, just scoped
/// with `projectId` instead of `proposalId` and skipping the
/// compliance-oriented fields (version/issue/expiry) that don't apply to a
/// project-record upload.
Future<void> showUploadProjectDocumentDialog(
  BuildContext context, {
  required String projectId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _UploadProjectDocumentDialog(projectId: projectId),
  );
}

class _UploadProjectDocumentDialog extends ConsumerStatefulWidget {
  const _UploadProjectDocumentDialog({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_UploadProjectDocumentDialog> createState() =>
      _UploadProjectDocumentDialogState();
}

class _UploadProjectDocumentDialogState
    extends ConsumerState<_UploadProjectDocumentDialog> {
  final _titleController = TextEditingController();
  DocumentCategory _category = DocumentCategory.previousProjectEvidence;
  PlatformFile? _chosenFile;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _chosenFile = result.files.first;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = result.files.first.name;
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
    final contentType = _guessMimeType(file.name);

    try {
      final id = await service.create(
        LibraryDocument(
          id: '',
          title: _titleController.text.trim(),
          category: _category,
          projectId: widget.projectId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final downloadUrl = await service.uploadFile(
        documentId: id,
        bytes: file.bytes!,
        fileName: file.name,
        contentType: contentType,
      );

      await service.update(
        LibraryDocument(
          id: id,
          title: _titleController.text.trim(),
          category: _category,
          projectId: widget.projectId,
          storagePath: 'documents/$id/${file.name}',
          downloadUrl: downloadUrl,
          fileName: file.name,
          contentType: contentType,
          fileSizeBytes: file.size,
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

    return AlertDialog(
      title: Text(strings.uploadProjectDocumentTitle),
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
