import 'package:jva_projecttracker/models/project.dart';

/// One related project worth showing, with an explicit reason — same
/// "explain WHY" requirement as `RelatedWinningOpportunity` in the
/// Submission Workspace, and built the same way: plain overlap on
/// Company Intelligence relationship IDs already present on both records,
/// not a new AI pass.
class RelatedProject {
  final Project project;
  final String reasoning;
  final int overlapCount;

  const RelatedProject({
    required this.project,
    required this.reasoning,
    required this.overlapCount,
  });
}

/// Finds other completed/past projects that share a business unit,
/// industry, technology, or category with [project] — the "previous
/// projects, similar projects" the brief's Related Knowledge section asks
/// for. Capability/technology/experience chips are intentionally NOT
/// duplicated here: the Project Workspace reuses `RecommendedEntityChips`
/// directly against `project.capabilityIds`/`technologyIds`/etc., the same
/// way the Submission Workspace already does for the opportunity's
/// strategic-review IDs.
List<RelatedProject> computeRelatedProjects({
  required Project project,
  required List<Project> allProjects,
  int limit = 5,
}) {
  final businessUnits = project.businessUnitIds.toSet();
  final industries = project.industryIds.toSet();
  final technologies = project.technologyIds.toSet();

  final matches = <RelatedProject>[];

  for (final other in allProjects) {
    if (other.id == project.id) continue;

    final sharedBusinessUnits = businessUnits.intersection(
      other.businessUnitIds.toSet(),
    );
    final sharedIndustries = industries.intersection(other.industryIds.toSet());
    final sharedTechnologies = technologies.intersection(
      other.technologyIds.toSet(),
    );
    final sameCategory = other.category == project.category;

    var overlapCount =
        sharedBusinessUnits.length +
        sharedIndustries.length +
        sharedTechnologies.length;
    if (sameCategory) overlapCount += 1;
    if (overlapCount == 0) continue;

    final reasons = <String>[
      if (sameCategory) 'same category (${project.category.label})',
      if (sharedIndustries.isNotEmpty)
        '${sharedIndustries.length} shared industry(ies)',
      if (sharedBusinessUnits.isNotEmpty)
        '${sharedBusinessUnits.length} shared business unit(s)',
      if (sharedTechnologies.isNotEmpty)
        '${sharedTechnologies.length} shared technology(ies)',
    ];

    matches.add(
      RelatedProject(
        project: other,
        reasoning: 'Related via ${reasons.join(', ')}',
        overlapCount: overlapCount,
      ),
    );
  }

  matches.sort((a, b) => b.overlapCount.compareTo(a.overlapCount));
  return matches.take(limit).toList();
}
