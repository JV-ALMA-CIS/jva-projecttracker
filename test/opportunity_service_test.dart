import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late OpportunityService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = OpportunityService(firestore: firestore);
  });

  Future<String> seedOpportunity() {
    final now = DateTime.utc(2024, 6, 1);
    return firestore
        .collection('opportunities')
        .add({
          'title': 'Rural water tender',
          'description': 'Design and build rural water network',
          'sourceUrl': 'https://example.com/tender/1',
          'status': 'discovered',
          'fitScorePercent': 70,
          'discoveredAt': now,
          'updatedAt': now,
        })
        .then((doc) => doc.id);
  }

  test('watchById returns null for a document that does not exist', () async {
    final result = await service.watchById('missing').first;
    expect(result, isNull);
  });

  test(
    'watchById returns a legacy (pre-3.1) document with defaulted classification fields',
    () async {
      final id = await seedOpportunity();

      final opportunity = await service.watchById(id).first;

      expect(opportunity, isNotNull);
      expect(
        opportunity!.classificationStatus,
        ClassificationStatus.notClassified,
      );
      expect(opportunity.priority, isNull);
      expect(opportunity.riskLevel, isNull);
      expect(opportunity.confidenceScore, isNull);
    },
  );

  test(
    'update() writes classification fields and relationships without touching unrelated fields',
    () async {
      final id = await seedOpportunity();
      final loaded = await service.watchById(id).first;

      await service.update(
        loaded!.copyWithForTest(
          classificationStatus: ClassificationStatus.classified,
          classificationSummary: 'Matches water infrastructure profile',
          industryIds: const ['industry-1'],
          technologyIds: const ['tech-1'],
          confidenceScore: 75,
          riskLevel: RiskLevel.low,
          priority: OpportunityPriority.high,
        ),
      );

      final updated = await service.watchById(id).first;
      expect(updated!.id, id);
      // Untouched fields survive the update.
      expect(updated.title, 'Rural water tender');
      expect(updated.fitScorePercent, 70);
      expect(updated.status, OpportunityStatus.discovered);
      // Classification fields were written.
      expect(updated.classificationStatus, ClassificationStatus.classified);
      expect(
        updated.classificationSummary,
        'Matches water infrastructure profile',
      );
      expect(updated.industryIds, ['industry-1']);
      expect(updated.technologyIds, ['tech-1']);
      expect(updated.confidenceScore, 75);
      expect(updated.riskLevel, RiskLevel.low);
      expect(updated.priority, OpportunityPriority.high);
    },
  );

  test('updateStatus only changes status and updatedAt', () async {
    final id = await seedOpportunity();

    await service.updateStatus(id, OpportunityStatus.won);

    final updated = await service.watchById(id).first;
    expect(updated!.status, OpportunityStatus.won);
    expect(updated.title, 'Rural water tender');
  });

  test('delete removes the document', () async {
    final id = await seedOpportunity();
    await service.delete(id);

    final result = await service.watchById(id).first;
    expect(result, isNull);
  });

  group('transitionStage', () {
    late OpportunityEventService eventService;

    setUp(() {
      eventService = OpportunityEventService(firestore: firestore);
    });

    test(
      'updates pipelineStage and lastStageUpdated on the opportunity',
      () async {
        final id = await seedOpportunity();

        await service.transitionStage(
          opportunityId: id,
          newStage: OpportunityPipelineStage.qualified,
          note: 'Budget confirmed',
          actor: 'jane@example.com',
        );

        final updated = await service.watchById(id).first;
        expect(updated!.pipelineStage, OpportunityPipelineStage.qualified);
        expect(updated.lastStageUpdated, isNotNull);
        // Untouched fields survive the transition.
        expect(updated.title, 'Rural water tender');
        expect(updated.fitScorePercent, 70);
      },
    );

    test(
      'creates a matching OpportunityEvent with fromStage/toStage metadata',
      () async {
        final id = await seedOpportunity();

        await service.transitionStage(
          opportunityId: id,
          newStage: OpportunityPipelineStage.qualified,
          note: 'Budget confirmed',
          actor: 'jane@example.com',
        );

        final events = await eventService.watchByOpportunity(id).first;
        expect(events, hasLength(1));
        final event = events.single;
        expect(event.opportunityId, id);
        expect(event.stage, OpportunityPipelineStage.qualified);
        expect(event.description, 'Budget confirmed');
        expect(event.createdBy, 'jane@example.com');
        expect(event.metadata['fromStage'], 'discovered');
        expect(event.metadata['toStage'], 'qualified');
      },
    );

    test(
      "a second transition uses the opportunity's current stage as fromStage",
      () async {
        final id = await seedOpportunity();

        await service.transitionStage(
          opportunityId: id,
          newStage: OpportunityPipelineStage.qualified,
        );
        await service.transitionStage(
          opportunityId: id,
          newStage: OpportunityPipelineStage.approved,
        );

        final events = await eventService.watchByOpportunity(id).first;
        expect(events, hasLength(2));
        // Two transitions issued back-to-back can land on the same
        // millisecond, so don't assume ordering here (that's covered by
        // OpportunityEventService's own "orders most-recent-first" test) —
        // just confirm each event recorded the right fromStage/toStage pair.
        final qualifiedEvent = events.singleWhere(
          (e) => e.stage == OpportunityPipelineStage.qualified,
        );
        final approvedEvent = events.singleWhere(
          (e) => e.stage == OpportunityPipelineStage.approved,
        );
        expect(qualifiedEvent.metadata['fromStage'], 'discovered');
        expect(approvedEvent.metadata['fromStage'], 'qualified');
      },
    );
  });

  group('recordStrategicDecision', () {
    test(
      'persists the human decision without touching executiveRecommendation',
      () async {
        final id = await seedOpportunity();
        await firestore.collection('opportunities').doc(id).update({
          'executiveRecommendation': 'doNotPursue',
        });

        await service.recordStrategicDecision(
          opportunityId: id,
          decision: StrategicReviewRecommendation.pursue,
          reason: 'Strategic client relationship outweighs the AI risk flag',
          decidedBy: 'jane@example.com',
        );

        final updated = await service.watchById(id).first;
        expect(updated!.humanDecision, StrategicReviewRecommendation.pursue);
        expect(
          updated.humanDecisionReason,
          'Strategic client relationship outweighs the AI risk flag',
        );
        expect(updated.humanDecisionBy, 'jane@example.com');
        expect(updated.humanDecisionAt, isNotNull);
        // The AI's own recommendation is preserved unchanged, even though
        // the human explicitly disagreed with it.
        expect(
          updated.executiveRecommendation,
          StrategicReviewRecommendation.doNotPursue,
        );
      },
    );

    test('a later decision overwrites only the decision fields', () async {
      final id = await seedOpportunity();

      await service.recordStrategicDecision(
        opportunityId: id,
        decision: StrategicReviewRecommendation.doNotPursue,
        decidedBy: 'jane@example.com',
      );
      await service.recordStrategicDecision(
        opportunityId: id,
        decision: StrategicReviewRecommendation.pursueWithCaution,
        reason: 'Revisited after client clarified scope',
        decidedBy: 'bob@example.com',
      );

      final updated = await service.watchById(id).first;
      expect(
        updated!.humanDecision,
        StrategicReviewRecommendation.pursueWithCaution,
      );
      expect(
        updated.humanDecisionReason,
        'Revisited after client clarified scope',
      );
      expect(updated.humanDecisionBy, 'bob@example.com');
      // Unrelated fields remain untouched.
      expect(updated.title, 'Rural water tender');
    });
  });

  group('deleteByTenderSourceId', () {
    Future<String> seedOpportunityFromSource(String? tenderSourceId) {
      final now = DateTime.utc(2024, 6, 1);
      return firestore
          .collection('opportunities')
          .add({
            'title': 'Tender from source',
            'description': '',
            'sourceUrl': 'https://example.com/tender/x',
            'status': 'discovered',
            'fitScorePercent': 50,
            'discoveredAt': now,
            'updatedAt': now,
            'tenderSourceId': tenderSourceId,
          })
          .then((doc) => doc.id);
    }

    test(
      'deletes only opportunities matching the given tenderSourceId',
      () async {
        final matchingA = await seedOpportunityFromSource('source-1');
        final matchingB = await seedOpportunityFromSource('source-1');
        final other = await seedOpportunityFromSource('source-2');
        final unrelated = await seedOpportunity();

        final deletedCount = await service.deleteByTenderSourceId('source-1');

        expect(deletedCount, 2);
        expect(await service.watchById(matchingA).first, isNull);
        expect(await service.watchById(matchingB).first, isNull);
        expect(await service.watchById(other).first, isNotNull);
        expect(await service.watchById(unrelated).first, isNotNull);
      },
    );

    test('returns 0 when no opportunity references the source', () async {
      await seedOpportunity();

      final deletedCount = await service.deleteByTenderSourceId(
        'no-such-source',
      );

      expect(deletedCount, 0);
    });
  });

  group('markSourceUrlVerified', () {
    test(
      'sets sourceUrlVerified to true and stamps sourceUrlVerifiedAt — the '
      'manual override for a real link the automated reachability check '
      'couldn\'t confirm (e.g. a site that blocks automated requests)',
      () async {
        final id = await seedOpportunity();
        final before = await service.watchById(id).first;
        expect(before!.sourceUrlVerified, isFalse);
        expect(before.sourceUrlVerifiedAt, isNull);

        await service.markSourceUrlVerified(id);

        final after = await service.watchById(id).first;
        expect(after!.sourceUrlVerified, isTrue);
        expect(after.sourceUrlVerifiedAt, isNotNull);
      },
    );

    test('does not touch unrelated fields', () async {
      final id = await seedOpportunity();

      await service.markSourceUrlVerified(id);

      final after = await service.watchById(id).first;
      expect(after!.title, 'Rural water tender');
      expect(after.sourceUrl, 'https://example.com/tender/1');
      expect(after.status, OpportunityStatus.discovered);
    });
  });
}

/// Test-only helper mirroring how [OpportunityClassificationScreen] rebuilds
/// a full [Opportunity] before calling [OpportunityService.update] — the
/// model itself has no copyWith (see Technology's test suite for the same
/// pattern/reasoning).
extension _OpportunityTestX on Opportunity {
  Opportunity copyWithForTest({
    ClassificationStatus? classificationStatus,
    String? classificationSummary,
    List<String>? industryIds,
    List<String>? technologyIds,
    int? confidenceScore,
    RiskLevel? riskLevel,
    OpportunityPriority? priority,
  }) => Opportunity(
    id: id,
    title: title,
    description: description,
    sourceUrl: sourceUrl,
    client: client,
    deadline: deadline,
    status: status,
    fitScorePercent: fitScorePercent,
    fitReasoning: fitReasoning,
    tags: tags,
    discoveredAt: discoveredAt,
    updatedAt: updatedAt,
    classificationStatus: classificationStatus ?? this.classificationStatus,
    classificationSummary: classificationSummary ?? this.classificationSummary,
    industryIds: industryIds ?? this.industryIds,
    technologyIds: technologyIds ?? this.technologyIds,
    businessUnitIds: businessUnitIds,
    productIds: productIds,
    serviceIds: serviceIds,
    capabilityIds: capabilityIds,
    experienceIds: experienceIds,
    knowledgeArticleIds: knowledgeArticleIds,
    opportunityType: opportunityType,
    estimatedBudget: estimatedBudget,
    estimatedDuration: estimatedDuration,
    estimatedComplexity: estimatedComplexity,
    confidenceScore: confidenceScore ?? this.confidenceScore,
    riskLevel: riskLevel ?? this.riskLevel,
    priority: priority ?? this.priority,
    aiReviewedAt: aiReviewedAt,
  );
}
