import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/screens/proposals/proposal_workspace_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/proposal_generation_service.dart';
import 'package:jva_projecttracker/services/submission_review_service.dart';
import 'package:jva_projecttracker/services/proposal_section_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/proposal_readiness.dart';
import 'package:jva_projecttracker/services/proposal_section_suggestions.dart';
import 'package:jva_projecttracker/widgets/proposal_section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

/// Disambiguates a section title from the same text also appearing as a
/// step label in `ProposalProgressTracker`, which mirrors the real
/// sections' titles above the section list.
Finder _sectionTitle(String title) => find.descendant(
  of: find.byType(ProposalSectionCard),
  matching: find.text(title),
);

Future<String> _seedOpportunity(
  FakeFirebaseFirestore firestore, {
  bool withStrategicReview = false,
}) async {
  final now = DateTime.utc(2024, 1, 1);
  final data = <String, dynamic>{
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'discovered',
    'pipelineStage': 'approved',
    'fitScorePercent': 70,
    'discoveredAt': now,
    'updatedAt': now,
  };
  if (withStrategicReview) {
    data.addAll({
      'strategicReviewedAt': now,
      'executiveRecommendation': 'pursue',
      'executiveSummary': 'Strong strategic fit, recommend pursuing.',
      'strategicStrengths': ['Deep water infrastructure experience'],
      'strategicWeaknesses': ['No local office in the region'],
      'missingRequirements': ['ISO 9001 certification'],
      'nextRecommendedActions': ['Schedule a scoping call with the client'],
    });
  }
  final doc = await firestore.collection('opportunities').add(data);
  return doc.id;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String opportunityId, {
  Future<Map<String, dynamic>?> Function({
    required String sectionId,
    required String mode,
  })?
  generationOverride,
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
        proposalServiceProvider.overrideWithValue(
          ProposalService(firestore: firestore),
        ),
        proposalSectionServiceProvider.overrideWithValue(
          ProposalSectionService(firestore: firestore),
        ),
        proposalGenerationServiceProvider.overrideWithValue(
          ProposalGenerationService(
            invokeOverride:
                generationOverride ??
                ({required sectionId, required mode}) async => {
                  'content': 'Generated content.',
                },
          ),
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
        libraryDocumentServiceProvider.overrideWithValue(
          LibraryDocumentService(firestore: firestore),
        ),
        submissionReviewServiceProvider.overrideWithValue(
          SubmissionReviewService(
            invokeOverride: ({required proposalId}) async => {
              'overallReadiness': 'ready',
            },
          ),
        ),
      ],
      child: MaterialApp(
        home: ProposalWorkspaceScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state before a proposal exists', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);

    await _pumpScreen(tester, firestore, id);

    expect(find.text(_strings.createProposalEmptyStateTitle), findsOneWidget);
    expect(find.text(_strings.createProposalButton), findsOneWidget);
  });

  testWidgets(
    'creating a proposal scaffolds the 13 standard sections and bumps the pipeline stage',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      await _pumpScreen(tester, firestore, id);

      await tester.tap(find.text(_strings.createProposalButton));
      await tester.pumpAndSettle();

      expect(find.text(_strings.createProposalEmptyStateTitle), findsNothing);
      expect(find.text(_strings.sectionsCompletedLabel(0, 13)), findsOneWidget);
      expect(find.text('Executive Summary'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Conclusion'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Conclusion'), findsOneWidget);

      final opportunityDoc = await firestore
          .collection('opportunities')
          .doc(id)
          .get();
      expect(opportunityDoc.data()!['pipelineStage'], 'proposalStarted');
    },
  );

  testWidgets('editing a section\'s content marks it edited', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);
    final now = DateTime.utc(2024, 8, 1);
    final proposalDoc = await firestore.collection('proposals').add({
      'opportunityId': id,
      'title': 'Proposal for Rural water tender',
      'status': 'draft',
      'createdAt': now,
      'updatedAt': now,
    });
    await firestore.collection('proposalSections').add({
      'proposalId': proposalDoc.id,
      'order': 0,
      'type': 'executiveSummary',
      'title': 'Executive Summary',
      'content': '',
      'status': 'notStarted',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, id);

    expect(find.text(_strings.sectionsCompletedLabel(0, 1)), findsOneWidget);

    await tester.scrollUntilVisible(
      _sectionTitle('Executive Summary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, _strings.sectionContentHint),
      'We propose a phased rollout.',
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.text(
        _strings.proposalSectionStatusLabel(ProposalSectionStatus.edited),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '"Mark ready for review" is enabled only once every section is approved',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      final proposalDoc = await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('proposalSections').add({
        'proposalId': proposalDoc.id,
        'order': 0,
        'type': 'executiveSummary',
        'title': 'Executive Summary',
        'content': 'Summary text.',
        'status': 'approved',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.sectionsCompletedLabel(1, 1)), findsOneWidget);

      await tester.tap(find.text(_strings.markReadyForReviewButton));
      await tester.pumpAndSettle();

      expect(
        find.text(_strings.proposalStatusLabel(ProposalStatus.readyForReview)),
        findsOneWidget,
      );
      expect(find.text(_strings.reopenForEditingButton), findsOneWidget);
    },
  );

  testWidgets('deleting a section asks for confirmation before removing it', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);
    final now = DateTime.utc(2024, 8, 1);
    final proposalDoc = await firestore.collection('proposals').add({
      'opportunityId': id,
      'title': 'Proposal for Rural water tender',
      'status': 'draft',
      'createdAt': now,
      'updatedAt': now,
    });
    await firestore.collection('proposalSections').add({
      'proposalId': proposalDoc.id,
      'order': 0,
      'type': 'executiveSummary',
      'title': 'Executive Summary',
      'content': '',
      'status': 'notStarted',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, id);

    await tester.scrollUntilVisible(
      _sectionTitle('Executive Summary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text(_strings.deleteSectionConfirmTitle), findsOneWidget);

    await tester.tap(find.text(_strings.confirmButton));
    await tester.pumpAndSettle();

    expect(find.text('Executive Summary'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(_strings.sectionsCompletedLabel(0, 0)),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_strings.sectionsCompletedLabel(0, 0)), findsOneWidget);
  });

  testWidgets('shows an onTrack readiness chip when there is no deadline', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);
    final now = DateTime.utc(2024, 8, 1);
    await firestore.collection('proposals').add({
      'opportunityId': id,
      'title': 'Proposal for Rural water tender',
      'status': 'draft',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, id);

    expect(
      find.text(_strings.proposalReadinessLabel(ProposalReadiness.onTrack)),
      findsOneWidget,
    );
  });

  testWidgets(
    'AI Summary prompts to run a strategic review when the opportunity has none',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text(_strings.noStrategicReviewForProposalPrompt),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(_strings.noStrategicReviewForProposalPrompt),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AI Summary surfaces the opportunity\'s strategic review when one exists',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore, withStrategicReview: true);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text(_strings.executiveSummaryLabel),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.executiveSummaryLabel), findsOneWidget);
      expect(
        find.text('Strong strategic fit, recommend pursuing.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Submission Readiness, Team Collaboration, Timeline and AI Assistant sections render',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text(_strings.aiAssistantPanelSectionTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(_strings.submissionReadinessSectionTitle),
        findsOneWidget,
      );
      expect(find.text(_strings.teamCollaborationSectionTitle), findsOneWidget);
      expect(find.text(_strings.proposalTimelineSectionTitle), findsOneWidget);
      expect(find.text(_strings.aiAssistantPanelSectionTitle), findsOneWidget);
    },
  );

  testWidgets(
    'Submission Readiness shows every required category as missing when no documents are linked',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        find.text(_strings.submissionReadinessSectionTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_strings.submissionReadinessSectionTitle),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text(_strings.submissionNotReadyLabel), findsOneWidget);
      expect(
        find.text(_strings.requiredDocumentsCountLabel(5)),
        findsOneWidget,
      );
      expect(
        find.text(_strings.uploadedDocumentsCountLabel(0)),
        findsOneWidget,
      );
      expect(find.text(_strings.missingDocumentsCountLabel(5)), findsOneWidget);
    },
  );

  testWidgets('assigning a proposal owner persists', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final id = await _seedOpportunity(firestore);
    final now = DateTime.utc(2024, 8, 1);
    final proposalDoc = await firestore.collection('proposals').add({
      'opportunityId': id,
      'title': 'Proposal for Rural water tender',
      'status': 'draft',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, id);

    await tester.scrollUntilVisible(
      find.text(_strings.teamCollaborationSectionTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(_strings.teamCollaborationSectionTitle),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(_strings.unassignedLabel),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_strings.unassignedLabel), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'jane@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final updated = await firestore
        .collection('proposals')
        .doc(proposalDoc.id)
        .get();
    expect(updated.data()!['assignedTo'], 'jane@example.com');
  });

  testWidgets(
    'Submission Overview renders a blocker count and opens the Submission Workspace',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      expect(
        find.text(_strings.submissionOverviewSectionTitle),
        findsOneWidget,
      );
      // No sections, no linked documents, and no recorded approvals yet —
      // sectionsComplete, documentsAttached, and requiredSignatures all
      // block; metadataComplete is only a warning and budgetComplete is
      // not applicable (no pricing section), so neither counts.
      expect(find.text(_strings.blockersCountLabel(3)), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(_strings.openSubmissionWorkspaceButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_strings.openSubmissionWorkspaceButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text(_strings.submissionWorkspaceTitle), findsOneWidget);
    },
  );

  testWidgets(
    'the header shows a Submitted indicator once the proposal is finalized',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'finalized',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      expect(find.text(_strings.submittedStatusLabel), findsOneWidget);
      expect(find.text(_strings.markReadyForReviewButton), findsNothing);
      expect(find.text(_strings.reopenForEditingButton), findsNothing);
    },
  );

  testWidgets(
    'Generate with AI populates content and marks the section aiDrafted',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      final proposalDoc = await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('proposalSections').add({
        'proposalId': proposalDoc.id,
        'order': 0,
        'type': 'executiveSummary',
        'title': 'Executive Summary',
        'content': '',
        'status': 'notStarted',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(
        tester,
        firestore,
        id,
        // The real Cloud Function both writes the section document and
        // returns the same data — this override does both, so the fake
        // Firestore stream the screen actually reads from picks up the
        // change (the returned map alone is not applied to the UI).
        generationOverride: ({required sectionId, required mode}) async {
          await firestore.collection('proposalSections').doc(sectionId).update({
            'content': 'JV ALMA CIS proposes a phased approach.',
            'status': 'aiDrafted',
            'aiGeneratedAt': now,
            'updatedAt': now,
          });
          return {
            'content': 'JV ALMA CIS proposes a phased approach.',
            'confidenceScore': 80,
          };
        },
      );

      await tester.scrollUntilVisible(
        _sectionTitle('Executive Summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.generateWithAiButton));
      await tester.pumpAndSettle();

      expect(
        find.text('JV ALMA CIS proposes a phased approach.'),
        findsOneWidget,
      );
      expect(
        find.text(
          _strings.proposalSectionStatusLabel(ProposalSectionStatus.aiDrafted),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'regenerating an edited section shows a confirmation dialog before overwriting',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      final proposalDoc = await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('proposalSections').add({
        'proposalId': proposalDoc.id,
        'order': 0,
        'type': 'executiveSummary',
        'title': 'Executive Summary',
        'content': 'Human-written content.',
        'status': 'edited',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        _sectionTitle('Executive Summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.regenerateButton));
      await tester.pumpAndSettle();

      expect(find.text(_strings.overwriteConfirmTitle), findsOneWidget);

      await tester.tap(find.text(_strings.cancelButton));
      await tester.pumpAndSettle();

      expect(find.text('Human-written content.'), findsOneWidget);
    },
  );

  testWidgets(
    'restoring a previous version brings back the old content and status',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);
      final now = DateTime.utc(2024, 8, 1);
      final proposalDoc = await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('proposalSections').add({
        'proposalId': proposalDoc.id,
        'order': 0,
        'type': 'executiveSummary',
        'title': 'Executive Summary',
        'content': 'New AI content.',
        'status': 'aiDrafted',
        'previousContent': 'Old human content.',
        'previousStatus': 'edited',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        _sectionTitle('Executive Summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.restorePreviousVersionButton));
      await tester.pumpAndSettle();

      expect(find.text('Old human content.'), findsOneWidget);
      expect(
        find.text(
          _strings.proposalSectionStatusLabel(ProposalSectionStatus.edited),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows a suggestion chip for a technology the opportunity references but the section has not cited',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2024, 1, 1);
      final oppDoc = await firestore.collection('opportunities').add({
        'title': 'Rural water tender',
        'description': 'Design and build rural water network',
        'sourceUrl': 'https://example.com/tender/1',
        'status': 'discovered',
        'pipelineStage': 'approved',
        'fitScorePercent': 70,
        'discoveredAt': now,
        'updatedAt': now,
        'technologyIds': ['tech-1'],
      });
      final id = oppDoc.id;
      await firestore.collection('technologies').doc('tech-1').set({
        'name': 'Flutter',
        'slug': 'flutter',
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      });
      final proposalDoc = await firestore.collection('proposals').add({
        'opportunityId': id,
        'title': 'Proposal for Rural water tender',
        'status': 'draft',
        'createdAt': now,
        'updatedAt': now,
      });
      await firestore.collection('proposalSections').add({
        'proposalId': proposalDoc.id,
        'order': 0,
        'type': 'executiveSummary',
        'title': 'Executive Summary',
        'content': 'Generated content.',
        'status': 'aiDrafted',
        'aiGeneratedAt': now,
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, id);

      await tester.scrollUntilVisible(
        _sectionTitle('Executive Summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(_sectionTitle('Executive Summary'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.text(
          _strings.suggestionLabel(
            SuggestionCategory.missingTechnology,
            'Flutter',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
