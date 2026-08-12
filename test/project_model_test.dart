import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/project.dart';

void main() {
  final now = DateTime.utc(2024, 8, 1);

  test('Project round-trips every field', () {
    final project = Project(
      id: 'project-1',
      name: 'Rural Water Network',
      description: 'Design and build a rural water network',
      client: 'Ministry of Water',
      status: ProjectStatus.running,
      startDate: now,
      endDate: now.add(const Duration(days: 365)),
      teamMembers: const ['jane@example.com'],
      notes: 'On track',
      createdAt: now,
      updatedAt: now,
      category: ProjectCategory.waterSanitation,
      location: 'Nairobi',
      contractValueAmount: 250000,
      contractValueCurrency: 'USD',
      scopeOfWorks: 'Full network design and construction',
      fundingAgency: 'USAID',
      contractorRole: ContractorRole.mainContractor,
      projectSize: '12 km',
      clientType: ClientType.government,
      sourceOpportunityId: 'opportunity-1',
      experienceId: 'experience-1',
      businessUnitIds: const ['bu-1'],
      industryIds: const ['industry-1'],
      technologyIds: const ['technology-1'],
      serviceIds: const ['service-1'],
      capabilityIds: const ['capability-1'],
      productIds: const ['product-1'],
    );

    final restored = Project.fromMap(project.id, project.toMap());

    expect(restored.name, 'Rural Water Network');
    expect(restored.description, project.description);
    expect(restored.client, project.client);
    expect(restored.status, ProjectStatus.running);
    expect(restored.startDate?.toUtc(), now.toUtc());
    expect(
      restored.endDate?.toUtc(),
      now.add(const Duration(days: 365)).toUtc(),
    );
    expect(restored.teamMembers, ['jane@example.com']);
    expect(restored.notes, 'On track');
    expect(restored.category, ProjectCategory.waterSanitation);
    expect(restored.location, 'Nairobi');
    expect(restored.contractValueAmount, 250000);
    expect(restored.contractValueCurrency, 'USD');
    expect(restored.scopeOfWorks, project.scopeOfWorks);
    expect(restored.fundingAgency, 'USAID');
    expect(restored.contractorRole, ContractorRole.mainContractor);
    expect(restored.projectSize, '12 km');
    expect(restored.clientType, ClientType.government);
    expect(restored.sourceOpportunityId, 'opportunity-1');
    expect(restored.experienceId, 'experience-1');
    expect(restored.businessUnitIds, ['bu-1']);
    expect(restored.industryIds, ['industry-1']);
    expect(restored.technologyIds, ['technology-1']);
    expect(restored.serviceIds, ['service-1']);
    expect(restored.capabilityIds, ['capability-1']);
    expect(restored.productIds, ['product-1']);
  });

  test('relationship IDs default to empty lists when missing', () {
    final restored = Project.fromMap('project-4', {
      'name': 'Legacy project',
      'description': '',
      'client': '',
      'status': 'planned',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.businessUnitIds, isEmpty);
    expect(restored.industryIds, isEmpty);
    expect(restored.technologyIds, isEmpty);
    expect(restored.serviceIds, isEmpty);
    expect(restored.capabilityIds, isEmpty);
    expect(restored.productIds, isEmpty);
    expect(restored.fundingAgency, '');
  });

  test('copyWith can update relationship ID lists', () {
    final project = Project(
      id: 'project-5',
      name: 'Name',
      description: '',
      client: '',
      status: ProjectStatus.planned,
      createdAt: now,
      updatedAt: now,
      businessUnitIds: const ['bu-1'],
    );

    final updated = project.copyWith(businessUnitIds: ['bu-1', 'bu-2']);

    expect(updated.businessUnitIds, ['bu-1', 'bu-2']);
  });

  test(
    'Project defaults sourceOpportunityId/experienceId to null when missing',
    () {
      final restored = Project.fromMap('project-2', {
        'name': 'Legacy project',
        'description': '',
        'client': '',
        'status': 'planned',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.sourceOpportunityId, isNull);
      expect(restored.experienceId, isNull);
    },
  );

  test('copyWith preserves sourceOpportunityId and experienceId untouched', () {
    final project = Project(
      id: 'project-3',
      name: 'Original name',
      description: '',
      client: '',
      status: ProjectStatus.planned,
      createdAt: now,
      updatedAt: now,
      sourceOpportunityId: 'opportunity-1',
      experienceId: 'experience-1',
    );

    final updated = project.copyWith(name: 'Updated name');

    expect(updated.name, 'Updated name');
    expect(updated.sourceOpportunityId, 'opportunity-1');
    expect(updated.experienceId, 'experience-1');
  });
}
