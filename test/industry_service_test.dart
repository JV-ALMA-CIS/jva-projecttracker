import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late IndustryService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = IndustryService(firestore: firestore);
  });

  Industry buildIndustry({
    String id = '',
    String name = 'Agriculture',
    IndustryStatus status = IndustryStatus.active,
  }) {
    final now = DateTime.utc(2024, 3, 1);
    return Industry(
      id: id,
      name: name,
      status: status,
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a document that watchAll then returns', () async {
    final id = await service.create(buildIndustry());

    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, 'Agriculture');
    expect(all.single.technologyIds, ['tech-1']);
  });

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildIndustry());
    final created = await service.watchById(id).first;

    await service.update(
      Industry(
        id: created!.id,
        name: created.name,
        description: created.description,
        sector: created.sector,
        tags: created.tags,
        status: IndustryStatus.archived,
        businessUnitIds: created.businessUnitIds,
        productIds: created.productIds,
        capabilityIds: created.capabilityIds,
        technologyIds: created.technologyIds,
        experienceIds: created.experienceIds,
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      ),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.status, IndustryStatus.archived);
  });

  test('delete removes the document', () async {
    final id = await service.create(buildIndustry());
    await service.delete(id);

    final doc = await service.watchById(id).first;
    expect(doc, isNull);
  });

  test('watchAll orders by updatedAt descending', () async {
    final older = Industry(
      id: '',
      name: 'Older',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final newer = Industry(
      id: '',
      name: 'Newer',
      createdAt: DateTime.utc(2024, 6, 1),
      updatedAt: DateTime.utc(2024, 6, 1),
    );
    await service.create(older);
    await service.create(newer);

    final all = await service.watchAll().first;
    expect(all.map((i) => i.name), ['Newer', 'Older']);
  });
}
