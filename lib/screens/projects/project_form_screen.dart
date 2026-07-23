import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.project});

  final Project? project;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _clientController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _techStackController;
  late ProjectStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? '');
    _clientController = TextEditingController(text: p?.client ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _techStackController = TextEditingController(
      text: p?.techStack.join(', ') ?? '',
    );
    _status = p?.status ?? ProjectStatus.planned;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final service = ref.read(projectServiceProvider);
    final techStack = _techStackController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (widget.project == null) {
      final now = DateTime.now();
      await service.create(
        Project(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          client: _clientController.text.trim(),
          status: _status,
          techStack: techStack,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await service.update(
        widget.project!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          client: _clientController.text.trim(),
          status: _status,
          techStack: techStack,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.project == null) return;
    await ref.read(projectServiceProvider).delete(widget.project!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Project' : 'New Project'),
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
              decoration: const InputDecoration(labelText: 'Project name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientController,
              decoration: const InputDecoration(labelText: 'Client'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _techStackController,
              decoration: const InputDecoration(
                labelText: 'Tech stack (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ProjectStatus.values
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
      ),
    );
  }
}
