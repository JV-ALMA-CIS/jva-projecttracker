import 'package:jva_projecttracker/models/opportunity.dart';

/// What generated a [NotificationItem] — drives its icon and which group it
/// renders under in `NotificationCenterScreen`.
enum NotificationType { recommendation, deadline }

/// A single entry in the Notification Center, derived (never persisted) by
/// `buildNotifications` from live AI Recommendations (Milestone 3.6) and
/// opportunity deadlines. See ADR-007.
///
/// [id] is a synthetic, stable key (`"recommendation:<id>"` /
/// `"deadline:<id>"`) — used both as a Flutter `Key` and as the value stored
/// in `NotificationPreferencesService`'s local read-state.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    this.body,
    this.daysUntilDeadline,
    required this.timestamp,
    this.relatedOpportunityIds = const [],
    this.recommendationId,
    required this.isRead,
  });

  final String id;
  final NotificationType type;

  /// Reuses [OpportunityPriority] rather than a duplicate enum — same
  /// "avoid duplicating logic" call already made for `Recommendation` in
  /// ADR-006.
  final OpportunityPriority priority;
  final String title;

  /// Set only for [NotificationType.recommendation] — the recommendation's
  /// own AI-generated reasoning, which is business data, not UI chrome, so
  /// it's stored as-is (same convention as every other AI feature's
  /// reasoning/summary text).
  final String? body;

  /// Set only for [NotificationType.deadline]. Deliberately a plain `int`,
  /// not a pre-rendered string: unlike [body], "N days left" IS interface
  /// chrome, so it must be localized via `AppStrings` at render time (see
  /// `NotificationTile`), not baked into this model by the (locale-unaware)
  /// pure `buildNotifications` function.
  final int? daysUntilDeadline;
  final DateTime timestamp;
  final List<String> relatedOpportunityIds;

  /// Set only for [NotificationType.recommendation] — lets the center deep-
  /// link back to the specific recommendation if a future screen needs it.
  final String? recommendationId;
  final bool isRead;
}
