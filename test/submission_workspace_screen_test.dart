import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/proposal_section_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/submission_review_service.dart';
import 'package:jva_projecttracker/services/submission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

const _kRequiredCategories = [
  'companyRegistration',
  'taxCertificate',
  'license',
  'insurance',
  'financialStatement',
];

Future<String> _seedOpportunity(FakeFirebaseFirestore firestore) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'discovered',
    'pipelineStage': 'proposalStarted',
    'fitScorePercent': 70,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<String> _seedProposal(
  FakeFirebaseFirestore firestore,
  String opportunityId, {
  bool allApproved = false,
  bool sectionsApproved = false,
}) async {
  final now = DateTime.utc(2024, 8, 1);
  final doc = await firestore.collection('proposals').add({
    'opportunityId': opportunityId,
    'title': 'Proposal for Rural water tender',
    'status': 'draft',
    'assignedTo': 'jane@example.com',
    'approvals': allApproved
        ? [
            for (final role in ApprovalRole.values)
              {
                'role': role.name,
                'decision': 'approved',
                'approverName': 'Someone',
              },
          ]
        : const [],
    'createdAt': now,
    'updatedAt': now,
  });

  await firestore.collection('proposalSections').add({
    'proposalId': doc.id,
    'order': 0,
    'type': 'executiveSummary',
    'title': 'Executive Summary',
    'content': 'Some content',
    'status': sectionsApproved ? 'approved' : 'notStarted',
    'createdAt': now,
    'updatedAt': now,
  });

  return doc.id;
}

Future<void> _seedRequiredDocuments(
  FakeFirebaseFirestore firestore,
  String proposalId,
) async {
  final now = DateTime.utc(2024, 1, 1);
  for (final category in _kRequiredCategories) {
    await firestore.collection('documents').add({
      'title': '$category document',
      'category': category,
      'status': 'active',
      'relatedProposalIds': [proposalId],
      'createdAt': now,
      'updatedAt': now,
    });
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String opportunityId, {
  Future<Map<String, dynamic>?> Function({required String proposalId})?
  reviewOverride,
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
        libraryDocumentServiceProvider.overrideWithValue(
          LibraryDocumentService(firestore: firestore),
        ),
        submissionServiceProvider.overrideWithValue(
          SubmissionService(firestore: firestore),
        ),
        submissionReviewServiceProvider.overrideWithValue(
          SubmissionReviewService(
            // The real Cloud Function both writes the proposal document and
            // returns the same data — this override does both, so the fake
            // Firestore stream the screen actually reads from picks up the
            // change (the returned map alone is not applied to the UI).
            invokeOverride:
                reviewOverride ??
                ({required proposalId}) async {
                  final data = {
                    'submissionReviewReadiness': 'ready',
                    'submissionReviewRiskLevel': 'low',
                    'submissionReviewStrongSections': [
                      'Executive Summary: clear and concise',
                    ],
                    'submissionReviewedAt': DateTime.utc(2024, 8, 2),
                    'updatedAt': DateTime.utc(2024, 8, 2),
                  };
                  await firestore
                      .collection('proposals')
                      .doc(proposalId)
                      .update(data);
                  return {
                    'overallReadiness': 'ready',
                    'riskLevel': 'low',
                    'strongSections': ['Executive Summary: clear and concise'],
                  };
                },
          ),
        ),
      ],
      child: MaterialApp(
        home: SubmissionWorkspaceScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the blocked banner when the proposal is not submittable', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final opportunityId = await _seedOpportunity(firestore);
    await _seedProposal(firestore, opportunityId);

    await _pumpScreen(tester, firestore, opportunityId);

    await tester.scrollUntilVisible(
      find.text(_strings.validationBlockedBannerMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_strings.validationBlockedBannerMessage), findsOneWidget);
    expect(find.text(_strings.validationAllClearMessage), findsNothing);
  });

  testWidgets(
    'shows the all-clear message and enables Submit once every check passes',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final opportunityId = await _seedOpportunity(firestore);
      final proposalId = await _seedProposal(
        firestore,
        opportunityId,
        allApproved: true,
        sectionsApproved: true,
      );
      await _seedRequiredDocuments(firestore, proposalId);

      await _pumpScreen(tester, firestore, opportunityId);

      await tester.scrollUntilVisible(
        find.text(_strings.validationAllClearMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.validationAllClearMessage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(_strings.submitProposalButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, _strings.submitProposalButton),
      );
      expect(submitButton.onPressed, isNotNull);
    },
  );

  testWidgets('recording an approval persists and updates the approval card', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final opportunityId = await _seedOpportunity(firestore);
    await _seedProposal(firestore, opportunityId);

    await _pumpScreen(tester, firestore, opportunityId);

    await tester.scrollUntilVisible(
      find.text(_strings.approvalRoleLabel(ApprovalRole.legal)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(_strings.approvalRoleLabel(ApprovalRole.legal)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, _strings.fieldApproverName),
      'Jane Legal',
    );
    await tester.tap(find.text(_strings.approveButton));
    await tester.pumpAndSettle();

    final proposals = await firestore.collection('proposals').get();
    final approvals = proposals.docs.single.data()['approvals'] as List;
    expect(approvals, hasLength(1));
    expect(approvals.single['role'], 'legal');
    expect(approvals.single['decision'], 'approved');
    expect(approvals.single['approverName'], 'Jane Legal');
  });

  testWidgets(
    'submitting finalizes the proposal, transitions the opportunity, and creates a Submission',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final opportunityId = await _seedOpportunity(firestore);
      final proposalId = await _seedProposal(
        firestore,
        opportunityId,
        allApproved: true,
        sectionsApproved: true,
      );
      await _seedRequiredDocuments(firestore, proposalId);

      await _pumpScreen(tester, firestore, opportunityId);

      await tester.scrollUntilVisible(
        find.text(_strings.submitProposalButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_strings.submitProposalButton),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.confirmButton));
      await tester.pumpAndSettle();

      final proposalDoc = await firestore
          .collection('proposals')
          .doc(proposalId)
          .get();
      expect(proposalDoc.data()!['status'], 'finalized');

      final opportunityDoc = await firestore
          .collection('opportunities')
          .doc(opportunityId)
          .get();
      expect(opportunityDoc.data()!['pipelineStage'], 'submitted');

      final submissions = await firestore.collection('submissions').get();
      expect(submissions.docs, hasLength(1));
      expect(submissions.docs.single.data()['opportunityId'], opportunityId);
      expect(submissions.docs.single.data()['proposalId'], proposalId);
    },
  );

  testWidgets(
    'the Submit button is disabled while validation checks are blocked',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final opportunityId = await _seedOpportunity(firestore);
      await _seedProposal(firestore, opportunityId);

      await _pumpScreen(tester, firestore, opportunityId);

      await tester.scrollUntilVisible(
        find.text(_strings.submitProposalButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, _strings.submitProposalButton),
      );
      expect(submitButton.onPressed, isNull);
    },
  );

  testWidgets('running the AI review populates the panel', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final opportunityId = await _seedOpportunity(firestore);
    await _seedProposal(firestore, opportunityId);

    await _pumpScreen(tester, firestore, opportunityId);

    await tester.scrollUntilVisible(
      find.text(_strings.neverReviewedMessage),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(_strings.neverReviewedMessage), findsOneWidget);

    await tester.tap(
      find.text(_strings.runAiReviewButton),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        _strings.submissionReviewReadinessLabel(
          SubmissionReviewReadiness.ready,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Executive Summary: clear and concise'), findsOneWidget);
  });

  group('status transitions', () {
    Future<String> seedSubmission(
      FakeFirebaseFirestore firestore,
      String opportunityId,
      String proposalId, {
      String status = 'underEvaluation',
    }) async {
      final now = DateTime.utc(2024, 8, 3);
      final doc = await firestore.collection('submissions').add({
        'opportunityId': opportunityId,
        'proposalId': proposalId,
        'status': status,
        'createdAt': now,
        'updatedAt': now,
      });
      return doc.id;
    }

    testWidgets(
      'selecting Awarded updates the Submission and syncs the Opportunity pipeline stage',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final opportunityId = await _seedOpportunity(firestore);
        final proposalId = await _seedProposal(
          firestore,
          opportunityId,
          allApproved: true,
          sectionsApproved: true,
        );
        final submissionId = await seedSubmission(
          firestore,
          opportunityId,
          proposalId,
        );

        await _pumpScreen(tester, firestore, opportunityId);

        await tester.tap(find.byType(DropdownButton<SubmissionStatus>));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(_strings.submissionStatusLabel(SubmissionStatus.awarded))
              .last,
        );
        await tester.pumpAndSettle();

        final submissionDoc = await firestore
            .collection('submissions')
            .doc(submissionId)
            .get();
        expect(submissionDoc.data()!['status'], 'awarded');

        final opportunityDoc = await firestore
            .collection('opportunities')
            .doc(opportunityId)
            .get();
        expect(opportunityDoc.data()!['pipelineStage'], 'awarded');
      },
    );

    testWidgets(
      'a closed submission shows a read-only chip instead of a dropdown',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final opportunityId = await _seedOpportunity(firestore);
        final proposalId = await _seedProposal(
          firestore,
          opportunityId,
          allApproved: true,
          sectionsApproved: true,
        );
        await seedSubmission(
          firestore,
          opportunityId,
          proposalId,
          status: 'awarded',
        );

        await _pumpScreen(tester, firestore, opportunityId);

        expect(find.byType(DropdownButton<SubmissionStatus>), findsNothing);
        expect(
          find.text(_strings.submissionStatusLabel(SubmissionStatus.awarded)),
          findsWidgets,
        );
      },
    );
  });
}
