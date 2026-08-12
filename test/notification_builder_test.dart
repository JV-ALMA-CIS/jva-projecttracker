import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';

void main() {
  final now = DateTime.utc(2024, 8, 10);

  Recommendation buildRecommendation({
    required String id,
    OpportunityPriority priority = OpportunityPriority.medium,
  }) {
    return Recommendation(
      id: id,
      priority: priority,
      title: 'Fast-track the Rural Water Tender',
      reasoning: 'Strong strategic fit and an approaching deadline.',
      relatedOpportunityIds: const ['opportunity-1'],
      generatedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Opportunity buildOpportunity({
    required String id,
    DateTime? deadline,
    OpportunityStatus status = OpportunityStatus.reviewing,
  }) {
    return Opportunity(
      id: id,
      title: 'Opportunity $id',
      description: '',
      sourceUrl: 'https://example.com/$id',
      deadline: deadline,
      status: status,
      discoveredAt: now,
      updatedAt: now,
    );
  }

  test(
    'produces one notification per active recommendation, fields carried through',
    () {
      final notifications = buildNotifications(
        activeRecommendations: [buildRecommendation(id: 'rec-1')],
        opportunities: const [],
        readIds: {},
        now: now,
      );

      expect(notifications, hasLength(1));
      final n = notifications.single;
      expect(n.id, 'recommendation:rec-1');
      expect(n.type, NotificationType.recommendation);
      expect(n.priority, OpportunityPriority.medium);
      expect(n.title, 'Fast-track the Rural Water Tender');
      expect(n.body, 'Strong strategic fit and an approaching deadline.');
      expect(n.timestamp, now);
      expect(n.relatedOpportunityIds, ['opportunity-1']);
      expect(n.recommendationId, 'rec-1');
      expect(n.isRead, isFalse);
    },
  );

  test('isRead reflects readIds', () {
    final notifications = buildNotifications(
      activeRecommendations: [buildRecommendation(id: 'rec-1')],
      opportunities: const [],
      readIds: {'recommendation:rec-1'},
      now: now,
    );

    expect(notifications.single.isRead, isTrue);
  });

  test('preserves the input order of active recommendations', () {
    final notifications = buildNotifications(
      activeRecommendations: [
        buildRecommendation(id: 'rec-high', priority: OpportunityPriority.high),
        buildRecommendation(id: 'rec-low', priority: OpportunityPriority.low),
      ],
      opportunities: const [],
      readIds: {},
      now: now,
    );

    expect(notifications.map((n) => n.id), [
      'recommendation:rec-high',
      'recommendation:rec-low',
    ]);
  });

  test(
    'includes an opportunity deadline exactly at the 7-day window boundary',
    () {
      final notifications = buildNotifications(
        activeRecommendations: const [],
        opportunities: [
          buildOpportunity(
            id: 'opp-1',
            deadline: now.add(const Duration(days: 7)),
          ),
        ],
        readIds: {},
        now: now,
      );

      expect(notifications, hasLength(1));
      expect(notifications.single.type, NotificationType.deadline);
    },
  );

  test('excludes an opportunity deadline just outside the 7-day window', () {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: [
        buildOpportunity(
          id: 'opp-1',
          deadline: now.add(const Duration(days: 8)),
        ),
      ],
      readIds: {},
      now: now,
    );

    expect(notifications, isEmpty);
  });

  test('includes an overdue deadline with a negative daysUntilDeadline', () {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: [
        buildOpportunity(
          id: 'opp-1',
          deadline: now.subtract(const Duration(days: 3)),
        ),
      ],
      readIds: {},
      now: now,
    );

    expect(notifications.single.daysUntilDeadline, -3);
    expect(notifications.single.priority, OpportunityPriority.high);
  });

  test('excludes opportunities with no deadline set', () {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: [buildOpportunity(id: 'opp-1')],
      readIds: {},
      now: now,
    );

    expect(notifications, isEmpty);
  });

  for (final status in [
    OpportunityStatus.won,
    OpportunityStatus.lost,
    OpportunityStatus.dismissed,
  ]) {
    test('excludes a $status opportunity even with a near deadline', () {
      final notifications = buildNotifications(
        activeRecommendations: const [],
        opportunities: [
          buildOpportunity(
            id: 'opp-1',
            deadline: now.add(const Duration(days: 1)),
            status: status,
          ),
        ],
        readIds: {},
        now: now,
      );

      expect(notifications, isEmpty);
    });
  }

  test('assigns high priority at 2 days left and medium at 3', () {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: [
        buildOpportunity(
          id: 'opp-2d',
          deadline: now.add(const Duration(days: 2)),
        ),
        buildOpportunity(
          id: 'opp-3d',
          deadline: now.add(const Duration(days: 3)),
        ),
      ],
      readIds: {},
      now: now,
    );

    final byId = {
      for (final n in notifications) n.relatedOpportunityIds.single: n,
    };
    expect(byId['opp-2d']!.priority, OpportunityPriority.high);
    expect(byId['opp-3d']!.priority, OpportunityPriority.medium);
  });

  test('sorts deadline notifications soonest-first', () {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: [
        buildOpportunity(
          id: 'opp-later',
          deadline: now.add(const Duration(days: 5)),
        ),
        buildOpportunity(
          id: 'opp-sooner',
          deadline: now.add(const Duration(days: 1)),
        ),
      ],
      readIds: {},
      now: now,
    );

    expect(notifications.map((n) => n.relatedOpportunityIds.single), [
      'opp-sooner',
      'opp-later',
    ]);
  });

  test('lists recommendation notifications before deadline notifications', () {
    final notifications = buildNotifications(
      activeRecommendations: [buildRecommendation(id: 'rec-1')],
      opportunities: [
        buildOpportunity(
          id: 'opp-1',
          deadline: now.add(const Duration(days: 1)),
        ),
      ],
      readIds: {},
      now: now,
    );

    expect(notifications.map((n) => n.type), [
      NotificationType.recommendation,
      NotificationType.deadline,
    ]);
  });
}
