import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/product.dart';

void main() {
  test('Product round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 2, 1);
    final updatedAt = DateTime.utc(2024, 2, 2);

    final product = Product(
      id: 'product-1',
      name: 'CoffeeCore',
      slug: 'coffeecore',
      summary: 'Digital platform',
      description: 'Core product',
      businessUnitId: 'unit-1',
      status: ProductStatus.active,
      storeUrl:
          'https://play.google.com/store/apps/details?id=com.jva.coffeecore',
      capabilityIds: ['analytics'],
      industryIds: ['agri'],
      technologyIds: ['flutter'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = product.toMap();
    final restored = Product.fromMap(product.id, map);

    expect(restored.name, product.name);
    expect(restored.slug, product.slug);
    expect(restored.storeUrl, product.storeUrl);
    expect(restored.businessUnitId, product.businessUnitId);
    expect(restored.capabilityIds, product.capabilityIds);
    expect(restored.industryIds, product.industryIds);
    expect(restored.technologyIds, product.technologyIds);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('storeUrl defaults to null when missing', () {
    final restored = Product.fromMap('product-2', {
      'name': 'Legacy Product',
      'slug': 'legacy-product',
      'businessUnitId': 'unit-1',
    });
    expect(restored.storeUrl, isNull);
  });
}
