import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_inbox_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore, {
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
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
  String kind = 'tender',
  int fitScorePercent = 65,
  DateTime? deadline,
  List<String> businessUnitIds = const [],
}) async {
  final now = discoveredAt ?? DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': title,
    'description': 'Some description',
    'sourceUrl':
        'https://example.com/${title.hashCode}-${now.millisecondsSinceEpoch}',
    'client': client,
    'status': 'discovered',
    'fitScorePercent': fitScorePercent,
    'kind': kind,
    'deadline': deadline,
    'businessUnitIds': businessUnitIds,
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

  testWidgets(
    'groups the Inbox into Tenders / Grants / Programmes tabs with counts',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedDiscoveredOpportunity(firestore, title: 'Fencing works');
      await _seedDiscoveredOpportunity(
        firestore,
        title: 'Classroom renovation',
      );
      await _seedDiscoveredOpportunity(
        firestore,
        title: 'ABIL EXPLORE call',
        kind: 'grant',
      );
      await _pumpScreen(tester, firestore);

      expect(find.text('Tenders (2)'), findsOneWidget);
      expect(find.text('Grants / Calls (1)'), findsOneWidget);
      expect(find.text('Fencing works'), findsOneWidget);
      expect(find.text('ABIL EXPLORE call'), findsNothing);

      await tester.tap(find.text('Grants / Calls (1)'));
      await tester.pumpAndSettle();
      expect(find.text('ABIL EXPLORE call'), findsOneWidget);
      expect(find.text('Fencing works'), findsNothing);
    },
  );

  testWidgets('opens on the tab the person used last', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(firestore, title: 'Fencing works');
    await _seedDiscoveredOpportunity(
      firestore,
      title: 'ABIL EXPLORE call',
      kind: 'grant',
    );
    await _pumpScreen(tester, firestore, prefsValues: {'inbox.kind': 'grant'});

    expect(find.text('ABIL EXPLORE call'), findsOneWidget);
    expect(find.text('Fencing works'), findsNothing);
  });

  testWidgets('business-unit chips narrow tenders to one unit', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final bu = await firestore.collection('businessUnits').add({
      'name': 'Construction',
      'slug': 'construction',
      'createdAt': DateTime.utc(2024),
      'updatedAt': DateTime.utc(2024),
    });
    await _seedDiscoveredOpportunity(
      firestore,
      title: 'Drainage works',
      businessUnitIds: [bu.id],
    );
    await _seedDiscoveredOpportunity(firestore, title: 'Supply of stationery');
    await _pumpScreen(tester, firestore);

    await tester.tap(find.text('Construction (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Drainage works'), findsOneWidget);
    expect(find.text('Supply of stationery'), findsNothing);
  });

  testWidgets('closed opportunities drop out; best match is listed first', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedDiscoveredOpportunity(
      firestore,
      title: 'Already closed tender',
      deadline: DateTime.now().subtract(const Duration(days: 1)),
    );
    await _seedDiscoveredOpportunity(
      firestore,
      title: 'Weak match',
      fitScorePercent: 51,
    );
    await _seedDiscoveredOpportunity(
      firestore,
      title: 'Strong match',
      fitScorePercent: 88,
      deadline: DateTime.now().add(const Duration(days: 10)),
    );
    await _pumpScreen(tester, firestore);

    expect(find.text('Already closed tender'), findsNothing);
    final strongY = tester.getTopLeft(find.text('Strong match')).dy;
    final weakY = tester.getTopLeft(find.text('Weak match')).dy;
    expect(strongY, lessThan(weakY));
    expect(find.textContaining('Closes in'), findsOneWidget);
  });
}
