import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_match_analysis_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/match_analysis_service.dart';
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
  required MatchAnalysisService matchService,
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
        matchAnalysisServiceProvider.overrideWithValue(matchService),
        // The report renders RecommendedEntityChips for four entity types —
        // each needs its own service provider overridden, or it would fall
        // back to the real FirebaseFirestore.instance with no Firebase
        // Core init.
        productServiceProvider.overrideWithValue(
          ProductService(firestore: firestore),
        ),
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
        experienceServiceProvider.overrideWithValue(
          ExperienceService(firestore: firestore),
        ),
        knowledgeServiceProvider.overrideWithValue(
          KnowledgeService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: OpportunityMatchAnalysisScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state before running match analysis', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);

    await _pumpScreen(
      tester,
      firestore,
      id,
      matchService: MatchAnalysisService(invokeOverride: (_) async => null),
    );

    expect(find.text(_strings.noMatchAnalysisYet), findsOneWidget);
    expect(find.text(_strings.neverAnalyzedLabel), findsOneWidget);
    expect(find.text(_strings.runMatchAnalysisButton), findsOneWidget);
  });

  testWidgets(
    'running match analysis shows a loading state then renders the report',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final matchService = MatchAnalysisService(
        invokeOverride: (opportunityId) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final payload = {
            'overallMatchScore': 87,
            'businessUnitScore': 90,
            'productScore': 80,
            'strategicRecommendation': 'Strong strategic fit, pursue actively.',
            'strengths': ['Deep water infrastructure experience'],
            'gaps': ['No prior work in this specific region'],
            'risks': ['Tight delivery timeline'],
            'nextActions': ['Schedule a scoping call with the client'],
          };
          // The real `analyzeOpportunityMatch` Cloud Function writes to
          // Firestore as a side effect of returning this payload — this
          // screen is a pure live-stream renderer (see the class doc
          // comment), so the mock must replicate that write for the
          // stream to have anything new to emit.
          await firestore.collection('opportunities').doc(opportunityId).update(
            {...payload, 'matchAnalyzedAt': DateTime.utc(2024, 8, 1)},
          );
          return {
            ...payload,
            'matchAnalyzedAt': DateTime.utc(2024, 8, 1).toIso8601String(),
          };
        },
      );

      await _pumpScreen(tester, firestore, id, matchService: matchService);

      await tester.tap(find.text(_strings.runMatchAnalysisButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('87%'), findsOneWidget);
      expect(
        find.text('Strong strategic fit, pursue actively.'),
        findsOneWidget,
      );
      expect(find.text('Deep water infrastructure experience'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No prior work in this specific region'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No prior work in this specific region'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Tight delivery timeline'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tight delivery timeline'), findsOneWidget);

      // "Suggested next actions" is the last bullet section, past the
      // default test viewport — scroll the report's ListView until it
      // builds.
      await tester.scrollUntilVisible(
        find.text('Schedule a scoping call with the client'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Schedule a scoping call with the client'),
        findsOneWidget,
      );
      expect(find.text(_strings.matchAnalysisSucceeded), findsOneWidget);
      expect(find.text(_strings.noMatchAnalysisYet), findsNothing);
    },
  );

  testWidgets(
    'a failed match analysis shows an error and leaves the report empty',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      final matchService = MatchAnalysisService(
        invokeOverride: (opportunityId) async =>
            throw Exception('Gemini unavailable'),
      );

      await _pumpScreen(tester, firestore, id, matchService: matchService);

      await tester.tap(find.text(_strings.runMatchAnalysisButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Match analysis failed'), findsOneWidget);
      expect(find.text(_strings.noMatchAnalysisYet), findsOneWidget);
    },
  );
}
