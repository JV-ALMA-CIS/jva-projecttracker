import 'package:flutter/material.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/proposal_section_style.dart';

/// A horizontal stepper visualizing a proposal's real sections and their
/// real statuses — deliberately *not* a fixed 7-phase tracker, since this
/// app's actual `ProposalSectionType`s don't map onto a generic phase list.
/// Each step reuses `proposalSectionStatusStyle`, the same status colors
/// `ProposalSectionCard` already uses, so the tracker and the section list
/// below it always agree.
class ProposalProgressTracker extends StatelessWidget {
  const ProposalProgressTracker({super.key, required this.sections});

  final List<ProposalSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final section = sections[index];
          final (background, foreground, icon) = proposalSectionStatusStyle(
            theme.colorScheme,
            section.status,
          );
          return SizedBox(
            width: 84,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: background,
                  child: Icon(icon, color: foreground, size: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  section.title,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
