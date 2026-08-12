import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/dashboard/dashboard_screen.dart';
import 'package:jva_projecttracker/services/application_service.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
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
        projectServiceProvider.overrideWithValue(
          ProjectService(firestore: firestore),
        ),
        applicationServiceProvider.overrideWithValue(
          ApplicationService(firestore: firestore),
        ),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
        proposalServiceProvider.overrideWithValue(
          ProposalService(firestore: firestore),
        ),
        opportunityEventServiceProvider.overrideWithValue(
          OpportunityEventService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty recommendations state with no data', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.scrollUntilVisible(
      find.text(_strings.noAiRecommendationsGroundedMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(_strings.noAiRecommendationsGroundedMessage),
      findsOneWidget,
    );
  });

  testWidgets('shows the command-center sections\' empty states with no data', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.youreAllCaughtUpMessage), findsOneWidget);

    // The later sections start below the fold — scroll them into view
    // before asserting, same as proposal_workspace_screen_test.dart does
    // for its own long scrollable body.
    await tester.scrollUntilVisible(
      find.text(_strings.noActiveProjectsMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_strings.noActiveProjectsMessage), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(_strings.noRecentActivity),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_strings.noRecentActivity), findsOneWidget);
  });

  testWidgets('shows a top recommendation card once one is generated', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 8, 1);
    await firestore.collection('recommendations').add({
      'category': 'priorityOpportunity',
      'priority': 'high',
      'title': 'Fast-track the Rural Water Tender',
      'reasoning': 'Strong strategic fit and an approaching deadline.',
      'status': 'active',
      'generatedAt': now,
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore);

    // findsNWidgets(2), not findsOneWidget: a high-priority active
    // recommendation legitimately renders twice — once as a NotificationTile
    // in "Needs attention" (it's high priority) and once as a
    // RecommendationCard in "AI Recommendations".
    expect(find.text('Fast-track the Rural Water Tender'), findsNWidgets(2));
    expect(
      find.text(_strings.noAiRecommendationsGroundedMessage),
      findsNothing,
    );
  });

  // The notification bell (and its unread-count Badge) moved from
  // DashboardScreen's own AppBar into AppSidebar as part of the header
  // consolidation pass — Search/Notifications now live once in the
  // persistent shell instead of being redeclared per main-module screen.
  // DashboardScreen no longer renders a NotificationBellButton at all, so a
  // Dashboard-only test can't assert on its badge; that behavior belongs in
  // an AppSidebar-level test if/when one exists.
}
