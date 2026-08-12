import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_history_screen.dart';
import 'package:jva_projecttracker/services/discovery_run_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        discoveryRunServiceProvider.overrideWithValue(
          DiscoveryRunService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: DiscoveryHistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state when no runs have been recorded', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noDiscoveryRunsMessage), findsOneWidget);
  });

  testWidgets('renders a completed run with its counts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 8, 1);
    await firestore.collection('discoveryRuns').add({
      'sourceId': 'source-1',
      'sourceName': 'World Bank tenders',
      'sourceType': 'developmentOrganization',
      'status': 'completed',
      'trigger': 'manual',
      'candidatesFound': 8,
      'opportunitiesCreated': 5,
      'duplicatesSkipped': 3,
      'startedAt': now,
      'completedAt': now,
    });

    await _pumpScreen(tester, firestore);

    expect(find.text('World Bank tenders'), findsOneWidget);
    expect(
      find.text(_strings.discoveryRunStatusLabel(DiscoveryRunStatus.completed)),
      findsOneWidget,
    );
  });

  testWidgets('a failed run\'s error message expands on tap', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 8, 1);
    await firestore.collection('discoveryRuns').add({
      'sourceId': 'source-2',
      'sourceName': 'Some RSS feed',
      'sourceType': 'rss',
      'status': 'failed',
      'trigger': 'manual',
      'errorMessage': 'Source type "rss" is not yet automated.',
      'startedAt': now,
    });

    await _pumpScreen(tester, firestore);
    expect(find.text('Source type "rss" is not yet automated.'), findsNothing);

    await tester.tap(find.text('Some RSS feed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Source type "rss" is not yet automated.'),
      findsOneWidget,
    );
  });
}
