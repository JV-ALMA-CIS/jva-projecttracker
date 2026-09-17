import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/notifications/notification_center_screen.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunities_screen.dart';
import 'package:jva_projecttracker/screens/recommendations/recommendations_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
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
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
        productServiceProvider.overrideWithValue(
          ProductService(firestore: firestore),
        ),
        serviceServiceProvider.overrideWithValue(
          ServiceService(firestore: firestore),
        ),
        capabilityServiceProvider.overrideWithValue(
          CapabilityService(firestore: firestore),
        ),
        technologyServiceProvider.overrideWithValue(
          TechnologyService(firestore: firestore),
        ),
        industryServiceProvider.overrideWithValue(
          IndustryService(firestore: firestore),
        ),
        experienceServiceProvider.overrideWithValue(
          ExperienceService(firestore: firestore),
        ),
        knowledgeServiceProvider.overrideWithValue(
          KnowledgeService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: NotificationCenterScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<String> _seedRecommendation(
  FakeFirebaseFirestore firestore, {
  String title = 'Fast-track the Rural Water Tender',
}) async {
  final now = DateTime.utc(2024, 8, 1);
  final doc = await firestore.collection('recommendations').add({
    'category': 'priorityOpportunity',
    'priority': 'high',
    'title': title,
    'reasoning': 'Strong strategic fit and an approaching deadline.',
    'status': 'active',
    'generatedAt': now,
    'createdAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<String> _seedOpportunityWithDeadline(
  FakeFirebaseFirestore firestore, {
  required DateTime deadline,
  String title = 'Rural water tender',
}) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': title,
    // Must name an in-region country/city (see isOffRegionOpportunity in
    // opportunity_filters.dart) — notificationsProvider filters out
    // opportunities it can't place in Kenya/East Africa, so an
    // otherwise-qualifying deadline notification would silently never
    // render without this.
    'description': 'Design and build rural water network in Nairobi, Kenya',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'reviewing',
    // Below kMatchScoreNotifyThreshold (70) deliberately — this fixture is
    // meant to produce a deadline notification only. At/above threshold, it
    // would *also* produce a matchScore notification with the same title,
    // rendering "Rural water tender" twice and making find.text(...) below
    // ambiguous.
    'fitScorePercent': 50,
    'deadline': deadline,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

void main() {
  testWidgets('shows the empty state with nothing to notify about', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noNotificationsYet), findsOneWidget);
    expect(find.text(_strings.markAllReadButton), findsNothing);
  });

  testWidgets(
    'groups an active recommendation and a near deadline into their own sections',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecommendation(firestore);
      await _seedOpportunityWithDeadline(
        firestore,
        deadline: DateTime.now().toUtc().add(const Duration(days: 1)),
      );

      await _pumpScreen(tester, firestore);

      expect(find.text(_strings.recommendationsGroupLabel), findsOneWidget);
      expect(find.text(_strings.upcomingDeadlinesGroupLabel), findsOneWidget);
      expect(find.text('Fast-track the Rural Water Tender'), findsOneWidget);
      expect(find.text('Rural water tender'), findsOneWidget);
    },
  );

  testWidgets('"Mark all read" appears with unread items and clears them', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedRecommendation(firestore);

    await _pumpScreen(tester, firestore);

    expect(find.text(_strings.markAllReadButton), findsOneWidget);

    await tester.tap(find.text(_strings.markAllReadButton));
    await tester.pumpAndSettle();

    expect(find.text(_strings.markAllReadButton), findsNothing);
  });

  testWidgets(
    'tapping a recommendation notification opens RecommendationsScreen',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecommendation(firestore);

      await _pumpScreen(tester, firestore);

      await tester.tap(find.text('Fast-track the Rural Water Tender'));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationsScreen), findsOneWidget);
    },
  );

  testWidgets('tapping a deadline notification opens OpportunitiesScreen', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedOpportunityWithDeadline(
      firestore,
      deadline: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    await _pumpScreen(tester, firestore);

    await tester.tap(find.text('Rural water tender'));
    await tester.pumpAndSettle();

    expect(find.byType(OpportunitiesScreen), findsOneWidget);
  });
}
