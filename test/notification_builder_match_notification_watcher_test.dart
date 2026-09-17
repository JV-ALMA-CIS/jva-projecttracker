import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';

/// Tests for the pure decision logic `MatchNotificationWatcher`
/// (lib/services/core/notification_providers.dart) relies on to decide
/// whether to durably write `lastNotifiedScore`/`matchNotificationSentAt` —
/// `matchNotifyScoreFor`, `matchScoreBucket`, and
/// `shouldMarkMatchNotificationSent`. The watcher itself is a thin Riverpod
/// wrapper with no branching logic of its own (it just calls
/// `shouldMarkMatchNotificationSent` per opportunity and writes when true),
/// so exercising this shared logic is equivalent to exercising the watcher.
void main() {
  final now = DateTime.utc(2024, 8, 10);

  Opportunity buildOpportunity({
    required String id,
    int? overallMatchScore,
    int fitScorePercent = 0,
    OpportunityStatus status = OpportunityStatus.reviewing,
    int? lastNotifiedScore,
  }) {
    return Opportunity(
      id: id,
      title: 'Opportunity $id',
      description: '',
      sourceUrl: 'https://example.com/$id',
      status: status,
      fitScorePercent: fitScorePercent,
      overallMatchScore: overallMatchScore,
      lastNotifiedScore: lastNotifiedScore,
      discoveredAt: now,
      updatedAt: now,
    );
  }

  group('matchScoreBucket', () {
    test('buckets scores into their ten-point band', () {
      expect(matchScoreBucket(70), 70);
      expect(matchScoreBucket(79), 70);
      expect(matchScoreBucket(80), 80);
      expect(matchScoreBucket(99), 90);
    });
  });

  group('matchNotifyScoreFor', () {
    test('returns overallMatchScore when set and >= threshold', () {
      final opportunity = buildOpportunity(id: 'opp-1', overallMatchScore: 72);
      expect(matchNotifyScoreFor(opportunity), 72);
    });

    test('falls back to fitScorePercent when overallMatchScore is null', () {
      final opportunity = buildOpportunity(id: 'opp-1', fitScorePercent: 75);
      expect(matchNotifyScoreFor(opportunity), 75);
    });

    test('returns null when below threshold', () {
      final opportunity = buildOpportunity(id: 'opp-1', overallMatchScore: 65);
      expect(matchNotifyScoreFor(opportunity), isNull);
    });

    for (final status in [
      OpportunityStatus.won,
      OpportunityStatus.lost,
      OpportunityStatus.dismissed,
    ]) {
      test('returns null for a $status opportunity even with a high score', () {
        final opportunity = buildOpportunity(
          id: 'opp-1',
          overallMatchScore: 95,
          status: status,
        );
        expect(matchNotifyScoreFor(opportunity), isNull);
      });
    }
  });

  group('shouldMarkMatchNotificationSent', () {
    test(
      'true for a first-time qualifying opportunity (lastNotifiedScore null)',
      () {
        final opportunity = buildOpportunity(
          id: 'opp-1',
          overallMatchScore: 72,
        );
        expect(shouldMarkMatchNotificationSent(opportunity), isTrue);
      },
    );

    test('false when the score is below threshold', () {
      final opportunity = buildOpportunity(id: 'opp-1', overallMatchScore: 65);
      expect(shouldMarkMatchNotificationSent(opportunity), isFalse);
    });

    test('false when already notified within the same decade bucket', () {
      final opportunity = buildOpportunity(
        id: 'opp-1',
        overallMatchScore: 74,
        lastNotifiedScore: 72,
      );
      expect(shouldMarkMatchNotificationSent(opportunity), isFalse);
    });

    test('true when the score has moved into a new decade bucket', () {
      final opportunity = buildOpportunity(
        id: 'opp-1',
        overallMatchScore: 85,
        lastNotifiedScore: 72,
      );
      expect(shouldMarkMatchNotificationSent(opportunity), isTrue);
    });

    test('false for a closed opportunity even if never notified before', () {
      final opportunity = buildOpportunity(
        id: 'opp-1',
        overallMatchScore: 95,
        status: OpportunityStatus.won,
      );
      expect(shouldMarkMatchNotificationSent(opportunity), isFalse);
    });
  });
}
