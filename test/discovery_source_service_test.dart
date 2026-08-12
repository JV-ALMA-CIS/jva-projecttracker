import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/discovery_source.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/discovery_source_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DiscoverySourceService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DiscoverySourceService(firestore: firestore);
  });

  DiscoverySource buildSource({
    required String name,
    DiscoverySourceType type = DiscoverySourceType.governmentProcurement,
  }) {
    final now = DateTime.utc(2024, 8, 1);
    return DiscoverySource(
      id: '',
      name: name,
      type: type,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a source that watchAll then returns', () async {
    await service.create(buildSource(name: 'Government portal'));

    final sources = await service.watchAll().first;
    expect(sources, hasLength(1));
    expect(sources.single.name, 'Government portal');
  });

  test('watchAll orders sources by name', () async {
    await service.create(buildSource(name: 'Zebra source'));
    await service.create(buildSource(name: 'Alpha source'));

    final sources = await service.watchAll().first;
    expect(sources.map((s) => s.name), ['Alpha source', 'Zebra source']);
  });

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildSource(name: 'Original name'));
    final original = await service.watchById(id).first;

    await service.update(
      DiscoverySource(
        id: id,
        name: 'Updated name',
        type: DiscoverySourceType.ngo,
        createdAt: original!.createdAt,
        updatedAt: DateTime.utc(2024, 8, 2),
      ),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.name, 'Updated name');
    expect(updated.type, DiscoverySourceType.ngo);
  });

  test('setEnabled toggles only the enabled flag', () async {
    final id = await service.create(buildSource(name: 'Toggle me'));

    await service.setEnabled(id, false);

    final source = await service.watchById(id).first;
    expect(source!.enabled, isFalse);
    expect(source.name, 'Toggle me');
  });

  test('delete removes the document', () async {
    final id = await service.create(buildSource(name: 'Delete me'));

    await service.delete(id);

    final source = await service.watchById(id).first;
    expect(source, isNull);
  });
}
