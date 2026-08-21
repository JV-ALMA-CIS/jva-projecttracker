import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/opportunity_explore.dart';

Opportunity _opportunity({
  String id = 'opp-1',
  String title = 'Rural water tender',
  String description = '',
  List<String> tags = const [],
  List<String> businessUnitIds = const [],
  List<OpportunityCertificationRequirement> requiredCertifications = const [],
  int fitScorePercent = 0,
  DateTime? deadline,
  OpportunityPipelineStage pipelineStage = OpportunityPipelineStage.discovered,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Opportunity(
    id: id,
    title: title,
    description: description,
    sourceUrl: 'https://example.com/tender/$id',
    tags: tags,
    discoveredAt: now,
    updatedAt: now,
    businessUnitIds: businessUnitIds,
    requiredCertifications: requiredCertifications,
    fitScorePercent: fitScorePercent,
    deadline: deadline,
    pipelineStage: pipelineStage,
  );
}

Certification _certification({
  String id = 'cert-1',
  CertificationType type = CertificationType.nca,
  String? gradeOrClass,
  CertificationStatus status = CertificationStatus.active,
  DateTime? expiryDate,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Certification(
    id: id,
    name: 'Test cert',
    type: type,
    gradeOrClass: gradeOrClass,
    status: status,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final now = DateTime.utc(2024, 6, 15);

  group('classifyExploreCertMatch', () {
    test('none when opportunity has no requiredCertifications', () {
      final opp = _opportunity();
      expect(
        classifyExploreCertMatch(opp, [_certification()], now: now),
        ExploreCertMatch.none,
      );
    });

    test('fullMatch when a held cert satisfies the requirement', () {
      final opp = _opportunity(
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
      );
      final held = [_certification(gradeOrClass: '7')];
      expect(
        classifyExploreCertMatch(opp, held, now: now),
        ExploreCertMatch.fullMatch,
      );
    });

    test(
      'typeMatchWithGap when the type matches but the grade does not clear the bar',
      () {
        final opp = _opportunity(
          requiredCertifications: [
            const OpportunityCertificationRequirement(
              type: CertificationType.nca,
              gradeOrClass: '7',
              label: 'NCA Class 7',
            ),
          ],
        );
        final held = [_certification(gradeOrClass: '5')];
        expect(
          classifyExploreCertMatch(opp, held, now: now),
          ExploreCertMatch.typeMatchWithGap,
        );
      },
    );

    test('none when no held certification shares a type', () {
      final opp = _opportunity(
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
      );
      final held = [_certification(type: CertificationType.iso)];
      expect(
        classifyExploreCertMatch(opp, held, now: now),
        ExploreCertMatch.none,
      );
    });

    test('an expired held certification never counts as a match', () {
      final opp = _opportunity(
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
      );
      final held = [
        _certification(gradeOrClass: '7', status: CertificationStatus.expired),
      ];
      expect(
        classifyExploreCertMatch(opp, held, now: now),
        ExploreCertMatch.none,
      );
    });
  });

  group('matchesExploreGrowthKeyword', () {
    test('matches a growth keyword in the title case-insensitively', () {
      final opp = _opportunity(title: 'Irrigation scheme upgrade');
      expect(matchesExploreGrowthKeyword(opp), isTrue);
    });

    test('matches a growth keyword in tags', () {
      final opp = _opportunity(title: 'Untitled', tags: const ['Pipeline']);
      expect(matchesExploreGrowthKeyword(opp), isTrue);
    });

    test('does not match unrelated text', () {
      final opp = _opportunity(title: 'Office stationery supply');
      expect(matchesExploreGrowthKeyword(opp), isFalse);
    });
  });

  group('isExploreCandidate', () {
    test(
      'cert-eligible opportunity qualifies even with no BU tags (thin Experience)',
      () {
        final opp = _opportunity(
          requiredCertifications: [
            const OpportunityCertificationRequirement(
              type: CertificationType.nca,
              gradeOrClass: '5',
              label: 'NCA Class 5',
            ),
          ],
        );
        final held = [_certification(gradeOrClass: '7')];
        expect(isExploreCandidate(opp, held, now: now), isTrue);
      },
    );

    test('grade gap still qualifies for Explore (warning, not hidden)', () {
      final opp = _opportunity(
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '7',
            label: 'NCA Class 7',
          ),
        ],
      );
      final held = [_certification(gradeOrClass: '5')];
      expect(isExploreCandidate(opp, held, now: now), isTrue);
    });

    test('growth-keyword opportunity qualifies with no certs at all', () {
      final opp = _opportunity(title: 'Irrigation scheme upgrade');
      expect(isExploreCandidate(opp, const [], now: now), isTrue);
    });

    test('lost pipeline stage is excluded even if cert-eligible', () {
      final opp = _opportunity(
        pipelineStage: OpportunityPipelineStage.lost,
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
      );
      final held = [_certification(gradeOrClass: '7')];
      expect(isExploreCandidate(opp, held, now: now), isFalse);
    });

    test('completed pipeline stage is excluded', () {
      final opp = _opportunity(
        pipelineStage: OpportunityPipelineStage.completed,
        title: 'Irrigation scheme upgrade',
      );
      expect(isExploreCandidate(opp, const [], now: now), isFalse);
    });

    test(
      'qualified pipeline stage is excluded even if cert-eligible — '
      'already being actively pursued in Pipeline, not a discovery prospect',
      () {
        final opp = _opportunity(
          pipelineStage: OpportunityPipelineStage.qualified,
          requiredCertifications: [
            const OpportunityCertificationRequirement(
              type: CertificationType.nca,
              gradeOrClass: '5',
              label: 'NCA Class 5',
            ),
          ],
        );
        final held = [_certification(gradeOrClass: '7')];
        expect(isExploreCandidate(opp, held, now: now), isFalse);
      },
    );

    test(
      'reviewed pipeline stage still qualifies — still just triage, nobody committed yet',
      () {
        final opp = _opportunity(
          pipelineStage: OpportunityPipelineStage.reviewed,
          title: 'Irrigation scheme upgrade',
        );
        expect(isExploreCandidate(opp, const [], now: now), isTrue);
      },
    );

    test(
      'plain unassigned opportunity with no cert/growth signal is excluded',
      () {
        final opp = _opportunity(title: 'Office stationery supply');
        expect(isExploreCandidate(opp, const [], now: now), isFalse);
      },
    );

    test('an opportunity with no title is excluded (empty junk)', () {
      final opp = _opportunity(title: '');
      expect(isExploreCandidate(opp, const [], now: now), isFalse);
    });

    test(
      'a BU-tagged opportunity can still qualify for Explore when cert-eligible (B3)',
      () {
        final opp = _opportunity(
          businessUnitIds: const ['bu-construction'],
          requiredCertifications: [
            const OpportunityCertificationRequirement(
              type: CertificationType.nca,
              gradeOrClass: '5',
              label: 'NCA Class 5',
            ),
          ],
        );
        final held = [_certification(gradeOrClass: '7')];
        expect(isExploreCandidate(opp, held, now: now), isTrue);
      },
    );
  });

  group('exploreOpportunities / compareExploreCandidates', () {
    test('sorts full cert match before type-match-with-gap before none', () {
      final fullMatch = _opportunity(
        id: 'full',
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
      );
      final gapMatch = _opportunity(
        id: 'gap',
        requiredCertifications: [
          const OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '7',
            label: 'NCA Class 7',
          ),
        ],
      );
      final growthOnly = _opportunity(
        id: 'growth',
        title: 'Irrigation scheme upgrade',
      );
      final held = [_certification(gradeOrClass: '6')];

      final result = exploreOpportunities(
        [growthOnly, gapMatch, fullMatch],
        held,
        now: now,
      );

      expect(result.map((o) => o.id).toList(), ['full', 'gap', 'growth']);
    });

    test('within the same cert tier, sorts by fitScorePercent descending', () {
      final low = _opportunity(
        id: 'low',
        title: 'Irrigation A',
        fitScorePercent: 20,
      );
      final high = _opportunity(
        id: 'high',
        title: 'Irrigation B',
        fitScorePercent: 80,
      );

      final result = exploreOpportunities([low, high], const [], now: now);

      expect(result.map((o) => o.id).toList(), ['high', 'low']);
    });

    test(
      'within the same cert tier and fit score, sorts by soonest deadline; null deadlines last',
      () {
        final noDeadline = _opportunity(id: 'none', title: 'Irrigation none');
        final soon = _opportunity(
          id: 'soon',
          title: 'Irrigation soon',
          deadline: now.add(const Duration(days: 3)),
        );
        final later = _opportunity(
          id: 'later',
          title: 'Irrigation later',
          deadline: now.add(const Duration(days: 30)),
        );

        final result = exploreOpportunities(
          [noDeadline, later, soon],
          const [],
          now: now,
        );

        expect(result.map((o) => o.id).toList(), ['soon', 'later', 'none']);
      },
    );
  });
}
