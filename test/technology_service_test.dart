import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TechnologyService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TechnologyService(firestore: firestore);
  });

  Technology buildTechnology({
    String id = '',
    String name = 'Flutter',
    TechnologyStatus status = TechnologyStatus.active,
  }) {
    final now = DateTime.utc(2024, 5, 1);
    return Technology(
      id: id,
      name: name,
      slug: name.toLowerCase(),
      status: status,
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      capabilityIds: const ['cap-1'],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a document that watchAll then returns', () async {
    final id = await service.create(buildTechnology());

    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, 'Flutter');
    expect(all.single.businessUnitIds, ['unit-1']);
  });

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildTechnology());
    final created = await service.watchById(id).first;

    await service.update(
      created!.copyWithForTest(status: TechnologyStatus.archived),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.status, TechnologyStatus.archived);
  });

  test('delete removes the document', () async {
    final id = await service.create(buildTechnology());
    await service.delete(id);

    final doc = await service.watchById(id).first;
    expect(doc, isNull);
  });

  test('watchAll orders by updatedAt descending', () async {
    final older = Technology(
      id: '',
      name: 'Older',
      slug: 'older',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final newer = Technology(
      id: '',
      name: 'Newer',
      slug: 'newer',
      createdAt: DateTime.utc(2024, 6, 1),
      updatedAt: DateTime.utc(2024, 6, 1),
    );
    await service.create(older);
    await service.create(newer);

    final all = await service.watchAll().first;
    expect(all.map((t) => t.name), ['Newer', 'Older']);
  });
}

/// Test-only helper: the app itself never needs to mutate a single field of
/// a loaded [Technology] (forms rebuild a full instance from their
/// controllers — see TechnologyFormScreen._save), so the model has no
/// copyWith. Rebuilding it here keeps that non-requirement out of the model.
extension _TechnologyTestX on Technology {
  Technology copyWithForTest({TechnologyStatus? status}) => Technology(
    id: id,
    name: name,
    slug: slug,
    summary: summary,
    description: description,
    category: category,
    vendor: vendor,
    website: website,
    keywords: keywords,
    tags: tags,
    status: status ?? this.status,
    notes: notes,
    businessUnitIds: businessUnitIds,
    productIds: productIds,
    capabilityIds: capabilityIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
