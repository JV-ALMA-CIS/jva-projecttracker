import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/services/opportunity_filters.dart';

Opportunity _opportunity({
  String id = 'opp-1',
  List<String> businessUnitIds = const [],
  double? estimatedBudget,
  DateTime? deadline,
  int fitScorePercent = 0,
  OpportunityPipelineStage pipelineStage = OpportunityPipelineStage.discovered,
  TenderSourceCategory? tenderSourceCategory,
  DiscoverySourceType? discoverySourceType,
  String title = 'Rural water tender',
  String? client,
  String sourceUrl = 'https://example.com/tender/1',
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Opportunity(
    id: id,
    title: title,
    description: '',
    sourceUrl: sourceUrl,
    client: client,
    deadline: deadline,
    discoveredAt: now,
    updatedAt: now,
    businessUnitIds: businessUnitIds,
    estimatedBudget: estimatedBudget,
    fitScorePercent: fitScorePercent,
    pipelineStage: pipelineStage,
    tenderSourceCategory: tenderSourceCategory,
    discoverySourceType: discoverySourceType,
  );
}

void main() {
  group('matchesBuFilter', () {
    test('all matches regardless of businessUnitIds', () {
      expect(
        matchesBuFilter(_opportunity(), const OpportunityBuFilter.all()),
        isTrue,
      );
      expect(
        matchesBuFilter(
          _opportunity(businessUnitIds: const ['bu-1']),
          const OpportunityBuFilter.all(),
        ),
        isTrue,
      );
    });

    test('unassigned matches only an empty businessUnitIds list', () {
      expect(
        matchesBuFilter(_opportunity(), const OpportunityBuFilter.unassigned()),
        isTrue,
      );
      expect(
        matchesBuFilter(
          _opportunity(businessUnitIds: const ['bu-1']),
          const OpportunityBuFilter.unassigned(),
        ),
        isFalse,
      );
    });

    test('specific matches only opportunities containing that BU id', () {
      final filter = OpportunityBuFilter.specific('bu-1');
      expect(
        matchesBuFilter(
          _opportunity(businessUnitIds: const ['bu-1', 'bu-2']),
          filter,
        ),
        isTrue,
      );
      expect(
        matchesBuFilter(_opportunity(businessUnitIds: const ['bu-2']), filter),
        isFalse,
      );
      expect(matchesBuFilter(_opportunity(), filter), isFalse);
    });
  });

  group('matchesValueBand', () {
    test('any matches everything including null', () {
      expect(matchesValueBand(null, ValueBand.any), isTrue);
      expect(matchesValueBand(500000, ValueBand.any), isTrue);
    });

    test('unknown matches only a null amount', () {
      expect(matchesValueBand(null, ValueBand.unknown), isTrue);
      expect(matchesValueBand(0, ValueBand.unknown), isFalse);
    });

    test('a null amount never matches a specific band', () {
      expect(matchesValueBand(null, ValueBand.under50k), isFalse);
      expect(matchesValueBand(null, ValueBand.from50kTo250k), isFalse);
      expect(matchesValueBand(null, ValueBand.from250kTo1m), isFalse);
      expect(matchesValueBand(null, ValueBand.over1m), isFalse);
    });

    test('bands are correctly bounded', () {
      expect(matchesValueBand(49999, ValueBand.under50k), isTrue);
      expect(matchesValueBand(50000, ValueBand.under50k), isFalse);
      expect(matchesValueBand(50000, ValueBand.from50kTo250k), isTrue);
      expect(matchesValueBand(249999, ValueBand.from50kTo250k), isTrue);
      expect(matchesValueBand(250000, ValueBand.from50kTo250k), isFalse);
      expect(matchesValueBand(250000, ValueBand.from250kTo1m), isTrue);
      expect(matchesValueBand(999999, ValueBand.from250kTo1m), isTrue);
      expect(matchesValueBand(1000000, ValueBand.from250kTo1m), isFalse);
      expect(matchesValueBand(1000000, ValueBand.over1m), isTrue);
    });
  });

  group('matchesDeadlineWindow', () {
    final now = DateTime.utc(2024, 6, 15);

    test('any matches everything including a null deadline', () {
      expect(matchesDeadlineWindow(null, DeadlineWindow.any, now: now), isTrue);
    });

    test('noDeadline matches only a null deadline', () {
      expect(
        matchesDeadlineWindow(null, DeadlineWindow.noDeadline, now: now),
        isTrue,
      );
      expect(
        matchesDeadlineWindow(now, DeadlineWindow.noDeadline, now: now),
        isFalse,
      );
    });

    test('a null deadline never matches a specific window', () {
      expect(
        matchesDeadlineWindow(null, DeadlineWindow.overdue, now: now),
        isFalse,
      );
      expect(
        matchesDeadlineWindow(null, DeadlineWindow.within7Days, now: now),
        isFalse,
      );
    });

    test('overdue matches a deadline strictly before now', () {
      expect(
        matchesDeadlineWindow(
          now.subtract(const Duration(days: 1)),
          DeadlineWindow.overdue,
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesDeadlineWindow(now, DeadlineWindow.overdue, now: now),
        isFalse,
      );
    });

    test('within7Days matches [now, now+7d)', () {
      expect(
        matchesDeadlineWindow(now, DeadlineWindow.within7Days, now: now),
        isTrue,
      );
      expect(
        matchesDeadlineWindow(
          now.add(const Duration(days: 6)),
          DeadlineWindow.within7Days,
          now: now,
        ),
        isTrue,
      );
      expect(
        matchesDeadlineWindow(
          now.add(const Duration(days: 7)),
          DeadlineWindow.within7Days,
          now: now,
        ),
        isFalse,
      );
      expect(
        matchesDeadlineWindow(
          now.subtract(const Duration(days: 1)),
          DeadlineWindow.within7Days,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('matchesFitScoreThreshold', () {
    test('any matches every score', () {
      expect(matchesFitScoreThreshold(0, FitScoreThreshold.any), isTrue);
    });

    test('thresholds are inclusive lower bounds', () {
      expect(matchesFitScoreThreshold(50, FitScoreThreshold.at50), isTrue);
      expect(matchesFitScoreThreshold(49, FitScoreThreshold.at50), isFalse);
      expect(matchesFitScoreThreshold(70, FitScoreThreshold.at70), isTrue);
      expect(matchesFitScoreThreshold(69, FitScoreThreshold.at70), isFalse);
      expect(matchesFitScoreThreshold(85, FitScoreThreshold.at85), isTrue);
      expect(matchesFitScoreThreshold(84, FitScoreThreshold.at85), isFalse);
    });
  });

  group('buyerTypeFacetFor / matchesBuyerTypeFacet', () {
    test('tenderSourceCategory wins when both fields are set', () {
      final opp = _opportunity(
        tenderSourceCategory: TenderSourceCategory.ngo,
        discoverySourceType: DiscoverySourceType.governmentProcurement,
      );
      expect(buyerTypeFacetFor(opp), BuyerTypeFacet.ngo);
    });

    test(
      'falls back to discoverySourceType when tenderSourceCategory is null',
      () {
        final opp = _opportunity(
          discoverySourceType: DiscoverySourceType.unProcurement,
        );
        expect(buyerTypeFacetFor(opp), BuyerTypeFacet.unAgency);
      },
    );

    test('is unknown when neither field is set', () {
      expect(buyerTypeFacetFor(_opportunity()), BuyerTypeFacet.unknown);
    });

    test('government/countyGovernment both map to government', () {
      expect(
        buyerTypeFacetFor(
          _opportunity(
            tenderSourceCategory: TenderSourceCategory.governmentAgency,
          ),
        ),
        BuyerTypeFacet.government,
      );
      expect(
        buyerTypeFacetFor(
          _opportunity(
            tenderSourceCategory: TenderSourceCategory.countyGovernment,
          ),
        ),
        BuyerTypeFacet.government,
      );
    });

    test('any matches regardless of classification', () {
      expect(matchesBuyerTypeFacet(_opportunity(), BuyerTypeFacet.any), isTrue);
    });

    test('a specific facet only matches its own classification', () {
      final opp = _opportunity(tenderSourceCategory: TenderSourceCategory.ngo);
      expect(matchesBuyerTypeFacet(opp, BuyerTypeFacet.ngo), isTrue);
      expect(matchesBuyerTypeFacet(opp, BuyerTypeFacet.government), isFalse);
    });
  });

  group('matchesSearchQuery', () {
    test('empty query always matches', () {
      expect(matchesSearchQuery(_opportunity(), ''), isTrue);
      expect(matchesSearchQuery(_opportunity(), '   '), isTrue);
    });

    test('matches title case-insensitively', () {
      expect(
        matchesSearchQuery(_opportunity(title: 'Rural Water Tender'), 'water'),
        isTrue,
      );
    });

    test('matches client', () {
      expect(
        matchesSearchQuery(
          _opportunity(client: 'Ministry of Water'),
          'ministry',
        ),
        isTrue,
      );
    });

    test('does not match unrelated text', () {
      expect(
        matchesSearchQuery(_opportunity(title: 'Rural water tender'), 'roads'),
        isFalse,
      );
    });
  });

  group('filterOpportunities', () {
    test('composes BU + facet filters + search', () {
      final now = DateTime.utc(2024, 6, 15);
      final matching = _opportunity(
        id: 'match',
        businessUnitIds: const ['bu-1'],
        estimatedBudget: 100000,
        fitScorePercent: 80,
        title: 'Rural water network',
      );
      final wrongBu = _opportunity(
        id: 'wrong-bu',
        businessUnitIds: const ['bu-2'],
        estimatedBudget: 100000,
        fitScorePercent: 80,
        title: 'Rural water network',
      );
      final wrongValue = _opportunity(
        id: 'wrong-value',
        businessUnitIds: const ['bu-1'],
        estimatedBudget: 5000000,
        fitScorePercent: 80,
        title: 'Rural water network',
      );

      final result = filterOpportunities(
        [matching, wrongBu, wrongValue],
        const OpportunityBuFilter.specific('bu-1'),
        const OpportunityFacetFilters(
          valueBand: ValueBand.from50kTo250k,
          fitScoreThreshold: FitScoreThreshold.at70,
          searchQuery: 'water',
        ),
        now: now,
      );

      expect(result.map((o) => o.id).toList(), ['match']);
    });

    test('an empty facet set with All BU returns everything', () {
      final now = DateTime.utc(2024, 6, 15);
      final a = _opportunity(id: 'a');
      final b = _opportunity(id: 'b', businessUnitIds: const ['bu-1']);

      final result = filterOpportunities(
        [a, b],
        const OpportunityBuFilter.all(),
        const OpportunityFacetFilters(),
        now: now,
      );

      expect(result.length, 2);
    });
  });
}
