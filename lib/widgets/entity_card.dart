import 'package:flutter/material.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// Generic list/grid item card used by Projects and Applications: a title,
/// optional subtitle, a status badge pinned to the top-right, and a row of
/// meta chips beneath. Kept generic so per-entity cards (e.g. `ProjectCard`)
/// only need to decide what goes in each slot.
class EntityCard extends StatelessWidget {
  const EntityCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.statusBadge,
    this.metaChips = const [],
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget statusBadge;
  final List<Widget> metaChips;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  statusBadge,
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (metaChips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: metaChips,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
