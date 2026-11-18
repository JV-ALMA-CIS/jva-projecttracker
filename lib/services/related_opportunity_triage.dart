import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/opportunities/inbox_view.dart';

/// How an AI recommendation's related opportunity should be presented:
/// highlighted as worth acting on, shown normally, or greyed out as
/// background for why the AI made the recommendation.
enum RelatedOpportunityState { worthALook, open, reference }

/// Match score at or above which an open related opportunity is "worth a
/// look" — the same line as the instant push alert.
const kWorthALookScore = 70;

const _closedStatuses = {
  OpportunityStatus.dismissed,
  OpportunityStatus.archived,
  OpportunityStatus.lost,
  OpportunityStatus.won,
};

/// - reference: closed (dismissed / archived / lost / won) or its deadline
///   has passed without an application;
/// - worthALook: still open and either a strong match (>= 70%) or the
///   recommendation itself says to fast-track it ("priority opportunity");
/// - open: everything else that can still be pursued.
RelatedOpportunityState relatedOpportunityState(
  Opportunity opportunity,
  Recommendation recommendation,
  DateTime now,
) {
  if (_closedStatuses.contains(opportunity.status)) {
    return RelatedOpportunityState.reference;
  }
  if (opportunity.status == OpportunityStatus.applied) {
    return RelatedOpportunityState.open;
  }
  final deadline = opportunity.deadline;
  if (deadline != null && !deadline.isAfter(now)) {
    return RelatedOpportunityState.reference;
  }
  if (inboxScore(opportunity) >= kWorthALookScore ||
      recommendation.category == RecommendationCategory.priorityOpportunity) {
    return RelatedOpportunityState.worthALook;
  }
  return RelatedOpportunityState.open;
}

/// A related opportunity paired with how to present it.
class TriagedOpportunity {
  const TriagedOpportunity(this.opportunity, this.state);

  final Opportunity opportunity;
  final RelatedOpportunityState state;
}

/// The recommendation's related opportunities that still exist, worth-a-look
/// first, then open, then reference; within each group best match first.
List<TriagedOpportunity> triageRelatedOpportunities(
  Recommendation recommendation,
  Map<String, Opportunity> opportunitiesById,
  DateTime now,
) {
  final triaged = [
    for (final id in recommendation.relatedOpportunityIds)
      if (opportunitiesById[id] case final o?)
        TriagedOpportunity(o, relatedOpportunityState(o, recommendation, now)),
  ];
  triaged.sort((a, b) {
    final byState = a.state.index.compareTo(b.state.index);
    if (byState != 0) return byState;
    return compareForInbox(a.opportunity, b.opportunity);
  });
  return triaged;
}

/// A recommendation is outdated when it is about specific opportunities and
/// every one of them is closed, past its deadline, or no longer exists —
/// there is nothing left to act on.
bool isOutdatedRecommendation(
  Recommendation recommendation,
  Map<String, Opportunity> opportunitiesById,
  DateTime now,
) {
  final ids = recommendation.relatedOpportunityIds;
  if (ids.isEmpty) return false;
  for (final id in ids) {
    final o = opportunitiesById[id];
    if (o == null) continue;
    if (relatedOpportunityState(o, recommendation, now) !=
        RelatedOpportunityState.reference) {
      return false;
    }
  }
  return true;
}
