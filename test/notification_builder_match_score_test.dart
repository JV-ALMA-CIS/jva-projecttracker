import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';

void main() {
  final now = DateTime.utc(2024, 8, 10);

  Opportunity buildOpportunity({
    required String id,
    int? overallMatchScore,
    int fitScorePercent = 0,
    OpportunityStatus status = OpportunityStatus.reviewing,
    DateTime? matchAnalyzedAt,
  }) {
    return Opportunity(
      id: id,
      title: 'Opportunity $id',
      description: '',
      sourceUrl: 'https://example.com/$id',
      status: status,
      fitScorePercent: fitScorePercent,
      overallMatchScore: overallMatchScore,
      matchAnalyzedAt: matchAnalyzedAt,
      discoveredAt: now,
      updatedAt: now,
    );
  }

  List<NotificationItem> matchScoreItems(
    List<Opportunity> opportunities, {
    Set<String> readIds = const {},
  }) {
    final notifications = buildNotifications(
      activeRecommendations: const [],
      opportunities: opportunities,
      readIds: readIds,
      now: now,
    );
    return notifications
        .where((n) => n.type == NotificationType.matchScore)
        .toList();
  }

  test('produces a notification when overallMatchScore is at or above 70', () {
    final items = matchScoreItems([
      buildOpportunity(id: 'opp-1', overallMatchScore: 72),
    ]);

    expect(items, hasLength(1));
    expect(items.single.matchScorePercent, 72);
    expect(items.single.relatedOpportunityIds, ['opp-1']);
  });

  test('produces no notification when overallMatchScore is below 70', () {
    final items = matchScoreItems([
      buildOpportunity(id: 'opp-1', overallMatchScore: 65),
    ]);

    expect(items, isEmpty);
  });

  test('falls back to fitScorePercent when overallMatchScore is null', () {
    final items = matchScoreItems([
      buildOpportunity(id: 'opp-1', fitScorePercent: 80),
    ]);

    expect(items, hasLength(1));
    expect(items.single.matchScorePercent, 80);
  });

  test('overallMatchScore wins over fitScorePercent when both are set', () {
    final items = matchScoreItems([
      buildOpportunity(id: 'opp-1', fitScorePercent: 30, overallMatchScore: 90),
    ]);

    expect(items, hasLength(1));
    expect(items.single.matchScorePercent, 90);
  });

  for (final status in [
    OpportunityStatus.won,
    OpportunityStatus.lost,
    OpportunityStatus.dismissed,
  ]) {
    test(
      'produces no notification for a $status opportunity even with a high score',
      () {
        final items = matchScoreItems([
          buildOpportunity(id: 'opp-1', overallMatchScore: 95, status: status),
        ]);

        expect(items, isEmpty);
      },
    );
  }

  test('the same score stays in the same decade bucket -> same id (dedup)', () {
    final idAt72 = matchScoreItems([
      buildOpportunity(id: 'opp-1', overallMatchScore: 72),
    ]).single.id;
    final idAt79 = matchScoreItems([
      buildOpportunity(id: 'opp-1', overallMatchScore: 79),
    ]).single.id;

    expect(idAt72, idAt79);
  });

  test(
    'a jump into a new decade bucket produces a different id (re-notify)',
    () {
      final idAt72 = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 72),
      ]).single.id;
      final idAt85 = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 85),
      ]).single.id;

      expect(idAt72, isNot(idAt85));
    },
  );

  test(
    'a bucket already marked read stays read on re-derivation with the same score',
    () {
      final firstPass = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 72),
      ]);
      final readIds = {firstPass.single.id};

      final secondPass = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 74),
      ], readIds: readIds);

      expect(secondPass.single.isRead, isTrue);
    },
  );

  test(
    'crossing into a new decade bucket after being read is unread again',
    () {
      final firstPass = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 72),
      ]);
      final readIds = {firstPass.single.id};

      final secondPass = matchScoreItems([
        buildOpportunity(id: 'opp-1', overallMatchScore: 88),
      ], readIds: readIds);

      expect(secondPass.single.isRead, isFalse);
    },
  );
}
