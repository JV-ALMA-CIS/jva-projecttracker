import 'package:flutter/material.dart';

/// A circular "X% complete" indicator — the Proposal Workspace's headline
/// visual (in place of a plain progress bar or a bare fraction), so
/// proposal completeness reads at a glance the way a modern workspace tool
/// (Notion/Linear-style) would present it. Reusable anywhere else a
/// proposal's progress needs surfacing (e.g. a future Dashboard card).
class ProposalProgressRing extends StatelessWidget {
  const ProposalProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
  });

  /// 0.0-1.0.
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
