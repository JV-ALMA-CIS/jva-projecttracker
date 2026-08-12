import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';

void main() {
  test('BusinessUnit round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 1, 1);
    final updatedAt = DateTime.utc(2024, 1, 2);

    final unit = BusinessUnit(
      id: 'unit-1',
      name: 'Construction',
      slug: 'construction',
      summary: 'Works in physical infrastructure',
      description: 'Construction business unit',
      status: BusinessUnitStatus.active,
      productIds: ['CoffeeCore'],
      serviceIds: ['Design'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = unit.toMap();
    final restored = BusinessUnit.fromMap(unit.id, map);

    expect(restored.name, unit.name);
    expect(restored.slug, unit.slug);
    expect(restored.summary, unit.summary);
    expect(restored.productIds, unit.productIds);
    expect(restored.serviceIds, unit.serviceIds);
    expect(restored.status, BusinessUnitStatus.active);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });
}
