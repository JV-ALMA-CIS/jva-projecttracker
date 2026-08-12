import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late OpportunityEventService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = OpportunityEventService(firestore: firestore);
  });

  OpportunityEvent buildEvent({
    required String opportunityId,
    required DateTime createdAt,
    OpportunityPipelineStage stage = OpportunityPipelineStage.qualified,
  }) {
    return OpportunityEvent(
      id: '',
      opportunityId: opportunityId,
      stage: stage,
      title: 'Stage changed to ${stage.label}',
      createdAt: createdAt,
    );
  }

  test('create writes an event that watchByOpportunity then returns', () async {
    await service.create(
      buildEvent(
        opportunityId: 'opportunity-1',
        createdAt: DateTime.utc(2024, 8, 1),
      ),
    );

    final events = await service.watchByOpportunity('opportunity-1').first;
    expect(events, hasLength(1));
    expect(events.single.opportunityId, 'opportunity-1');
    expect(events.single.stage, OpportunityPipelineStage.qualified);
  });

  test(
    'watchByOpportunity only returns events for the requested opportunity',
    () async {
      await service.create(
        buildEvent(
          opportunityId: 'opportunity-1',
          createdAt: DateTime.utc(2024, 8, 1),
        ),
      );
      await service.create(
        buildEvent(
          opportunityId: 'opportunity-2',
          createdAt: DateTime.utc(2024, 8, 1),
        ),
      );

      final events = await service.watchByOpportunity('opportunity-1').first;
      expect(events, hasLength(1));
      expect(events.single.opportunityId, 'opportunity-1');
    },
  );

  test('watchByOpportunity orders events most-recent-first', () async {
    await service.create(
      buildEvent(
        opportunityId: 'opportunity-1',
        createdAt: DateTime.utc(2024, 1, 1),
        stage: OpportunityPipelineStage.discovered,
      ),
    );
    await service.create(
      buildEvent(
        opportunityId: 'opportunity-1',
        createdAt: DateTime.utc(2024, 6, 1),
        stage: OpportunityPipelineStage.qualified,
      ),
    );

    final events = await service.watchByOpportunity('opportunity-1').first;
    expect(events.map((e) => e.stage), [
      OpportunityPipelineStage.qualified,
      OpportunityPipelineStage.discovered,
    ]);
  });
}
