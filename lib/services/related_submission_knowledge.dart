import 'package:jva_projecttracker/models/opportunity.dart';

/// One previously **won** opportunity worth showing alongside the current
/// submission, with an explicit reason it was surfaced — per this
/// project's AI Design Philosophy ("every recommendation should explain
/// WHY"), even though this particular derivation is plain overlap logic,
/// not a Gemini call.
class RelatedWinningOpportunity {
  final Opportunity opportunity;
  final String reasoning;
  final int overlapCount;

  const RelatedWinningOpportunity({
    required this.opportunity,
    required this.reasoning,
    required this.overlapCount,
  });
}

/// Finds previously won opportunities that share at least one business
/// unit, industry, or technology with [opportunity] — reusing the
/// Company Intelligence relationship IDs already on both records rather
/// than any new classification pass. Capability/technology/experience
/// "related knowledge" chips are intentionally NOT duplicated here: the
/// Submission Workspace reuses `RecommendedEntityChips` directly against
/// `opportunity.strategicReview*Ids`, exactly as the Strategic Review
/// screen already does, since that data and rendering already exist.
List<RelatedWinningOpportunity> computeRelatedWinningOpportunities({
  required Opportunity opportunity,
  required List<Opportunity> allOpportunities,
  int limit = 5,
}) {
  final businessUnits = opportunity.businessUnitIds.toSet();
  final industries = opportunity.industryIds.toSet();
  final technologies = opportunity.technologyIds.toSet();

  final matches = <RelatedWinningOpportunity>[];

  for (final other in allOpportunities) {
    if (other.id == opportunity.id) continue;
    if (other.status != OpportunityStatus.won) continue;

    final sharedBusinessUnits = businessUnits.intersection(
      other.businessUnitIds.toSet(),
    );
    final sharedIndustries = industries.intersection(other.industryIds.toSet());
    final sharedTechnologies = technologies.intersection(
      other.technologyIds.toSet(),
    );

    final overlapCount =
        sharedBusinessUnits.length +
        sharedIndustries.length +
        sharedTechnologies.length;
    if (overlapCount == 0) continue;

    final reasons = <String>[
      if (sharedIndustries.isNotEmpty)
        '${sharedIndustries.length} shared industry(ies)',
      if (sharedBusinessUnits.isNotEmpty)
        '${sharedBusinessUnits.length} shared business unit(s)',
      if (sharedTechnologies.isNotEmpty)
        '${sharedTechnologies.length} shared technology(ies)',
    ];

    matches.add(
      RelatedWinningOpportunity(
        opportunity: other,
        reasoning: 'Won opportunity with ${reasons.join(', ')}',
        overlapCount: overlapCount,
      ),
    );
  }

  matches.sort((a, b) => b.overlapCount.compareTo(a.overlapCount));
  return matches.take(limit).toList();
}
