import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Result of a confirmed stage-transition dialog. `note` is the optional
/// free text the user typed, forwarded as the created
/// [OpportunityEvent.description].
typedef StageTransitionResult = ({
  OpportunityPipelineStage stage,
  String? note,
});

/// Shows a dialog for picking a new [OpportunityPipelineStage] (defaulting
/// to [currentStage]) plus an optional note. Returns `null` if
/// cancelled/dismissed without confirming.
Future<StageTransitionResult?> showStageTransitionDialog(
  BuildContext context, {
  required OpportunityPipelineStage currentStage,
}) {
  return showDialog<StageTransitionResult>(
    context: context,
    builder: (context) => _StageTransitionDialog(currentStage: currentStage),
  );
}

class _StageTransitionDialog extends ConsumerStatefulWidget {
  const _StageTransitionDialog({required this.currentStage});

  final OpportunityPipelineStage currentStage;

  @override
  ConsumerState<_StageTransitionDialog> createState() =>
      _StageTransitionDialogState();
}

class _StageTransitionDialogState
    extends ConsumerState<_StageTransitionDialog> {
  final _noteController = TextEditingController();
  late OpportunityPipelineStage _selectedStage;

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.currentStage;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(strings.changeStageButton),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OpportunityPipelineStage>(
              initialValue: _selectedStage,
              decoration: InputDecoration(
                labelText: strings.selectNewStageLabel,
              ),
              items: OpportunityPipelineStage.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(strings.pipelineStageLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedStage = v ?? _selectedStage),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: strings.transitionNoteLabel,
              ),
              maxLines: 3,
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
          onPressed: () {
            final note = _noteController.text.trim();
            Navigator.of(context).pop<StageTransitionResult>((
              stage: _selectedStage,
              note: note.isEmpty ? null : note,
            ));
          },
          child: Text(strings.confirmButton),
        ),
      ],
    );
  }
}
