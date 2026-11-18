import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/services/related_opportunity_triage.dart';

final _now = DateTime.utc(2026, 11, 18, 9);

Opportunity _opp(
  String id, {
  int score = 60,
  OpportunityStatus status = OpportunityStatus.discovered,
  DateTime? deadline,
}) => Opportunity(
  id: id,
  title: 'Opportunity $id',
  description: '',
  sourceUrl: 'https://example.com/$id',
  status: status,
  fitScorePercent: score,
  deadline: deadline,
  discoveredAt: _now,
  updatedAt: _now,
);

Recommendation _rec(
  List<String> ids, {
  RecommendationCategory category = RecommendationCategory.general,
}) => Recommendation.fromMap('rec', {
  'category': category.name,
  'priority': 'medium',
  'title': 'Rec',
  'reasoning': 'Because',
  'status': 'active',
  'relatedOpportunityIds': ids,
});

void main() {
  test('open + strong match (>= 70%) is worth a look', () {
    expect(
      relatedOpportunityState(_opp('a', score: 82), _rec(['a']), _now),
      RelatedOpportunityState.worthALook,
    );
  });

  test('open + weaker match is just open, unless the AI says fast-track', () {
    final weak = _opp('a', score: 55);
    expect(
      relatedOpportunityState(weak, _rec(['a']), _now),
      RelatedOpportunityState.open,
    );
    expect(
      relatedOpportunityState(
        weak,
        _rec(['a'], category: RecommendationCategory.priorityOpportunity),
        _now,
      ),
      RelatedOpportunityState.worthALook,
    );
  });

  test('closed, dismissed, archived or past deadline is reference only', () {
    final rec = _rec(['a']);
    for (final status in [
      OpportunityStatus.dismissed,
      OpportunityStatus.archived,
      OpportunityStatus.lost,
      OpportunityStatus.won,
    ]) {
      expect(
        relatedOpportunityState(
          _opp('a', score: 90, status: status),
          rec,
          _now,
        ),
        RelatedOpportunityState.reference,
        reason: status.name,
      );
    }
    expect(
      relatedOpportunityState(
        _opp('a', score: 90, deadline: _now.subtract(const Duration(days: 1))),
        rec,
        _now,
      ),
      RelatedOpportunityState.reference,
    );
  });

  test('an applied opportunity past its deadline is still open', () {
    expect(
      relatedOpportunityState(
        _opp(
          'a',
          status: OpportunityStatus.applied,
          deadline: _now.subtract(const Duration(days: 3)),
        ),
        _rec(['a']),
        _now,
      ),
      RelatedOpportunityState.open,
    );
  });

  test('triage orders worth-a-look, then open, then reference', () {
    final byId = {
      'ref': _opp('ref', status: OpportunityStatus.dismissed),
      'open': _opp('open', score: 50),
      'worth': _opp('worth', score: 88),
    };
    final triaged = triageRelatedOpportunities(
      _rec(['ref', 'open', 'worth', 'missing']),
      byId,
      _now,
    );
    expect(triaged.map((t) => t.opportunity.id), ['worth', 'open', 'ref']);
  });

  test('outdated only when every related opportunity has closed', () {
    final byId = {
      'closed': _opp('closed', status: OpportunityStatus.dismissed),
      'past': _opp('past', deadline: _now.subtract(const Duration(days: 2))),
      'live': _opp('live', score: 75),
    };
    expect(
      isOutdatedRecommendation(_rec(['closed', 'past']), byId, _now),
      isTrue,
    );
    expect(
      isOutdatedRecommendation(_rec(['closed', 'live']), byId, _now),
      isFalse,
    );
    expect(isOutdatedRecommendation(_rec([]), byId, _now), isFalse);
  });
}
