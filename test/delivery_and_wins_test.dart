import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/delivery_and_wins.dart';

Project _project({
  String id = 'project-1',
  ProjectStatus status = ProjectStatus.planned,
  String? sourceOpportunityId,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Project(
    id: id,
    name: 'Project $id',
    description: '',
    client: '',
    status: status,
    createdAt: now,
    updatedAt: now,
    sourceOpportunityId: sourceOpportunityId,
  );
}

Opportunity _opportunity({
  String id = 'opp-1',
  OpportunityPipelineStage pipelineStage = OpportunityPipelineStage.discovered,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Opportunity(
    id: id,
    title: 'Opportunity $id',
    description: '',
    sourceUrl: 'https://example.com/$id',
    discoveredAt: now,
    updatedAt: now,
    pipelineStage: pipelineStage,
  );
}

void main() {
  group('isOperationalProject', () {
    test('planned and running are operational', () {
      expect(
        isOperationalProject(_project(status: ProjectStatus.planned)),
        isTrue,
      );
      expect(
        isOperationalProject(_project(status: ProjectStatus.running)),
        isTrue,
      );
    });

    test('past is not operational, even with a sourceOpportunityId', () {
      final project = _project(
        status: ProjectStatus.past,
        sourceOpportunityId: 'opp-1',
      );
      expect(isOperationalProject(project), isFalse);
    });
  });

  group('operationalProjects / historicalProjects', () {
    test('partitions planned/running vs past into disjoint lists', () {
      final planned = _project(id: 'p1', status: ProjectStatus.planned);
      final running = _project(id: 'p2', status: ProjectStatus.running);
      final past = _project(id: 'p3', status: ProjectStatus.past);
      final all = [planned, running, past];

      expect(operationalProjects(all).map((p) => p.id).toSet(), {'p1', 'p2'});
      expect(historicalProjects(all).map((p) => p.id).toSet(), {'p3'});
    });
  });

  group('isWonOpportunity / wonOpportunities', () {
    test('awarded and projectStarted both count as won', () {
      expect(
        isWonOpportunity(
          _opportunity(pipelineStage: OpportunityPipelineStage.awarded),
        ),
        isTrue,
      );
      expect(
        isWonOpportunity(
          _opportunity(pipelineStage: OpportunityPipelineStage.projectStarted),
        ),
        isTrue,
      );
    });

    test('completed and every earlier stage are not won', () {
      expect(
        isWonOpportunity(
          _opportunity(pipelineStage: OpportunityPipelineStage.completed),
        ),
        isFalse,
      );
      expect(
        isWonOpportunity(
          _opportunity(pipelineStage: OpportunityPipelineStage.negotiation),
        ),
        isFalse,
      );
      expect(
        isWonOpportunity(
          _opportunity(pipelineStage: OpportunityPipelineStage.lost),
        ),
        isFalse,
      );
    });

    test('wonOpportunities filters a mixed list', () {
      final awarded = _opportunity(
        id: 'o1',
        pipelineStage: OpportunityPipelineStage.awarded,
      );
      final started = _opportunity(
        id: 'o2',
        pipelineStage: OpportunityPipelineStage.projectStarted,
      );
      final lost = _opportunity(
        id: 'o3',
        pipelineStage: OpportunityPipelineStage.lost,
      );
      expect(
        wonOpportunities([awarded, started, lost]).map((o) => o.id).toSet(),
        {'o1', 'o2'},
      );
    });
  });

  group('hasStartedProject', () {
    test('true when a project links back via sourceOpportunityId', () {
      final projects = [_project(id: 'p1', sourceOpportunityId: 'opp-1')];
      expect(hasStartedProject('opp-1', projects), isTrue);
    });

    test('false when no project links to that opportunity', () {
      final projects = [_project(id: 'p1', sourceOpportunityId: 'opp-2')];
      expect(hasStartedProject('opp-1', projects), isFalse);
    });

    test('false against an empty project list', () {
      expect(hasStartedProject('opp-1', const []), isFalse);
    });
  });

  group('wonWithoutProject', () {
    test('excludes a won opportunity once its project exists', () {
      final awardedWithProject = _opportunity(
        id: 'o1',
        pipelineStage: OpportunityPipelineStage.awarded,
      );
      final awardedWithoutProject = _opportunity(
        id: 'o2',
        pipelineStage: OpportunityPipelineStage.awarded,
      );
      final projects = [_project(id: 'p1', sourceOpportunityId: 'o1')];

      final result = wonWithoutProject([
        awardedWithProject,
        awardedWithoutProject,
      ], projects);

      expect(result.map((o) => o.id).toList(), ['o2']);
    });

    test('never invents a match — an unrelated project does not count', () {
      final awarded = _opportunity(
        id: 'o1',
        pipelineStage: OpportunityPipelineStage.awarded,
      );
      final projects = [_project(id: 'p1', sourceOpportunityId: null)];

      final result = wonWithoutProject([awarded], projects);

      expect(result.map((o) => o.id).toList(), ['o1']);
    });

    test('only considers won opportunities, ignoring open pipeline stages', () {
      final discovered = _opportunity(
        id: 'o1',
        pipelineStage: OpportunityPipelineStage.discovered,
      );
      final result = wonWithoutProject([discovered], const []);
      expect(result, isEmpty);
    });
  });
}
