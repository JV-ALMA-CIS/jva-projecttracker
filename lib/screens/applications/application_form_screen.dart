import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class ApplicationFormScreen extends ConsumerStatefulWidget {
  const ApplicationFormScreen({super.key, this.application});

  final CompanyApplication? application;

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _platformsController;
  late final TextEditingController _techStackController;
  late final TextEditingController _repoUrlController;
  late final TextEditingController _liveUrlController;
  late ApplicationStatus _status;
  List<String> _applicationAreas = [];
  bool _saving = false;
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    final a = widget.application;
    _nameController = TextEditingController(text: a?.name ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _platformsController = TextEditingController(
      text: a?.platforms.join(', ') ?? '',
    );
    _techStackController = TextEditingController(
      text: a?.techStack.join(', ') ?? '',
    );
    _repoUrlController = TextEditingController(text: a?.repoUrl ?? '');
    _liveUrlController = TextEditingController(text: a?.liveUrl ?? '');
    _status = a?.status ?? ApplicationStatus.active;
    _applicationAreas = List.of(a?.applicationAreas ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _platformsController.dispose();
    _techStackController.dispose();
    _repoUrlController.dispose();
    _liveUrlController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String v) =>
      v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(applicationServiceProvider);
    final now = DateTime.now();

    if (widget.application == null) {
      await service.create(
        CompanyApplication(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          platforms: _splitCsv(_platformsController.text),
          techStack: _splitCsv(_techStackController.text),
          repoUrl: _repoUrlController.text.trim().isEmpty
              ? null
              : _repoUrlController.text.trim(),
          liveUrl: _liveUrlController.text.trim().isEmpty
              ? null
              : _liveUrlController.text.trim(),
          applicationAreas: _applicationAreas,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final a = widget.application!;
      await service.update(
        CompanyApplication(
          id: a.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          platforms: _splitCsv(_platformsController.text),
          techStack: _splitCsv(_techStackController.text),
          repoUrl: _repoUrlController.text.trim().isEmpty
              ? null
              : _repoUrlController.text.trim(),
          liveUrl: _liveUrlController.text.trim().isEmpty
              ? null
              : _liveUrlController.text.trim(),
          applicationAreas: _applicationAreas,
          applicationAreasUpdatedAt: a.applicationAreasUpdatedAt,
          createdAt: a.createdAt,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.application == null) return;
    await ref.read(applicationServiceProvider).delete(widget.application!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Calls the `discoverApplicationAreas` callable Cloud Function, which runs
  /// a web search + Gemini summarization to suggest real-world use cases.
  Future<void> _discoverApplicationAreas() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _discovering = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'discoverApplicationAreas',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      });
      final areas = List<String>.from(
        result.data['areas'] as List? ?? const [],
      );
      setState(() => _applicationAreas = areas);
    } catch (e) {
      _log.e('discoverApplicationAreas failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Discovery failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.application != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Application' : 'New Application'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Application name'),
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
              controller: _platformsController,
              decoration: const InputDecoration(
                labelText: 'Platforms (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _techStackController,
              decoration: const InputDecoration(
                labelText: 'Tech stack (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repoUrlController,
              decoration: const InputDecoration(labelText: 'Repo URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _liveUrlController,
              decoration: const InputDecoration(labelText: 'Live URL'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ApplicationStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ApplicationStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Application areas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _discovering ? null : _discoverApplicationAreas,
                  icon: _discovering
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_outlined, size: 18),
                  label: const Text('Discover'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _applicationAreas
                  .map(
                    (area) => Chip(
                      label: Text(area),
                      onDeleted: () =>
                          setState(() => _applicationAreas.remove(area)),
                    ),
                  )
                  .toList(),
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
      ),
    );
  }
}
