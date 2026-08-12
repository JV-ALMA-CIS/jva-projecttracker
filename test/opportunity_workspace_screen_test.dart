import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_workspace_screen.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedFreshOpportunity(
  FakeFirebaseFirestore firestore, {
  String pipelineStage = 'discovered',
}) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'fitScorePercent': 70,
    'fitReasoning': 'Strong alignment with our water infrastructure work.',
    'status': 'discovered',
    'pipelineStage': pipelineStage,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String opportunityId,
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
        projectServiceProvider.overrideWithValue(
          ProjectService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: OpportunityWorkspaceScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('header shows the fit score and current pipeline stage', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedFreshOpportunity(firestore);

    await _pumpScreen(tester, firestore, id);

    expect(find.text('70%'), findsOneWidget);
    // findsWidgets, not findsOneWidget: the stage renders both on the
    // header and on the (collapsed) Pipeline & Timeline section's subtitle.
    expect(
      find.text(
        _strings.pipelineStageLabel(OpportunityPipelineStage.discovered),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'Needs attention lists all three AI passes as outstanding before any have run',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(firestore);

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.runAiClassificationButton), findsOneWidget);
      expect(find.text(_strings.runMatchAnalysisButton), findsOneWidget);
      expect(find.text(_strings.runStrategicReviewButton), findsOneWidget);
    },
  );

  testWidgets(
    'AI overview falls back to the discovery-time fit reasoning before any AI pass has run',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(firestore);

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.fitReasoningLabel), findsOneWidget);
      expect(
        find.text('Strong alignment with our water infrastructure work.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the Project section does not render before the opportunity is awarded',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(
        firestore,
        pipelineStage: 'proposalStarted',
      );

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.startProjectButton), findsNothing);
      expect(find.text(_strings.projectSectionTitle), findsNothing);
    },
  );

  testWidgets(
    'the Project section does not render when the opportunity was lost',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(firestore, pipelineStage: 'lost');

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.startProjectButton), findsNothing);
    },
  );

  testWidgets(
    'shows a Start Project prompt once the opportunity is awarded with no project yet',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(
        firestore,
        pipelineStage: 'awarded',
      );

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text(_strings.startProjectButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.startProjectButton), findsOneWidget);
    },
  );

  testWidgets(
    'shows the linked project once one has been started from this opportunity',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedFreshOpportunity(
        firestore,
        pipelineStage: 'awarded',
      );
      final now = DateTime.utc(2024, 1, 2);
      await firestore.collection('projects').add({
        'name': 'Rural Water Network Build',
        'description': '',
        'client': '',
        'status': 'planned',
        'sourceOpportunityId': id,
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text('Rural Water Network Build'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rural Water Network Build'), findsOneWidget);
      expect(find.text(_strings.startProjectButton), findsNothing);
    },
  );
}
