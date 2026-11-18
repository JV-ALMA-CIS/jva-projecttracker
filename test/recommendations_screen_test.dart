import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
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
import 'package:jva_projecttracker/services/recommendation_engine_service.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore, {
  required RecommendationEngineService engineService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
        recommendationEngineServiceProvider.overrideWithValue(engineService),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
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
      child: const MaterialApp(home: RecommendationsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty active state before any refresh', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();

    await _pumpScreen(
      tester,
      firestore,
      engineService: RecommendationEngineService(
        invokeOverride: () async => {'created': 0},
      ),
    );

    expect(find.text(_strings.noActiveRecommendations), findsOneWidget);
    expect(find.text(_strings.refreshRecommendationsButton), findsOneWidget);
  });

  testWidgets(
    'refreshing shows a loading state then renders new recommendations',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      final engineService = RecommendationEngineService(
        invokeOverride: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
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
          return {'created': 1};
        },
      );

      await _pumpScreen(tester, firestore, engineService: engineService);

      await tester.tap(find.text(_strings.refreshRecommendationsButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('Fast-track the Rural Water Tender'), findsOneWidget);
      expect(
        find.text(_strings.recommendationsRefreshSucceeded(1)),
        findsOneWidget,
      );
      expect(find.text(_strings.noActiveRecommendations), findsNothing);
    },
  );

  testWidgets('dismissing a recommendation moves it out of the Active filter', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 8, 1);
    await firestore.collection('recommendations').add({
      'category': 'general',
      'priority': 'medium',
      'title': 'Consider developing this capability',
      'reasoning': 'Requested in three recent opportunities.',
      'status': 'active',
      'generatedAt': now,
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(
      tester,
      firestore,
      engineService: RecommendationEngineService(
        invokeOverride: () async => {'created': 0},
      ),
    );

    expect(find.text('Consider developing this capability'), findsOneWidget);

    await tester.tap(find.text(_strings.dismissRecommendationTooltip));
    await tester.pumpAndSettle();

    expect(find.text('Consider developing this capability'), findsNothing);
    expect(find.text(_strings.noActiveRecommendations), findsOneWidget);

    await tester.tap(find.text(_strings.filterDismissedLabel));
    await tester.pumpAndSettle();

    expect(find.text('Consider developing this capability'), findsOneWidget);
  });

  testWidgets(
    'related opportunities are tappable, triaged, and open a preview with Pursue',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      final strong = await firestore.collection('opportunities').add({
        'title': 'Hospital fit-out Mombasa',
        'description': '',
        'sourceUrl': 'https://example.com/a',
        'status': 'discovered',
        'fitScorePercent': 84,
        'fitReasoning': 'Matches our facility-management experience.',
        'deadline': now.add(const Duration(days: 10)),
        'discoveredAt': now,
        'updatedAt': now,
      });
      final closed = await firestore.collection('opportunities').add({
        'title': 'Old roofing tender',
        'description': '',
        'sourceUrl': 'https://example.com/b',
        'status': 'dismissed',
        'fitScorePercent': 70,
        'discoveredAt': now,
        'updatedAt': now,
      });
      await firestore.collection('recommendations').add({
        'category': 'general',
        'priority': 'high',
        'title': 'Focus on facility-management work',
        'reasoning': 'Several strong FM matches.',
        'status': 'active',
        'relatedOpportunityIds': [strong.id, closed.id],
        'generatedAt': now,
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(
        tester,
        firestore,
        engineService: RecommendationEngineService(
          invokeOverride: () async => {'created': 0},
        ),
      );

      // The worth-a-look item is shown; the closed one is folded away.
      expect(find.textContaining('Hospital fit-out Mombasa'), findsOneWidget);
      expect(find.textContaining('Old roofing tender'), findsNothing);
      expect(find.text(_strings.showReferenceLabel(1)), findsOneWidget);

      await tester.tap(find.textContaining('Hospital fit-out Mombasa'));
      await tester.pumpAndSettle();
      expect(
        find.text('Matches our facility-management experience.'),
        findsOneWidget,
      );

      await tester.tap(find.text(_strings.pursueButton));
      await tester.pumpAndSettle();
      final doc = await firestore
          .collection('opportunities')
          .doc(strong.id)
          .get();
      expect(doc.data()!['status'], 'reviewing');
    },
  );

  testWidgets(
    'a recommendation whose related opportunities all closed is folded as outdated',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      final expired = await firestore.collection('opportunities').add({
        'title': 'Expired tender',
        'description': '',
        'sourceUrl': 'https://example.com/c',
        'status': 'discovered',
        'fitScorePercent': 90,
        'deadline': now.subtract(const Duration(days: 2)),
        'discoveredAt': now,
        'updatedAt': now,
      });
      await firestore.collection('recommendations').add({
        'category': 'priorityOpportunity',
        'priority': 'high',
        'title': 'Fast-track the expired tender',
        'reasoning': 'It was a strong fit.',
        'status': 'active',
        'relatedOpportunityIds': [expired.id],
        'generatedAt': now,
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(
        tester,
        firestore,
        engineService: RecommendationEngineService(
          invokeOverride: () async => {'created': 0},
        ),
      );

      expect(find.text(_strings.noActiveRecommendations), findsOneWidget);
      expect(
        find.text(_strings.outdatedRecommendationsLabel(1)),
        findsOneWidget,
      );
    },
  );
}
