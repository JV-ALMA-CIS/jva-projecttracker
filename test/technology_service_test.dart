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

  /// Like [buildTechnology], but leaves `slug` blank — the shape a plain
  /// name-only entry actually takes (e.g. the Product form's "+ Add
  /// Technology" quick-create, which never touches the Technology form's
  /// slug field), so [TechnologyService.create]'s own [slugify]-derived
  /// slug is what actually gets stored. [buildTechnology] itself always
  /// sets a non-empty, non-normalized `slug` (`name.toLowerCase()`, not run
  /// through [slugify]), which is deliberately realistic for the tests that
  /// exercise plain create/update/delete — but wrong for dedup tests, which
  /// need the persisted slug to be the actual normalization key so a second
  /// create's lookup can find the first record.
  Technology buildBareTechnology({String name = 'Flutter'}) {
    final now = DateTime.utc(2024, 5, 1);
    return Technology(
      id: '',
      name: name,
      slug: '',
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

  test('create is independently usable — no Historical Project/document/AI '
      'extraction required, just a name', () async {
    final id = await service.create(buildTechnology(name: 'Flutter'));
    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
  });

  test(
    'create skips writing a duplicate when a Technology with the same '
    'normalized name already exists, returning the existing id instead',
    () async {
      final firstId = await service.create(
        buildBareTechnology(name: 'Flutter'),
      );

      final secondId = await service.create(
        buildBareTechnology(name: 'flutter'),
      );

      expect(secondId, firstId);
      final all = await service.watchAll().first;
      expect(all, hasLength(1));
    },
  );

  test('duplicate detection ignores casing/whitespace differences via slugify '
      'normalization', () async {
    final firstId = await service.create(
      buildBareTechnology(name: 'Google Gemini AI'),
    );

    final secondId = await service.create(
      buildBareTechnology(name: '  Google   Gemini AI  '),
    );

    expect(secondId, firstId);
    final all = await service.watchAll().first;
    expect(all, hasLength(1));
  });

  test('distinct technologies with different names are both created', () async {
    final flutterId = await service.create(
      buildBareTechnology(name: 'Flutter'),
    );
    final firebaseId = await service.create(
      buildBareTechnology(name: 'Firebase'),
    );

    expect(flutterId, isNot(firebaseId));
    final all = await service.watchAll().first;
    expect(all, hasLength(2));
  });

  test('findByNormalizedName returns null when nothing matches', () async {
    await service.create(buildTechnology(name: 'Flutter'));
    final found = await service.findByNormalizedName('Firebase');
    expect(found, isNull);
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
