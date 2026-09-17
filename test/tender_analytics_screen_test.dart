import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/tender_analytics_screen.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/tender_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opportunityServiceProvider.overrideWithValue(
        OpportunityService(firestore: firestore),
      ),
      tenderSourceServiceProvider.overrideWithValue(
        TenderSourceService(firestore: firestore),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TenderAnalyticsScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets(
    'shows the empty state once the stream resolves to zero opportunities',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _pumpScreen(tester, firestore);
      await tester.pumpAndSettle();

      expect(find.text(_strings.noAnalyticsDataYetMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'does not show the empty state once the stream resolves with opportunities',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('opportunities').add({
        'title': 'Rural water tender',
        'description': '',
        'sourceUrl': 'https://example.com/tender/1',
        'status': 'discovered',
        'fitScorePercent': 70,
        'discoveredAt': DateTime.utc(2024, 1, 1),
        'updatedAt': DateTime.utc(2024, 1, 1),
        'tenderSourceId': 'src-1',
      });

      await _pumpScreen(tester, firestore);
      await tester.pumpAndSettle();

      expect(find.text(_strings.noAnalyticsDataYetMessage), findsNothing);
      expect(find.text(_strings.monthlyTrendLabel), findsOneWidget);
    },
  );
}
