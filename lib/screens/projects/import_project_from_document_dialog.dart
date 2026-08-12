import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/screens/projects/project_extraction_review_screen.dart';
import 'package:jva_projecttracker/screens/projects/project_workspace_screen.dart';
import 'package:jva_projecttracker/services/project_extraction_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

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

String _titleFromFileName(String fileName) {
  final base = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  return base.trim().isEmpty ? fileName : base.trim();
}

/// Upload-first project creation: pick document → create minimal Project →
/// upload → AI extract → open Review screen.
Future<void> showImportProjectFromDocumentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ImportProjectFromDocumentDialog(),
  );
}

class _ImportProjectFromDocumentDialog extends ConsumerStatefulWidget {
  const _ImportProjectFromDocumentDialog();

  @override
  ConsumerState<_ImportProjectFromDocumentDialog> createState() =>
      _ImportProjectFromDocumentDialogState();
}

class _ImportProjectFromDocumentDialogState
    extends ConsumerState<_ImportProjectFromDocumentDialog> {
  final _titleController = TextEditingController();
  PlatformFile? _chosenFile;
  bool _busy = false;
  String? _statusMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _chosenFile = file;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _titleFromFileName(file.name);
      }
    });
  }

  bool get _canImport =>
      _titleController.text.trim().isNotEmpty &&
      _chosenFile != null &&
      _chosenFile!.bytes != null &&
      !_busy;

  Future<void> _import() async {
    final file = _chosenFile;
    if (!_canImport || file == null || file.bytes == null) return;

    final strings = ref.read(appStringsProvider);
    setState(() {
      _busy = true;
      _statusMessage = strings.importProjectCreatingLabel;
    });

    final projectService = ref.read(projectServiceProvider);
    final documentService = ref.read(libraryDocumentServiceProvider);
    final extractionService = ref.read(projectExtractionServiceProvider);
    final now = DateTime.now();
    final contentType = _guessMimeType(file.name);
    final title = _titleController.text.trim();

    try {
      final projectId = await projectService.create(
        Project(
          id: '',
          name: title,
          description: '',
          client: '',
          status: ProjectStatus.planned,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      setState(() => _statusMessage = strings.importProjectUploadingLabel);

      final documentId = await documentService.create(
        LibraryDocument(
          id: '',
          title: title,
          category: DocumentCategory.previousProjectEvidence,
          projectId: projectId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final downloadUrl = await documentService.uploadFile(
        documentId: documentId,
        bytes: file.bytes!,
        fileName: file.name,
        contentType: contentType,
      );

      await documentService.update(
        LibraryDocument(
          id: documentId,
          title: title,
          category: DocumentCategory.previousProjectEvidence,
          projectId: projectId,
          storagePath: 'documents/$documentId/${file.name}',
          downloadUrl: downloadUrl,
          fileName: file.name,
          contentType: contentType,
          fileSizeBytes: file.size,
          createdAt: now,
          updatedAt: now,
        ),
      );

      setState(() => _statusMessage = strings.importProjectExtractingLabel);
      try {
        await extractionService.extract(documentId: documentId);
      } on ProjectExtractionException {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.extractionFailedMessage)),
        );
        // Deliberately NOT the Review screen here — it reads live
        // `aiExtracted*` fields off the document, and since extraction
        // just failed those were never written, so Review would render
        // completely empty (this was the actual bug: the previous version
        // of this catch block navigated to Review anyway on failure).
        // The Project Workspace is where a real retry lives — its document
        // tile shows "Extract knowledge" again for a document whose
        // `aiExtractionStatus` is still `none`.
        pushSlideFade(context, ProjectWorkspaceScreen(projectId: projectId));
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      pushSlideFade(
        context,
        ProjectExtractionReviewScreen(
          documentId: documentId,
          projectId: projectId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(strings.importProjectFromDocumentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.importProjectFromDocumentCaption,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: strings.fieldProjectName),
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
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
            if (_statusMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_statusMessage!)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _canImport ? _import : null,
          child: Text(strings.importProjectButton),
        ),
      ],
    );
  }
}
