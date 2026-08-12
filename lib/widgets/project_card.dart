import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ProjectStatus status) => switch (status) {
  ProjectStatus.planned => Colors.blue,
  ProjectStatus.running => Colors.green,
  ProjectStatus.past => Colors.grey,
};

class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final subtitleParts = [
      project.client,
      project.location,
    ].where((p) => p.isNotEmpty);

    final amount = project.contractValueAmount;

    return EntityCard(
      title: project.name,
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      statusBadge: StatusBadge(
        label: strings.projectStatusLabel(project.status),
        color: _statusColor(project.status),
      ),
      metaChips: [
        Chip(label: Text(strings.projectCategoryLabel(project.category))),
        Chip(label: Text(strings.contractorRoleLabel(project.contractorRole))),
        if (amount != null)
          Chip(
            label: Text(
              NumberFormat.simpleCurrency(
                name: project.contractValueCurrency,
                decimalDigits: 0,
              ).format(amount),
            ),
          ),
        if (project.fundingAgency.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.account_balance_outlined, size: 16),
            label: Text(project.fundingAgency),
          ),
        if (project.sourceOpportunityId != null)
          Chip(
            avatar: const Icon(Icons.travel_explore_outlined, size: 16),
            label: Text(strings.sourceOpportunityChipLabel),
            visualDensity: VisualDensity.compact,
          ),
        if (project.experienceId != null)
          Chip(
            avatar: const Icon(Icons.auto_awesome, size: 16),
            label: Text(strings.linkedExperienceChipLabel),
            visualDensity: VisualDensity.compact,
          ),
      ],
      onTap: onTap,
    );
  }
}
