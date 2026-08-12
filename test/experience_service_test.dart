import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ExperienceService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ExperienceService(firestore: firestore);
  });

  Experience buildExperience({
    String id = '',
    String title = 'Water network rehabilitation',
    ExperienceStatus status = ExperienceStatus.active,
  }) {
    final now = DateTime.utc(2024, 4, 1);
    return Experience(
      id: id,
      title: title,
      status: status,
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      industryIds: const ['industry-1'],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a document that watchAll then returns', () async {
    final id = await service.create(buildExperience());

    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.title, 'Water network rehabilitation');
    expect(all.single.industryIds, ['industry-1']);
  });

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildExperience());
    final created = await service.watchById(id).first;

    await service.update(
      Experience(
        id: created!.id,
        title: created.title,
        summary: created.summary,
        clientName: created.clientName,
        partnerName: created.partnerName,
        country: created.country,
        region: created.region,
        businessUnitIds: created.businessUnitIds,
        productIds: created.productIds,
        capabilityIds: created.capabilityIds,
        technologyIds: created.technologyIds,
        industryIds: created.industryIds,
        startDate: created.startDate,
        endDate: created.endDate,
        contractValue: created.contractValue,
        currency: created.currency,
        fundingSource: created.fundingSource,
        outcome: created.outcome,
        achievements: created.achievements,
        lessonsLearned: created.lessonsLearned,
        tags: created.tags,
        status: ExperienceStatus.archived,
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      ),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.status, ExperienceStatus.archived);
  });

  test('delete removes the document', () async {
    final id = await service.create(buildExperience());
    await service.delete(id);

    final doc = await service.watchById(id).first;
    expect(doc, isNull);
  });

  test('watchAll orders by updatedAt descending', () async {
    final older = Experience(
      id: '',
      title: 'Older',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final newer = Experience(
      id: '',
      title: 'Newer',
      createdAt: DateTime.utc(2024, 6, 1),
      updatedAt: DateTime.utc(2024, 6, 1),
    );
    await service.create(older);
    await service.create(newer);

    final all = await service.watchAll().first;
    expect(all.map((e) => e.title), ['Newer', 'Older']);
  });
}
