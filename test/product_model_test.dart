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
      businessUnitIds: const ['unit-1'],
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
    expect(restored.businessUnitIds, product.businessUnitIds);
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

  test('reads legacy single businessUnitId into a one-item list', () {
    final restored = Product.fromMap('product-legacy', {
      'name': 'Legacy Product',
      'slug': 'legacy-product',
      'businessUnitId': 'agribusiness-id',
    });
    expect(restored.businessUnitIds, ['agribusiness-id']);
  });

  test('prefers canonical businessUnitIds over legacy businessUnitId', () {
    final restored = Product.fromMap('product-both', {
      'name': 'Kilimo Mkononi',
      'slug': 'kilimo-mkononi',
      'businessUnitId': 'agribusiness-id',
      'businessUnitIds': ['agribusiness-id', 'it-id'],
    });
    expect(restored.businessUnitIds, ['agribusiness-id', 'it-id']);
  });

  test('supports multiple Business Units and round-trips both', () {
    final createdAt = DateTime.utc(2024, 3, 1);
    final updatedAt = DateTime.utc(2024, 3, 2);
    final product = Product(
      id: 'product-multi',
      name: 'Kilimo Mkononi',
      slug: 'kilimo-mkononi',
      businessUnitIds: const ['agribusiness-id', 'it-id'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = product.toMap();
    // Legacy field stays in sync with the first entry so the existing
    // ProductService.watchByBusinessUnit equality query keeps matching.
    expect(map['businessUnitId'], 'agribusiness-id');
    expect(map['businessUnitIds'], ['agribusiness-id', 'it-id']);

    final restored = Product.fromMap(product.id, map);
    expect(restored.businessUnitIds, ['agribusiness-id', 'it-id']);
  });

  test('supports multiple Technology ids and round-trips all of them, '
      'e.g. Kilimo Mkononi spanning Flutter, Firebase, REST APIs, Gemini AI, '
      'AI/ML and GPS/Geospatial Technology', () {
    final createdAt = DateTime.utc(2024, 4, 1);
    final updatedAt = DateTime.utc(2024, 4, 2);
    const technologyIds = [
      'flutter-id',
      'firebase-id',
      'rest-apis-id',
      'gemini-ai-id',
      'ai-ml-id',
      'gps-geospatial-id',
    ];
    final product = Product(
      id: 'product-kilimo',
      name: 'Kilimo Mkononi',
      slug: 'kilimo-mkononi',
      businessUnitIds: const ['agribusiness-id', 'it-id'],
      technologyIds: technologyIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = product.toMap();
    expect(map['technologyIds'], technologyIds);

    final restored = Product.fromMap(product.id, map);
    expect(restored.technologyIds, technologyIds);
    expect(restored.technologyIds, hasLength(6));
  });

  test('an empty Business Unit selection round-trips as an empty list', () {
    final product = Product(
      id: 'product-none',
      name: 'No BU Yet',
      slug: 'no-bu-yet',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final restored = Product.fromMap(product.id, product.toMap());
    expect(restored.businessUnitIds, isEmpty);
  });
}
