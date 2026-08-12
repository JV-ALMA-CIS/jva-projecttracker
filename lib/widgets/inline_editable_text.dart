import 'package:flutter/material.dart';

/// A tap-to-edit text value with no separate dialog — the same UX already
/// used (as two separate private classes, `_ProposalTitleField` and
/// `_ProposalOwnerField`) in `ProposalWorkspaceScreen`. This is the
/// generic, reusable version; the Submission Workspace uses it for the
/// submission owner field. Consolidating the two pre-existing copies onto
/// this widget is a worthwhile follow-up, left out of this milestone's
/// diff for the same reason noted on [BulletList].
class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    this.style,
  });

  /// Current value, or `null`/empty to show [placeholder].
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;
  final TextStyle? style;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _controller.text.trim();
    widget.onChanged(value.isEmpty ? null : value);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: _controller,
        autofocus: true,
        style: widget.style,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
      );
    }
    final hasValue = widget.value?.isNotEmpty == true;
    return InkWell(
      onTap: () => setState(() => _editing = true),
      child: Text(
        hasValue ? widget.value! : widget.placeholder,
        style: widget.style,
      ),
    );
  }
}
