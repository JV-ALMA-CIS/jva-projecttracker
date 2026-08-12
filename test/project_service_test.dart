import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/project_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProjectService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ProjectService(firestore: firestore);
  });

  Project buildProject({
    String name = 'Test project',
    String? sourceOpportunityId,
  }) {
    final now = DateTime.utc(2024, 8, 1);
    return Project(
      id: '',
      name: name,
      description: '',
      client: '',
      status: ProjectStatus.planned,
      createdAt: now,
      updatedAt: now,
      sourceOpportunityId: sourceOpportunityId,
    );
  }

  test('create writes a project that watchAll then returns', () async {
    await service.create(buildProject());

    final projects = await service.watchAll().first;
    expect(projects, hasLength(1));
    expect(projects.single.name, 'Test project');
  });

  test('watchByOpportunityId returns null when no project exists', () async {
    final project = await service.watchByOpportunityId('opportunity-1').first;
    expect(project, isNull);
  });

  test(
    'watchByOpportunityId returns the project started from that opportunity',
    () async {
      await service.create(
        buildProject(name: 'From opp 1', sourceOpportunityId: 'opportunity-1'),
      );
      await service.create(
        buildProject(name: 'From opp 2', sourceOpportunityId: 'opportunity-2'),
      );

      final project = await service.watchByOpportunityId('opportunity-1').first;
      expect(project, isNotNull);
      expect(project!.name, 'From opp 1');
    },
  );

  test(
    'linkExperience sets experienceId without touching other fields',
    () async {
      final id = await service.create(buildProject(name: 'Completed project'));

      await service.linkExperience(id, 'experience-1');

      final project = await service.watchById(id).first;
      expect(project!.experienceId, 'experience-1');
      expect(project.name, 'Completed project');
    },
  );

  test('delete removes the project', () async {
    final id = await service.create(buildProject());

    await service.delete(id);

    final project = await service.watchById(id).first;
    expect(project, isNull);
  });
}
