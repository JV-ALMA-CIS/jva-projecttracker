import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_inbox_screen.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
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
        proposalServiceProvider.overrideWithValue(
          ProposalService(firestore: firestore),
        ),
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
        opportunityEventServiceProvider.overrideWithValue(
          OpportunityEventService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: OpportunityInboxScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<String> _seedDiscoveredOpportunity(
  FakeFirebaseFirestore firestore, {
  required String title,
  DateTime? discoveredAt,
  String? client,
}) async {
  final now = discoveredAt ?? DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': title,
    'description': 'Some description',
    'sourceUrl':
        'https://example.com/${title.hashCode}-${now.millisecondsSinceEpoch}',
    'client': client,
    'status': 'discovered',
    'fitScorePercent': 65,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state when nothing is awaiting triage', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.inboxEmptyMessage), findsOneWidget);
  });

  testWidgets('Accept moves an opportunity out of the Inbox', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(firestore, title: 'Rural water tender');

    await _pumpScreen(tester, firestore);
    expect(find.text('Rural water tender'), findsOneWidget);

    await tester.tap(find.text(_strings.acceptButton));
    await tester.pumpAndSettle();

    expect(find.text('Rural water tender'), findsNothing);
    expect(find.text(_strings.inboxEmptyMessage), findsOneWidget);
  });

  testWidgets('Ignore moves an opportunity out of the Inbox', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(firestore, title: 'Urban road bridge');

    await _pumpScreen(tester, firestore);
    await tester.tap(find.text(_strings.ignoreButton));
    await tester.pumpAndSettle();

    expect(find.text('Urban road bridge'), findsNothing);
  });

  testWidgets('Archive moves an opportunity out of the Inbox', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(firestore, title: 'School construction');

    await _pumpScreen(tester, firestore);
    await tester.tap(find.text(_strings.archiveButton));
    await tester.pumpAndSettle();

    expect(find.text('School construction'), findsNothing);
  });

  testWidgets(
    'shows a possible-duplicate banner for a later opportunity sharing an earlier one\'s title',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedDiscoveredOpportunity(
        firestore,
        title: 'Rural water tender',
        discoveredAt: DateTime.utc(2024, 1, 1),
      );
      await _seedDiscoveredOpportunity(
        firestore,
        title: 'Rural water tender',
        discoveredAt: DateTime.utc(2024, 2, 1),
      );

      await _pumpScreen(tester, firestore);

      expect(
        find.text(_strings.possibleDuplicateOf('Rural water tender')),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping a card opens the Opportunity Workspace', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(firestore, title: 'Rural water tender');

    await _pumpScreen(tester, firestore);
    await tester.tap(find.text('Rural water tender'));
    await tester.pumpAndSettle();

    expect(find.text(_strings.aiOverviewSectionTitle), findsOneWidget);
  });
}
