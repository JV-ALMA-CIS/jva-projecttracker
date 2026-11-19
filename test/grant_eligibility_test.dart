import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/opportunities/inbox_view.dart';

final DateTime _now = DateTime.utc(2026, 11, 19, 9);

Opportunity _grant(
  String id, {
  GrantEligibility? eligibility,
  DateTime? deadline,
  int score = 0,
  OpportunityKind kind = OpportunityKind.grant,
}) => Opportunity(
  id: id,
  title: 'Grant $id',
  description: '',
  sourceUrl: 'https://example.com/$id',
  status: OpportunityStatus.discovered,
  fitScorePercent: score,
  deadline: deadline,
  discoveredAt: _now,
  updatedAt: _now,
  kind: kind,
  eligibility: eligibility,
);

void main() {
  test('reads eligibility, amount and note from the stored document', () {
    final Opportunity o = Opportunity.fromMap('g1', {
      'title': 'GSMA Innovation Fund',
      'description': '',
      'sourceUrl': 'https://example.com',
      'status': 'discovered',
      'kind': 'grant',
      'fitScorePercent': 0,
      'eligibility': 'needsPartner',
      'eligibilityNote': ' Needs an EU consortium ',
      'fundingAmount': '£100,000–£250,000',
      'matchFunding': '',
    });
    expect(o.eligibility, GrantEligibility.needsPartner);
    expect(o.eligibilityNote, 'Needs an EU consortium');
    expect(o.fundingAmount, '£100,000–£250,000');
    expect(o.matchFunding, isNull);
  });

  test('unknown or missing eligibility reads as not checked', () {
    final Map<String, dynamic> base = {
      'title': 't',
      'description': '',
      'sourceUrl': 'https://example.com',
      'status': 'discovered',
      'fitScorePercent': 0,
    };
    expect(Opportunity.fromMap('a', base).eligibility, isNull);
    expect(
      Opportunity.fromMap('b', {...base, 'eligibility': 'maybe'}).eligibility,
      isNull,
    );
  });

  test('eligibility is never written back by the app', () {
    final Map<String, dynamic> map = _grant(
      'g',
      eligibility: GrantEligibility.eligible,
    ).toMap();
    expect(map.containsKey('eligibility'), isFalse);
    expect(map.containsKey('fundingAmount'), isFalse);
  });

  test(
    'Grants tab: can-apply first, then needs-partner, not-eligible last; soonest deadline first, rolling last',
    () {
      final List<Opportunity> inbox = [
        _grant(
          'not-eligible-soon',
          eligibility: GrantEligibility.notEligible,
          deadline: _now.add(const Duration(days: 2)),
        ),
        _grant('rolling', eligibility: GrantEligibility.eligible),
        _grant(
          'partner',
          eligibility: GrantEligibility.needsPartner,
          deadline: _now.add(const Duration(days: 5)),
          score: 95,
        ),
        _grant(
          'eligible-later',
          eligibility: GrantEligibility.eligible,
          deadline: _now.add(const Duration(days: 40)),
        ),
        _grant('unchecked-soon', deadline: _now.add(const Duration(days: 3))),
      ];
      expect(
        inboxSlice(
          inbox,
          kind: OpportunityKind.grant,
        ).map((o) => o.id).toList(),
        [
          'unchecked-soon',
          'eligible-later',
          'rolling',
          'partner',
          'not-eligible-soon',
        ],
      );
    },
  );

  test('Tenders tab keeps best-match-first order', () {
    final List<Opportunity> inbox = [
      _grant('low', kind: OpportunityKind.tender, score: 40),
      _grant('high', kind: OpportunityKind.tender, score: 90),
    ];
    inbox.sort(compareForInbox);
    expect(
      inboxSlice(inbox, kind: OpportunityKind.tender).map((o) => o.id).toList(),
      ['high', 'low'],
    );
  });

  test(
    'Inbox sets aside needs-partner, not-eligible and weak matches only',
    () {
      expect(
        inboxSetAsideReason(
          _grant('a', eligibility: GrantEligibility.needsPartner, score: 90),
        ),
        InboxSetAside.needsPartner,
      );
      expect(
        inboxSetAsideReason(
          _grant('b', eligibility: GrantEligibility.notEligible, score: 90),
        ),
        InboxSetAside.notEligible,
      );
      expect(
        inboxSetAsideReason(
          _grant('c', score: 20, kind: OpportunityKind.tender),
        ),
        InboxSetAside.weakMatch,
      );
      expect(
        inboxSetAsideReason(
          _grant('d', eligibility: GrantEligibility.eligible),
        ),
        isNull,
        reason: 'unscored watchlist calls are not weak',
      );
      expect(
        inboxSetAsideReason(
          _grant('e', score: 75, kind: OpportunityKind.tender),
        ),
        isNull,
      );
    },
  );
}
