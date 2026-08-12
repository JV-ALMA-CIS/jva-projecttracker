import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/submission_communication.dart';
import 'package:jva_projecttracker/services/providers.dart';

/// Shows the "log a communication" dialog for one submission. Mirrors the
/// existing `_showSourceFormDialog`/`_ManualOpportunityDialog` shape
/// (simple `AlertDialog` + `showDialog`) already used by
/// `discovery_sources_screen.dart`.
Future<void> showAddCommunicationDialog(
  BuildContext context,
  String submissionId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddCommunicationDialog(submissionId: submissionId),
  );
}

class _AddCommunicationDialog extends ConsumerStatefulWidget {
  const _AddCommunicationDialog({required this.submissionId});

  final String submissionId;

  @override
  ConsumerState<_AddCommunicationDialog> createState() =>
      _AddCommunicationDialogState();
}

class _AddCommunicationDialogState
    extends ConsumerState<_AddCommunicationDialog> {
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();
  CommunicationType _type = CommunicationType.meeting;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    await ref
        .read(submissionCommunicationServiceProvider)
        .create(
          SubmissionCommunication(
            id: '',
            submissionId: widget.submissionId,
            type: _type,
            subject: subject,
            notes: _notesController.text.trim(),
            date: _date,
            createdAt: now,
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dateFormat = DateFormat.yMMMd(strings.locale.toString());

    return AlertDialog(
      title: Text(strings.logCommunicationTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<CommunicationType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: strings.fieldCommunicationType,
              ),
              items: CommunicationType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(strings.communicationTypeLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              autofocus: true,
              decoration: InputDecoration(labelText: strings.fieldSubject),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: strings.fieldNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: strings.fieldDate),
                child: Text(dateFormat.format(_date)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.addButton),
        ),
      ],
    );
  }
}
