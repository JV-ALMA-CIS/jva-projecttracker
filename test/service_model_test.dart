import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';

void main() {
  test('ServiceModel round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 3, 1);
    final updatedAt = DateTime.utc(2024, 3, 2);

    final service = ServiceModel(
      id: 'service-1',
      name: 'Construction Supervision',
      slug: 'construction-supervision',
      summary: 'On-site supervision',
      description: 'Technical oversight',
      businessUnitIds: ['unit-1', 'unit-2'],
      status: ServiceStatus.active,
      capabilityIds: ['project-management'],
      industryIds: ['infrastructure'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = service.toMap();
    final restored = ServiceModel.fromMap(service.id, map);

    expect(restored.name, service.name);
    expect(restored.slug, service.slug);
    expect(restored.businessUnitIds, service.businessUnitIds);
    expect(restored.capabilityIds, service.capabilityIds);
    expect(restored.industryIds, service.industryIds);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });
}
