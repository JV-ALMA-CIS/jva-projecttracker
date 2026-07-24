import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/widgets/section_header.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class ApplicationFormScreen extends ConsumerStatefulWidget {
  const ApplicationFormScreen({super.key, this.applicationId});

  final String? applicationId;

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _platformsController = TextEditingController();
  final _techStackController = TextEditingController();
  final _repoUrlController = TextEditingController();
  final _liveUrlController = TextEditingController();

  ApplicationStatus _status = ApplicationStatus.active;
  List<String> _applicationAreas = [];
  List<ApplicationAreaSuggestion> _suggestions = [];

  bool _saving = false;
  bool _discovering = false;
  bool _initialized = false;
  CompanyApplication? _loaded;

  bool get _isEditing => widget.applicationId != null;

  void _seedFrom(CompanyApplication? a) {
    if (_initialized || a == null) return;
    _initialized = true;
    _loaded = a;
    _nameController.text = a.name;
    _descriptionController.text = a.description;
    _platformsController.text = a.platforms.join(', ');
    _techStackController.text = a.techStack.join(', ');
    _repoUrlController.text = a.repoUrl ?? '';
    _liveUrlController.text = a.liveUrl ?? '';
    _status = a.status;
    _applicationAreas = List.of(a.applicationAreas);
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

    if (!_isEditing) {
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
    } else if (_loaded != null) {
      final a = _loaded!;
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
    if (widget.applicationId == null) return;
    await ref.read(applicationServiceProvider).delete(widget.applicationId!);
    if (mounted) Navigator.of(context).pop();
  }

  /// Calls the `discoverApplicationAreas` callable Cloud Function, which
  /// cross-references the company's project/application history and runs a
  /// web search + Gemini summarization to suggest real-world use cases with
  /// reasoning. Results land in a review list — they never overwrite areas
  /// the user has already typed or accepted.
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
      final areas = (result.data['areas'] as List? ?? const [])
          .map(
            (e) => ApplicationAreaSuggestion.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .where((s) => s.area.isNotEmpty)
          .toList();
      setState(() => _suggestions = areas);
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

  void _acceptSuggestion(ApplicationAreaSuggestion s) {
    setState(() {
      if (!_applicationAreas.contains(s.area)) {
        _applicationAreas = [..._applicationAreas, s.area];
      }
      _suggestions = _suggestions.where((e) => e.area != s.area).toList();
    });
  }

  void _rejectSuggestion(ApplicationAreaSuggestion s) {
    setState(() {
      _suggestions = _suggestions.where((e) => e.area != s.area).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final applicationAsync = _isEditing
        ? ref.watch(applicationByIdProvider(widget.applicationId!))
        : null;

    if (applicationAsync != null) {
      final loaded = applicationAsync.value;
      if (loaded != null) _seedFrom(loaded);
    }

    final isLoading = _isEditing && !_initialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Application' : 'New Application'),
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
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Market & usability discovery',
            trailing: TextButton.icon(
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
          ),
          Text(
            'Suggests real-world market/usability fields for this app, '
            'grounded in web search and the company\'s own project & '
            'application history.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._suggestions.map(
              (s) => Card(
                child: ListTile(
                  title: Text(s.area),
                  subtitle: s.reasoning.isEmpty ? null : Text(s.reasoning),
                  leading: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Accept',
                    onPressed: () => _acceptSuggestion(s),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                    onPressed: () => _rejectSuggestion(s),
                  ),
                ),
              ),
            ),
          ],
          if (_applicationAreas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Selected areas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
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
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Platform & technology'),
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
