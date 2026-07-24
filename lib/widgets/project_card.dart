import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

Color _statusColor(ProjectStatus status) => switch (status) {
  ProjectStatus.planned => Colors.blue,
  ProjectStatus.running => Colors.green,
  ProjectStatus.past => Colors.grey,
};

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      project.client,
      project.location,
    ].where((p) => p.isNotEmpty);

    final amount = project.contractValueAmount;

    return EntityCard(
      title: project.name,
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      statusBadge: StatusBadge(
        label: project.status.label,
        color: _statusColor(project.status),
      ),
      metaChips: [
        Chip(label: Text(project.category.label)),
        Chip(label: Text(project.contractorRole.label)),
        if (amount != null)
          Chip(
            label: Text(
              NumberFormat.simpleCurrency(
                name: project.contractValueCurrency,
                decimalDigits: 0,
              ).format(amount),
            ),
          ),
      ],
      onTap: onTap,
    );
  }
}
