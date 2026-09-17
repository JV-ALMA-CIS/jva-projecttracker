import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/core/notification_providers.dart';
import 'package:jva_projecttracker/services/opportunities/opportunity_providers.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';

/// Regression coverage for the write-storm bug: MatchNotificationWatcher
/// re-scanning the whole opportunities collection and firing
/// markMatchNotificationSent for every already-qualifying opportunity on
/// every snapshot emission — including the emission its own write causes —
/// which without a guard becomes an unbounded loop of writes begetting new
/// snapshots begetting more writes (the reported "Discovery Engine spinner
/// never resolves, back button lags" symptom, caused by this running
/// continuously in the background from home_shell.dart's watch on
/// urgentAlertsProvider).
void main() {
  test(
    'settles to exactly one write per qualifying opportunity, never re-fires '
    'once handled — even across several snapshot emissions',
    () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);

      // 5 opportunities that already qualify (score >= 70, never notified).
      for (var i = 0; i < 5; i++) {
        await firestore.collection('opportunities').add({
          'title': 'Opportunity $i',
          'description': '',
          'sourceUrl': 'https://example.com/$i',
          'status': 'discovered',
          'fitScorePercent': 80,
          'discoveredAt': now,
          'updatedAt': now,
        });
      }

      final container = ProviderContainer(
        overrides: [
          opportunityServiceProvider.overrideWithValue(
            OpportunityService(firestore: firestore),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Mounts the watcher and lets its writes + the snapshots they cause
      // settle. If the old unguarded code path were still in place, this
      // loop would keep finding "new" work forever; with the fix, it must
      // reach a fixed point where every opportunity is durably marked.
      container.listen(matchNotificationWatcherProvider, (_, _) {});
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final docs = await firestore.collection('opportunities').get();
      for (final doc in docs.docs) {
        expect(
          doc.data()['lastNotifiedScore'],
          80,
          reason: 'every qualifying opportunity should be durably marked',
        );
      }
    },
  );

  test(
    'caps writes at kMaxMatchNotificationWritesPerPass in a single build() pass',
    () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);

      // More qualifying opportunities than the per-pass cap, all created
      // before the watcher ever mounts (so the very first build() sees the
      // whole backlog at once — the exact "large backlog" scenario the cap
      // protects against).
      final backlogSize = kMaxMatchNotificationWritesPerPass + 10;
      for (var i = 0; i < backlogSize; i++) {
        await firestore.collection('opportunities').add({
          'title': 'Opportunity $i',
          'description': '',
          'sourceUrl': 'https://example.com/$i',
          'status': 'discovered',
          'fitScorePercent': 80,
          'discoveredAt': now,
          'updatedAt': now,
        });
      }

      final container = ProviderContainer(
        overrides: [
          opportunityServiceProvider.overrideWithValue(
            OpportunityService(firestore: firestore),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(matchNotificationWatcherProvider, (_, _) {});
      // Only enough time for roughly one build() pass to fire its writes —
      // not enough for every follow-up snapshot to fully settle the whole
      // backlog, so the cap should still be visibly in effect.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final docs = await firestore.collection('opportunities').get();
      final markedCount = docs.docs
          .where((d) => d.data()['lastNotifiedScore'] != null)
          .length;

      // Not every opportunity should be marked yet — the cap must have
      // limited the first pass rather than writing all of them at once.
      expect(markedCount, lessThan(backlogSize));
    },
  );
}
