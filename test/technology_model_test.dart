import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';

void main() {
  test('Technology round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 5, 1);
    final updatedAt = DateTime.utc(2024, 5, 2);

    final technology = Technology(
      id: 'tech-1',
      name: 'Flutter',
      slug: 'flutter',
      summary: 'Cross-platform UI toolkit',
      description: 'Used for web and mobile',
      category: 'Software',
      vendor: 'Google',
      website: 'https://flutter.dev',
      keywords: ['ui', 'mobile'],
      tags: ['frontend'],
      status: TechnologyStatus.active,
      notes: 'Used in several products',
      businessUnitIds: ['unit-1'],
      productIds: ['product-1'],
      capabilityIds: ['cap-1'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = technology.toMap();
    final restored = Technology.fromMap(technology.id, map);

    expect(restored.name, technology.name);
    expect(restored.slug, technology.slug);
    expect(restored.category, technology.category);
    expect(restored.vendor, technology.vendor);
    expect(restored.website, technology.website);
    expect(restored.businessUnitIds, technology.businessUnitIds);
    expect(restored.productIds, technology.productIds);
    expect(restored.capabilityIds, technology.capabilityIds);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('Technology defaults missing optional fields', () {
    final now = DateTime.utc(2024, 5, 1);
    final restored = Technology.fromMap('tech-2', {
      'name': 'Bare Technology',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.status, TechnologyStatus.active);
    expect(restored.category, isNull);
    expect(restored.vendor, isNull);
    expect(restored.website, isNull);
    expect(restored.keywords, isEmpty);
    expect(restored.tags, isEmpty);
    expect(restored.businessUnitIds, isEmpty);
    expect(restored.productIds, isEmpty);
    expect(restored.capabilityIds, isEmpty);
  });
}
