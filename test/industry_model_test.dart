import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';

void main() {
  test('Industry round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 3, 1);
    final updatedAt = DateTime.utc(2024, 3, 2);

    final industry = Industry(
      id: 'industry-1',
      name: 'Agriculture',
      description: 'Farming and agribusiness',
      sector: 'Primary',
      tags: const ['agri', 'rural'],
      status: IndustryStatus.active,
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      experienceIds: const ['experience-1'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = industry.toMap();
    final restored = Industry.fromMap(industry.id, map);

    expect(restored.name, industry.name);
    expect(restored.description, industry.description);
    expect(restored.sector, industry.sector);
    expect(restored.tags, industry.tags);
    expect(restored.status, IndustryStatus.active);
    expect(restored.businessUnitIds, industry.businessUnitIds);
    expect(restored.productIds, industry.productIds);
    expect(restored.capabilityIds, industry.capabilityIds);
    expect(restored.technologyIds, industry.technologyIds);
    expect(restored.experienceIds, industry.experienceIds);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('Industry defaults missing optional fields', () {
    final now = DateTime.utc(2024, 3, 1);
    final restored = Industry.fromMap('industry-2', {
      'name': 'Bare Industry',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.status, IndustryStatus.active);
    expect(restored.sector, isNull);
    expect(restored.tags, isEmpty);
    expect(restored.businessUnitIds, isEmpty);
    expect(restored.productIds, isEmpty);
    expect(restored.capabilityIds, isEmpty);
    expect(restored.technologyIds, isEmpty);
    expect(restored.experienceIds, isEmpty);
  });
}
