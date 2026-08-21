import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

/// The single canonical stage-to-color mapping for
/// [OpportunityPipelineStage] — used by both the opportunities list tile
/// and [OpportunityPipelineScreen] so the two visual treatments never
/// drift apart. Mirrors [fitScoreColor]'s role as the one color function
/// for its concept. Reads [AppStatusColors] rather than raw `Colors.*` so
/// this stays in sync with the rest of the app's status-color system.
Color pipelineStageColor(OpportunityPipelineStage stage) => switch (stage) {
  OpportunityPipelineStage.lost => AppStatusColors.danger,
  OpportunityPipelineStage.awarded ||
  OpportunityPipelineStage.projectStarted ||
  OpportunityPipelineStage.completed => AppStatusColors.success,
  OpportunityPipelineStage.submitted ||
  OpportunityPipelineStage.evaluation ||
  OpportunityPipelineStage.negotiation => AppStatusColors.warning,
  _ => AppStatusColors.neutral,
};

/// A [StatusBadge] preconfigured for an opportunity's pipeline stage —
/// for the standalone "current stage" indicator. The list tile instead
/// renders a plain [Chip] (to match its sibling priority/risk chips) using
/// [pipelineStageColor] directly.
class PipelineStageBadge extends ConsumerWidget {
  const PipelineStageBadge({super.key, required this.stage});

  final OpportunityPipelineStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return StatusBadge(
      label: strings.pipelineStageLabel(stage),
      color: pipelineStageColor(stage),
    );
  }
}
