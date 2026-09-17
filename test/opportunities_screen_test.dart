import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunities_screen.dart';
import 'package:jva_projecttracker/services/discovery_engine_service.dart';
import 'package:jva_projecttracker/services/discovery_run_service.dart';
import 'package:jva_projecttracker/services/discovery_source_service.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:jva_projecttracker/services/tender_source_service.dart';
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
        discoverySourceServiceProvider.overrideWithValue(
          DiscoverySourceService(firestore: firestore),
        ),
        discoveryRunServiceProvider.overrideWithValue(
          DiscoveryRunService(firestore: firestore),
        ),
        discoveryEngineServiceProvider.overrideWithValue(
          DiscoveryEngineService(),
        ),
        tenderSourceServiceProvider.overrideWithValue(
          TenderSourceService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: OpportunitiesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state when there are no opportunities', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noOpportunitiesDiscovered), findsOneWidget);
  });

  testWidgets(
    'expanding a legacy (unclassified) opportunity shows only the default classification chip',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'Rural water tender',
        'description': 'Design and build rural water network',
        'sourceUrl': 'https://example.com/tender/1',
        'status': 'discovered',
        'fitScorePercent': 70,
        'discoveredAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);
      expect(find.text('Rural water tender'), findsOneWidget);

      await tester.tap(find.text('Rural water tender'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          _strings.classificationStatusLabel(
            ClassificationStatus.notClassified,
          ),
        ),
        findsOneWidget,
      );
      // findsWidgets, not findsOneWidget: the pipeline-stage chip and the
      // OpportunityStatus dropdown's own selected-value display both
      // legitimately render "Discovered" here (both enums default to a
      // same-named, same-labeled value).
      expect(
        find.text(
          _strings.pipelineStageLabel(OpportunityPipelineStage.discovered),
        ),
        findsWidgets,
      );
      expect(find.textContaining('Confidence:'), findsNothing);
    },
  );

  testWidgets(
    'expanding a classified opportunity shows confidence, priority and risk chips',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'Road rehabilitation tender',
        'description': 'Rehabilitate 40km of rural road',
        'sourceUrl': 'https://example.com/tender/2',
        'status': 'discovered',
        'fitScorePercent': 85,
        'discoveredAt': now,
        'updatedAt': now,
        'classificationStatus': 'classified',
        'confidenceScore': 72,
        'priority': 'high',
        'riskLevel': 'low',
        'industryIds': ['industry-1'],
      });

      await _pumpScreen(tester, firestore);
      await tester.tap(find.text('Road rehabilitation tender'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          _strings.classificationStatusLabel(ClassificationStatus.classified),
        ),
        findsOneWidget,
      );
      expect(find.text(_strings.confidenceScoreChipLabel(72)), findsOneWidget);
      expect(
        find.text(_strings.opportunityPriorityLabel(OpportunityPriority.high)),
        findsOneWidget,
      );
      expect(find.text(_strings.riskLevelLabel(RiskLevel.low)), findsOneWidget);
      expect(find.text(_strings.relatedKnowledgeCount(1)), findsOneWidget);
    },
  );

  testWidgets(
    'opening the workspace for an opportunity in a later pipeline stage shows that stage on its header',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'School construction tender',
        'description': 'Build a 12-classroom primary school',
        'sourceUrl': 'https://example.com/tender/3',
        'status': 'reviewing',
        'fitScorePercent': 90,
        'discoveredAt': now,
        'updatedAt': now,
        'pipelineStage': 'negotiation',
      });

      await _pumpScreen(tester, firestore);
      await tester.tap(find.text('School construction tender'));
      await tester.pumpAndSettle();

      // The 5 old per-opportunity nav actions (Classification/Pipeline/Match
      // Analysis/Strategic Review/Proposal) are gone — one button opens the
      // Opportunity Workspace instead, which shows the pipeline stage
      // directly on its header without any further navigation.
      await tester.tap(find.text(_strings.openWorkspaceButton));
      await tester.pumpAndSettle();

      // findsWidgets, not findsOneWidget: the stage renders both on the
      // workspace header and as the (collapsed, but always-visible)
      // Pipeline & Timeline section's subtitle badge.
      expect(
        find.text(
          _strings.pipelineStageLabel(OpportunityPipelineStage.negotiation),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('the Inbox AppBar icon opens the Opportunity Inbox', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.tap(find.byTooltip(_strings.inboxTooltip));
    await tester.pumpAndSettle();

    expect(find.text(_strings.inboxTitle), findsOneWidget);
  });

  testWidgets('the Sources AppBar icon opens Discovery Sources', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.tap(find.byTooltip(_strings.discoverySourcesTooltip));
    await tester.pumpAndSettle();

    expect(find.text(_strings.discoverySourcesTitle), findsOneWidget);
  });

  testWidgets(
    'shows an "Open source dashboard" button linking to the TenderSource\'s '
    'real website when the opportunity has a tenderSourceId — this is the '
    'guaranteed-real link, independent of whether the AI-suggested '
    'sourceUrl was verified',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      final sourceDoc = await firestore.collection('tenderSources').add({
        'name': 'US Embassy Nairobi — Commercial Opportunities',
        'organization': 'U.S. Embassy Nairobi',
        'category': 'governmentAgency',
        'discoveryMethod': 'api',
        'website': 'https://ke.usembassy.gov/tag/commercial-opportunities/',
        'status': 'active',
        'enabled': true,
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('opportunities').add({
        'title': 'Roof replacement at Rosslyn compound',
        'description': 'Construction services for roof replacement',
        'sourceUrl':
            'https://ke.usembassy.gov/embassy-of-the-united-states-of-america-nairobi-kenya-pr16154577-construction-services-for-the-roof-replacement-at-rosslyn-lonetree-compound-house-number-514/',
        'sourceUrlVerified': false,
        'status': 'discovered',
        'fitScorePercent': 80,
        'discoveredAt': now,
        'updatedAt': now,
        'tenderSourceId': sourceDoc.id,
      });

      await _pumpScreen(tester, firestore);
      await tester.tap(find.text('Roof replacement at Rosslyn compound'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.openSourceDashboardButton), findsOneWidget);
      // The unreliable AI-guessed deep link is still shown too, as a
      // secondary option — just no longer the only way to reach the source.
      expect(find.text(_strings.openSourceButton), findsOneWidget);
    },
  );

  testWidgets(
    'does not show an "Open source dashboard" button when the opportunity '
    'has no tenderSourceId (e.g. a manually-added opportunity)',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'Manually added tender',
        'description': 'Added by hand, no tender source',
        'sourceUrl': 'https://example.com/tender/manual',
        'status': 'discovered',
        'fitScorePercent': 60,
        'discoveredAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);
      await tester.tap(find.text('Manually added tender'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.openSourceDashboardButton), findsNothing);
    },
  );

  testWidgets('shows the fallback badge when sourceUrlIsFallback is true — the '
      'grounding cross-check rejected the AI-suggested URL and this points '
      'at the TenderSource\'s website instead of a tender-specific page', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 1, 1);
    await firestore.collection('opportunities').add({
      'title': 'Fallback tender',
      'description': 'Grounding cross-check rejected the suggested URL',
      'sourceUrl': 'https://example.gov',
      'sourceUrlVerified': false,
      'sourceUrlIsFallback': true,
      'status': 'discovered',
      'fitScorePercent': 60,
      'discoveredAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore);
    await tester.tap(find.text('Fallback tender'));
    await tester.pumpAndSettle();

    expect(find.text(_strings.sourceUrlFallbackBadgeLabel), findsOneWidget);
  });

  testWidgets(
    'does not show the fallback badge for an ordinary unverified opportunity',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'Ordinary unverified tender',
        'description': 'Just unverified, not a fallback',
        'sourceUrl': 'https://example.com/tender/unverified',
        'sourceUrlVerified': false,
        'status': 'discovered',
        'fitScorePercent': 60,
        'discoveredAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);
      await tester.tap(find.text('Ordinary unverified tender'));
      await tester.pumpAndSettle();

      expect(find.text(_strings.sourceUrlFallbackBadgeLabel), findsNothing);
    },
  );

  testWidgets(
    'the Evaluation tab shows only opportunities in the evaluation pipeline stage',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'KTDA ICT infrastructure tender',
        'description': 'Upgrade of core network infrastructure',
        'sourceUrl': 'https://example.com/tender/ktda-1',
        'status': 'reviewing',
        'fitScorePercent': 80,
        'discoveredAt': now,
        'updatedAt': now,
        'pipelineStage': 'evaluation',
        'procuringOrganization': 'KTDA',
        'tenderReferenceNumber': 'KTDA/ICT/2026/014',
      });
      await firestore.collection('opportunities').add({
        'title': 'Road rehabilitation tender',
        'description': 'Rehabilitate 40km of rural road',
        'sourceUrl': 'https://example.com/tender/road-1',
        'status': 'discovered',
        'fitScorePercent': 85,
        'discoveredAt': now,
        'updatedAt': now,
        'pipelineStage': 'discovered',
      });

      await _pumpScreen(tester, firestore);

      await tester.tap(find.widgetWithText(Tab, _strings.evaluationTabLabel));
      await tester.pumpAndSettle();

      expect(find.text('KTDA ICT infrastructure tender'), findsOneWidget);
      expect(find.text('Road rehabilitation tender'), findsNothing);
    },
  );

  testWidgets(
    'the Evaluation tab shows the empty state when nothing is under evaluation',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      await firestore.collection('opportunities').add({
        'title': 'Road rehabilitation tender',
        'description': 'Rehabilitate 40km of rural road',
        'sourceUrl': 'https://example.com/tender/road-1',
        'status': 'discovered',
        'fitScorePercent': 85,
        'discoveredAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);

      await tester.tap(find.widgetWithText(Tab, _strings.evaluationTabLabel));
      await tester.pumpAndSettle();

      expect(
        find.text(_strings.noOpportunitiesUnderEvaluation),
        findsOneWidget,
      );
    },
  );
}
