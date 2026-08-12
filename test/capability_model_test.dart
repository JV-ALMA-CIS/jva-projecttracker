import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';

void main() {
  test('Capability round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 4, 1);
    final updatedAt = DateTime.utc(2024, 4, 2);

    final capability = Capability(
      id: 'cap-1',
      name: 'Artificial Intelligence',
      slug: 'artificial-intelligence',
      summary: 'AI delivery capability',
      description: 'Supports AI-enabled solutions',
      keywords: ['ai', 'machine learning'],
      tags: ['priority'],
      status: CapabilityStatus.active,
      businessRelevance: 'High relevance for public digital programs',
      productIds: ['prod-1'],
      serviceIds: ['svc-1'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = capability.toMap();
    final restored = Capability.fromMap(capability.id, map);

    expect(restored.name, capability.name);
    expect(restored.slug, capability.slug);
    expect(restored.keywords, capability.keywords);
    expect(restored.tags, capability.tags);
    expect(restored.businessRelevance, capability.businessRelevance);
    expect(restored.productIds, capability.productIds);
    expect(restored.serviceIds, capability.serviceIds);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });
}
