import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_dashboard_screen.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:jva_projecttracker/services/tender_source_service.dart';
import 'package:jva_projecttracker/services/tender_sync_run_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<ProviderContainer> _pumpDashboard(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tenderSourceServiceProvider.overrideWithValue(
        TenderSourceService(firestore: firestore),
      ),
      opportunityServiceProvider.overrideWithValue(
        OpportunityService(firestore: firestore),
      ),
      recommendationServiceProvider.overrideWithValue(
        RecommendationService(firestore: firestore),
      ),
      tenderSyncRunServiceProvider.overrideWithValue(
        TenderSyncRunService(firestore: firestore),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DiscoveryDashboardBody()),
    ),
  );
  return container;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets(
    'shows a loading spinner before the tenderSources stream has emitted, '
    'not the empty state — regression test for the premature '
    '"No tender sources configured yet" bug',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tenderSources').add({
        'name': 'Tenders Kenya (PPIP)',
        'status': 'active',
        'enabled': true,
      });

      await _pumpDashboard(tester, firestore);
      // Deliberately only one pump — before the stream's first snapshot
      // has been delivered — to observe the transient loading frame.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text(_strings.noTenderSourcesConfiguredMessage),
        findsNothing,
      );

      // Let the stream settle before the test ends, so no pending timer
      // trips the test framework's teardown invariant check.
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'shows the empty state once the stream resolves to zero documents',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpDashboard(tester, firestore);
      await tester.pumpAndSettle();

      expect(
        find.text(_strings.noTenderSourcesConfiguredMessage),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'does not show the empty state once the stream resolves with sources',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tenderSources').add({
        'name': 'Tenders Kenya (PPIP)',
        'status': 'active',
        'enabled': true,
      });

      await _pumpDashboard(tester, firestore);
      await tester.pumpAndSettle();

      expect(
        find.text(_strings.noTenderSourcesConfiguredMessage),
        findsNothing,
      );
      // Note: a CircularProgressIndicator legitimately still appears here —
      // _HealthRing (discovery_dashboard_screen.dart) reuses it as a
      // health-score ring, not a loading indicator, so it isn't asserted
      // against in this test.
      expect(find.text(_strings.discoveryHealthLabel), findsWidgets);
    },
  );
}
