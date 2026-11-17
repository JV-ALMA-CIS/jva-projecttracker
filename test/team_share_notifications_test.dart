import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/notification_item.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/team_share.dart';
import 'package:jva_projecttracker/services/notification_builder.dart';
import 'package:jva_projecttracker/services/team_share_service.dart';

TeamShare _share(String id, {String by = 'u2', String note = ''}) => TeamShare(
  id: id,
  opportunityId: 'opp-$id',
  opportunityTitle: 'Classroom renovation $id',
  kind: OpportunityKind.tender,
  sharedByUid: by,
  sharedByName: 'Jane',
  note: note,
  justAdded: false,
  createdAt: DateTime.utc(2026, 11, 17),
);

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);

  test('colleagues\' shares appear first in the Notifications list', () {
    final items = buildNotifications(
      activeRecommendations: const [],
      opportunities: const [],
      readIds: const {},
      now: now,
      teamShares: [_share('a', note: 'fits our school work')],
      currentUid: 'u1',
    );
    expect(items, hasLength(1));
    final item = items.first;
    expect(item.type, NotificationType.teamShare);
    expect(item.title, 'Classroom renovation a');
    expect(item.body, 'fits our school work');
    expect(item.sharedByName, 'Jane');
    expect(item.relatedOpportunityIds, ['opp-a']);
    expect(item.isRead, isFalse);
  });

  test('your own shares are not listed back to you', () {
    final items = buildNotifications(
      activeRecommendations: const [],
      opportunities: const [],
      readIds: const {},
      now: now,
      teamShares: [_share('mine', by: 'u1')],
      currentUid: 'u1',
    );
    expect(items, isEmpty);
  });

  test('a read share stays read', () {
    final items = buildNotifications(
      activeRecommendations: const [],
      opportunities: const [],
      readIds: const {'share:a'},
      now: now,
      teamShares: [_share('a')],
      currentUid: 'u1',
    );
    expect(items.single.isRead, isTrue);
  });

  test('share links open the opportunity in the web app', () {
    expect(
      opportunityShareLink('abc 123'),
      'https://jva-projecttracker.web.app/?opportunityId=abc+123',
    );
  });
}
