import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_strategic_review_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/strategic_review_service.dart';
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
  required StrategicReviewService reviewService,
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
        strategicReviewServiceProvider.overrideWithValue(reviewService),
        // The report renders RecommendedEntityChips for seven entity types —
        // each needs its own service provider overridden, or it would fall
        // back to the real FirebaseFirestore.instance with no Firebase
        // Core init.
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
        experienceServiceProvider.overrideWithValue(
          ExperienceService(firestore: firestore),
        ),
        knowledgeServiceProvider.overrideWithValue(
          KnowledgeService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: OpportunityStrategicReviewScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state before running a strategic review', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);

    await _pumpScreen(
      tester,
      firestore,
      id,
      reviewService: StrategicReviewService(invokeOverride: (_) async => null),
    );

    expect(find.text(_strings.noStrategicReviewYet), findsOneWidget);
    expect(find.text(_strings.neverReviewedStrategicallyLabel), findsOneWidget);
    expect(find.text(_strings.runStrategicReviewButton), findsOneWidget);
  });

  testWidgets(
    'running a strategic review shows a loading state then renders the report',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final reviewService = StrategicReviewService(
        invokeOverride: (opportunityId) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final payload = {
            'executiveRecommendation': 'pursue',
            'executiveSummary': 'Strong strategic fit, recommend pursuing.',
            'strategicStrengths': ['Deep water infrastructure experience'],
            'strategicWeaknesses': ['No local office in the region'],
            'strategicRisks': ['Tight delivery timeline'],
            'mitigationStrategies': ['Partner with a local subcontractor'],
            'proposalPositioningStrategy':
                'Lead with the water infrastructure case study.',
            'nextRecommendedActions': [
              'Schedule a scoping call with the client',
            ],
          };
          // The real `generateStrategicReview` Cloud Function writes to
          // Firestore as a side effect of returning this payload — this
          // screen is a pure live-stream renderer (see the class doc
          // comment), so the mock must replicate that write for the stream
          // to have anything new to emit.
          await firestore.collection('opportunities').doc(opportunityId).update(
            {...payload, 'strategicReviewedAt': DateTime.utc(2024, 8, 1)},
          );
          return {
            ...payload,
            'strategicReviewedAt': DateTime.utc(2024, 8, 1).toIso8601String(),
          };
        },
      );

      await _pumpScreen(tester, firestore, id, reviewService: reviewService);

      await tester.tap(find.text(_strings.runStrategicReviewButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(
            _strings.strategicReviewRecommendationLabel(
              StrategicReviewRecommendation.pursue,
            ),
          ),
        ),
        findsOneWidget,
      );
      // The Strategic Decision panel (Business Workflow Governance) now
      // renders above the executive summary, pushing it below the default
      // test viewport — scroll before asserting on it and the sections that
      // follow it.
      await tester.scrollUntilVisible(
        find.text('Strong strategic fit, recommend pursuing.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Strong strategic fit, recommend pursuing.'),
        findsOneWidget,
      );
      expect(find.text('Deep water infrastructure experience'), findsOneWidget);
      expect(find.text('No local office in the region'), findsOneWidget);
      expect(find.text('Tight delivery timeline'), findsOneWidget);

      // "Proposal positioning strategy" is one of the last sections, past
      // the default test viewport — scroll the report's ListView until it
      // builds.
      await tester.scrollUntilVisible(
        find.text('Lead with the water infrastructure case study.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Lead with the water infrastructure case study.'),
        findsOneWidget,
      );
      expect(find.text(_strings.strategicReviewSucceeded), findsOneWidget);
      expect(find.text(_strings.noStrategicReviewYet), findsNothing);
    },
  );

  testWidgets(
    'a failed strategic review shows an error and leaves the report empty',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final reviewService = StrategicReviewService(
        invokeOverride: (opportunityId) async =>
            throw Exception('Gemini unavailable'),
      );

      await _pumpScreen(tester, firestore, id, reviewService: reviewService);

      await tester.tap(find.text(_strings.runStrategicReviewButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Strategic review failed'), findsOneWidget);
      expect(find.text(_strings.noStrategicReviewYet), findsOneWidget);
    },
  );
}
