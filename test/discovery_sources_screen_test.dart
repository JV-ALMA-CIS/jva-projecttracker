import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/discovery_sources_screen.dart';
import 'package:jva_projecttracker/services/discovery_engine_service.dart';
import 'package:jva_projecttracker/services/discovery_run_service.dart';
import 'package:jva_projecttracker/services/discovery_source_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
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
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        discoverySourceServiceProvider.overrideWithValue(
          DiscoverySourceService(firestore: firestore),
        ),
        discoveryRunServiceProvider.overrideWithValue(
          DiscoveryRunService(firestore: firestore),
        ),
        discoveryEngineServiceProvider.overrideWithValue(
          DiscoveryEngineService(),
        ),
      ],
      child: const MaterialApp(home: DiscoverySourcesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when no sources are configured', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noDiscoverySourcesMessage), findsOneWidget);
  });

  testWidgets('adding a source via the dialog creates it', (tester) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, _strings.fieldSourceName),
      'World Bank tenders',
    );
    await tester.tap(find.text(_strings.saveButton));
    await tester.pumpAndSettle();

    expect(find.text('World Bank tenders'), findsOneWidget);
  });

  testWidgets(
    'Run now is disabled with a tooltip for a source type with no automated adapter',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      await firestore.collection('discoverySources').add({
        'name': 'Some RSS feed',
        'type': 'rss',
        'enabled': true,
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_circle_outline),
      );
      expect(button.onPressed, isNull);
      expect(button.tooltip, _strings.notYetAutomatedTooltip);
    },
  );

  testWidgets('the enabled switch calls setEnabled', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    final doc = await firestore.collection('discoverySources').add({
      'name': 'Government portal',
      'type': 'governmentProcurement',
      'enabled': true,
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final updated = await firestore
        .collection('discoverySources')
        .doc(doc.id)
        .get();
    expect(updated.data()!['enabled'], isFalse);
  });
}
