import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/opportunity_event.dart';

void main() {
  test('OpportunityEvent round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 8, 1, 10, 30);

    final event = OpportunityEvent(
      id: 'event-1',
      opportunityId: 'opportunity-1',
      stage: OpportunityPipelineStage.qualified,
      title: 'Stage changed to Qualified',
      description: 'Confirmed budget and timeline with client',
      createdAt: createdAt,
      createdBy: 'jane@example.com',
      metadata: const {'fromStage': 'reviewed', 'toStage': 'qualified'},
    );

    final map = event.toMap();
    final restored = OpportunityEvent.fromMap(event.id, map);

    expect(restored.opportunityId, event.opportunityId);
    expect(restored.stage, OpportunityPipelineStage.qualified);
    expect(restored.title, event.title);
    expect(restored.description, event.description);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.createdBy, event.createdBy);
    expect(restored.metadata, event.metadata);
  });

  test('OpportunityEvent defaults missing optional fields', () {
    final now = DateTime.utc(2024, 8, 1);
    final restored = OpportunityEvent.fromMap('event-2', {
      'opportunityId': 'opportunity-2',
      'stage': 'discovered',
      'title': 'Stage changed to Discovered',
      'createdAt': Timestamp.fromDate(now),
    });

    expect(restored.stage, OpportunityPipelineStage.discovered);
    expect(restored.description, isEmpty);
    expect(restored.createdBy, isNull);
    expect(restored.metadata, isEmpty);
  });
}
