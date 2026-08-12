import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';

/// Opportunities whose deadline falls within this many days (inclusive of
/// already-overdue) are notification-worthy at all — anything further out
/// isn't urgent enough to surface yet.
const int kDeadlineWindowDays = 7;

/// Within [kDeadlineWindowDays], a deadline this close (or overdue) is
/// `high` priority; everything else in the window is `medium` — there is no
/// `low`-priority deadline notification, since the window itself already
/// pre-filters out anything that isn't at least moderately urgent.
const int kDeadlineHighPriorityDays = 2;

final Set<OpportunityStatus> _closedStatuses = {
  OpportunityStatus.won,
  OpportunityStatus.lost,
  OpportunityStatus.dismissed,
};

/// Builds the Notification Center's contents purely from already-live data
/// — no Firestore collection of its own (see ADR-007). Every active
/// [Recommendation] becomes one notification (reusing its own priority/
/// title/reasoning directly); every still-open [Opportunity] with a
/// deadline inside [kDeadlineWindowDays] becomes another. [readIds] marks
/// which are already read (see `NotificationPreferencesService`).
///
/// [activeRecommendations] is expected already priority-sorted (as
/// `activeRecommendationsProvider` provides) — that order is preserved
/// here. Deadline notifications are sorted soonest-first.
List<NotificationItem> buildNotifications({
  required List<Recommendation> activeRecommendations,
  required List<Opportunity> opportunities,
  required Set<String> readIds,
  required DateTime now,
}) {
  final recommendationItems = [
    for (final recommendation in activeRecommendations)
      NotificationItem(
        id: 'recommendation:${recommendation.id}',
        type: NotificationType.recommendation,
        priority: recommendation.priority,
        title: recommendation.title,
        body: recommendation.reasoning,
        timestamp: recommendation.generatedAt,
        relatedOpportunityIds: recommendation.relatedOpportunityIds,
        recommendationId: recommendation.id,
        isRead: readIds.contains('recommendation:${recommendation.id}'),
      ),
  ];

  final deadlineItems = <NotificationItem>[];
  for (final opportunity in opportunities) {
    final deadline = opportunity.deadline;
    if (deadline == null) continue;
    if (_closedStatuses.contains(opportunity.status)) continue;

    final daysLeft = deadline.difference(now).inDays;
    if (daysLeft > kDeadlineWindowDays) continue;

    final id = 'deadline:${opportunity.id}';
    deadlineItems.add(
      NotificationItem(
        id: id,
        type: NotificationType.deadline,
        priority: daysLeft <= kDeadlineHighPriorityDays
            ? OpportunityPriority.high
            : OpportunityPriority.medium,
        title: opportunity.title,
        daysUntilDeadline: daysLeft,
        timestamp: deadline,
        relatedOpportunityIds: [opportunity.id],
        isRead: readIds.contains(id),
      ),
    );
  }
  deadlineItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return [...recommendationItems, ...deadlineItems];
}
