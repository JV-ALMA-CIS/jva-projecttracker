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

/// An opportunity's match score (`overallMatchScore`, falling back to
/// `fitScorePercent` when no AI Match Analysis pass has run yet) at or
/// above this is notification-worthy.
const int kMatchScoreNotifyThreshold = 70;

/// An opportunity in one of these statuses is considered closed for
/// notification purposes — excluded from every notification type
/// ([buildNotifications]) and from the durable match-notification mark
/// ([shouldMarkMatchNotificationSent]).
final Set<OpportunityStatus> closedOpportunityStatuses = {
  OpportunityStatus.won,
  OpportunityStatus.lost,
  OpportunityStatus.dismissed,
};

/// An opportunity's current match score ([Opportunity.overallMatchScore],
/// falling back to [Opportunity.fitScorePercent] — same precedence used
/// throughout this file), or null if it isn't notification-worthy at all
/// (closed, or below [kMatchScoreNotifyThreshold]).
int? matchNotifyScoreFor(Opportunity opportunity) {
  if (closedOpportunityStatuses.contains(opportunity.status)) return null;
  final score = opportunity.overallMatchScore ?? opportunity.fitScorePercent;
  if (score < kMatchScoreNotifyThreshold) return null;
  return score;
}

/// Buckets a score into its ten-point band (70 -> 70, 79 -> 70, 80 -> 80,
/// ...) — the unit both the ephemeral notification id ([buildNotifications])
/// and the durable [Opportunity.lastNotifiedScore] mark key off, so a small
/// fluctuation within the same band is deduped while a jump into a new band
/// is treated as a genuinely new, renotify-worthy event.
int matchScoreBucket(int score) => (score ~/ 10) * 10;

/// True when [opportunity]'s current match score is notification-worthy
/// ([matchNotifyScoreFor]) and its [Opportunity.lastNotifiedScore] hasn't
/// already recorded that same [matchScoreBucket] — i.e. this is a genuinely
/// new or meaningfully-increased match crossing [kMatchScoreNotifyThreshold],
/// not a repeat of one already durably recorded. Used by
/// `MatchNotificationWatcher` to decide whether to write
/// `OpportunityService.markMatchNotificationSent`.
bool shouldMarkMatchNotificationSent(Opportunity opportunity) {
  final score = matchNotifyScoreFor(opportunity);
  if (score == null) return false;

  final lastNotified = opportunity.lastNotifiedScore;
  if (lastNotified != null &&
      matchScoreBucket(lastNotified) == matchScoreBucket(score)) {
    return false;
  }
  return true;
}

/// Builds the Notification Center's contents purely from already-live data
/// — no Firestore collection of its own (see ADR-007). Every active
/// [Recommendation] becomes one notification (reusing its own priority/
/// title/reasoning directly); every still-open [Opportunity] with a
/// deadline inside [kDeadlineWindowDays] becomes another; every still-open
/// [Opportunity] whose match score is at or above [kMatchScoreNotifyThreshold]
/// becomes a third. [readIds] marks which are already read (see
/// `NotificationPreferencesService`).
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
    if (closedOpportunityStatuses.contains(opportunity.status)) continue;

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

  final matchScoreItems = <NotificationItem>[];
  for (final opportunity in opportunities) {
    final score = matchNotifyScoreFor(opportunity);
    if (score == null) continue;

    // Bucketed by decade (70-79, 80-89, ...) rather than the raw opportunity
    // id alone: once a user marks a match-score notification read, the same
    // id would otherwise stay "read" forever even if the score later climbs
    // meaningfully (e.g. a re-run of Match Analysis moves 72 -> 88). Keying
    // the id on the bucket means a jump into a new decade band produces a
    // fresh, unread id, while small fluctuations within the same band stay
    // deduped against the already-read entry — no extra Firestore field
    // needed, since `NotificationReadController` already tracks read ids by
    // string key.
    final bucket = matchScoreBucket(score);
    final id = 'matchScore:${opportunity.id}:$bucket';
    matchScoreItems.add(
      NotificationItem(
        id: id,
        type: NotificationType.matchScore,
        priority: OpportunityPriority.high,
        title: opportunity.title,
        matchScorePercent: score,
        timestamp: opportunity.matchAnalyzedAt ?? opportunity.updatedAt,
        relatedOpportunityIds: [opportunity.id],
        isRead: readIds.contains(id),
      ),
    );
  }
  matchScoreItems.sort(
    (a, b) => b.matchScorePercent!.compareTo(a.matchScorePercent!),
  );

  return [...recommendationItems, ...deadlineItems, ...matchScoreItems];
}
