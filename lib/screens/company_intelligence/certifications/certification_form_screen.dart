import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_form_row.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';

/// Create/edit a company [Certification] — an eligibility credential the
/// company itself holds (NCA grade, tax compliance, AGPO, ISO, business
/// permit, professional license), never a project delivery field. Same
/// create-vs-edit shape and delete-confirm pattern as
/// `ProductFormScreen`/`project_form_screen.dart`.
class CertificationFormScreen extends ConsumerStatefulWidget {
  const CertificationFormScreen({super.key, this.certificationId});

  final String? certificationId;

  @override
  ConsumerState<CertificationFormScreen> createState() =>
      _CertificationFormScreenState();
}

class _CertificationFormScreenState
    extends ConsumerState<CertificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _issuingBodyController = TextEditingController();
  final _certificateNumberController = TextEditingController();
  final _notesController = TextEditingController();

  CertificationType _type = CertificationType.nca;
  CertificationStatus _status = CertificationStatus.active;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  String? _documentId;

  bool _saving = false;
  bool _initialized = false;
  Certification? _loaded;

  bool get _isEditing => widget.certificationId != null;

  void _seedFrom(Certification? c) {
    if (_initialized || c == null) return;
    _initialized = true;
    _loaded = c;
    _nameController.text = c.name;
    _gradeController.text = c.gradeOrClass ?? '';
    _issuingBodyController.text = c.issuingBody ?? '';
    _certificateNumberController.text = c.certificateNumber ?? '';
    _notesController.text = c.notes;
    _type = c.type;
    _status = c.status;
    _issueDate = c.issueDate;
    _expiryDate = c.expiryDate;
    _documentId = c.documentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _issuingBodyController.dispose();
    _certificateNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isExpiry ? _expiryDate : _issueDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiryDate = picked;
      } else {
        _issueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(certificationServiceProvider);
    final now = DateTime.now();
    final grade = _gradeController.text.trim();
    final issuingBody = _issuingBodyController.text.trim();
    final certificateNumber = _certificateNumberController.text.trim();

    if (!_isEditing) {
      await service.create(
        Certification(
          id: '',
          name: _nameController.text.trim(),
          type: _type,
          gradeOrClass: grade.isEmpty ? null : grade,
          issuingBody: issuingBody.isEmpty ? null : issuingBody,
          certificateNumber: certificateNumber.isEmpty
              ? null
              : certificateNumber,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          status: _status,
          documentId: _documentId,
          notes: _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (_loaded != null) {
      await service.update(
        _loaded!.copyWith(
          name: _nameController.text.trim(),
          type: _type,
          gradeOrClass: grade.isEmpty ? null : grade,
          issuingBody: issuingBody.isEmpty ? null : issuingBody,
          certificateNumber: certificateNumber.isEmpty
              ? null
              : certificateNumber,
          issueDate: _issueDate,
          clearIssueDate: _issueDate == null,
          expiryDate: _expiryDate,
          clearExpiryDate: _expiryDate == null,
          status: _status,
          documentId: _documentId,
          clearDocumentId: _documentId == null,
          notes: _notesController.text.trim(),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.certificationId == null) return;
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteTooltip),
        content: Text(strings.deleteCertificationConfirmBody),
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

    await ref
        .read(certificationServiceProvider)
        .delete(widget.certificationId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final certAsync = _isEditing
        ? ref.watch(certificationByIdProvider(widget.certificationId!))
        : null;

    if (certAsync != null) {
      final loaded = certAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? strings.editCertificationTitle
              : strings.newCertificationTitle,
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
    final documentsAsync = ref.watch(libraryDocumentsStreamProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SectionHeader(
            title: strings.sectionDetails,
            accentColor: AppStatusColors.neutral,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: strings.fieldCertificationName,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? strings.requiredValidator
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              DropdownButtonFormField<CertificationType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: strings.fieldCertificationType,
                ),
                items: CertificationType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(strings.certificationTypeLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              TextFormField(
                controller: _gradeController,
                decoration: InputDecoration(
                  labelText: strings.fieldCertificationGrade,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              TextFormField(
                controller: _issuingBodyController,
                decoration: InputDecoration(
                  labelText: strings.fieldCertificationIssuingBody,
                ),
              ),
              TextFormField(
                controller: _certificateNumberController,
                decoration: InputDecoration(
                  labelText: strings.fieldCertificationNumber,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdaptiveFieldRow(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.fieldCertificationIssueDate),
                subtitle: Text(
                  _issueDate == null
                      ? strings.notSetLabel
                      : dateFormat.format(_issueDate!),
                ),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () => _pickDate(isExpiry: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.fieldCertificationExpiryDate),
                subtitle: Text(
                  _expiryDate == null
                      ? strings.notSetLabel
                      : dateFormat.format(_expiryDate!),
                ),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () => _pickDate(isExpiry: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<CertificationStatus>(
            initialValue: _status,
            decoration: InputDecoration(labelText: strings.fieldStatus),
            items: CertificationStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: AppSpacing.md),
          documentsAsync.when(
            data: (documents) {
              // A previously-linked document id that no longer resolves
              // (deleted elsewhere) must not be passed as `initialValue` —
              // Dropdown throws if the value isn't among `items`. Falling
              // back to null here just means the dropdown shows
              // "No document selected" rather than crashing; the stale id
              // itself is only actually cleared if the user saves again.
              final resolvedValue = documents.any((d) => d.id == _documentId)
                  ? _documentId
                  : null;
              return DropdownButtonFormField<String?>(
                initialValue: resolvedValue,
                decoration: InputDecoration(
                  labelText: strings.fieldCertificationDocument,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.noDocumentSelectedLabel),
                  ),
                  for (final d in documents)
                    DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(d.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _documentId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(strings.errorPrefix(e)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(labelText: strings.fieldNotes),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
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
