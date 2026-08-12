import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_classification_screen.dart';
import 'package:jva_projecttracker/services/ai_classification_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedOpportunity(FakeFirebaseFirestore firestore) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'discovered',
    'fitScorePercent': 70,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String opportunityId, {
  required AIClassificationService aiService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        aiClassificationServiceProvider.overrideWithValue(aiService),
        // The classification screen also renders a RelationshipPicker for
        // every Company Intelligence entity — each needs its own service
        // provider overridden, or it would fall back to the real
        // FirebaseFirestore.instance and fail with no Firebase Core init.
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
      child: MaterialApp(
        home: OpportunityClassificationScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets(
    'shows "not yet reviewed" and no confidence chip before running AI classification',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      await _pumpScreen(
        tester,
        firestore,
        id,
        aiService: AIClassificationService(invokeOverride: (_) async => null),
      );

      expect(find.text(_strings.neverReviewedByAiLabel), findsOneWidget);
      expect(find.textContaining('Confidence:'), findsNothing);
      expect(find.text(_strings.runAiClassificationButton), findsOneWidget);
    },
  );

  testWidgets(
    'running AI classification shows a loading state then applies the result',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final aiService = AIClassificationService(
        invokeOverride: (opportunityId) async {
          // A real gap to pump through — an override that resolves within
          // the same microtask flush as the tap would make the loading
          // state impossible to observe here (it would flip back to false
          // before this test's own `pump()` call ever runs).
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return {
            'classificationSummary': 'Strong water-infrastructure fit.',
            'confidenceScore': 91,
            'priority': 'high',
            'riskLevel': 'low',
            'classificationStatus': 'classified',
            'aiReviewedAt': DateTime.utc(2024, 8, 1).toIso8601String(),
          };
        },
      );

      await _pumpScreen(tester, firestore, id, aiService: aiService);

      await tester.tap(find.text(_strings.runAiClassificationButton));
      await tester.pump(); // start the future — the spinner should show now
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('Strong water-infrastructure fit.'), findsOneWidget);
      expect(find.text(_strings.confidenceScoreChipLabel(91)), findsOneWidget);
      expect(find.text(_strings.aiClassificationSucceeded), findsOneWidget);
      expect(find.text(_strings.neverReviewedByAiLabel), findsNothing);
    },
  );

  testWidgets(
    'a failed classification shows an error and leaves the summary untouched',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final aiService = AIClassificationService(
        invokeOverride: (opportunityId) async =>
            throw Exception('Gemini unavailable'),
      );

      await _pumpScreen(tester, firestore, id, aiService: aiService);

      await tester.tap(find.text(_strings.runAiClassificationButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('AI classification failed'), findsOneWidget);
      expect(find.text(_strings.neverReviewedByAiLabel), findsOneWidget);
    },
  );
}
