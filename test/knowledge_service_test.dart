import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late KnowledgeService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = KnowledgeService(firestore: firestore);
  });

  KnowledgeArticle buildArticle({
    String id = '',
    String title = 'Company overview',
    KnowledgeArticleStatus status = KnowledgeArticleStatus.active,
  }) {
    final now = DateTime.utc(2024, 5, 1);
    return KnowledgeArticle(
      id: id,
      title: title,
      category: 'Company Overview',
      status: status,
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      serviceIds: const ['service-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      industryIds: const ['industry-1'],
      experienceIds: const ['experience-1'],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a document that watchAll then returns', () async {
    final id = await service.create(buildArticle());

    final all = await service.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.title, 'Company overview');
    expect(all.single.experienceIds, ['experience-1']);
  });

  test('update overwrites fields but preserves the document id', () async {
    final id = await service.create(buildArticle());
    final created = await service.watchById(id).first;

    await service.update(
      KnowledgeArticle(
        id: created!.id,
        title: created.title,
        category: created.category,
        summary: created.summary,
        content: created.content,
        tags: created.tags,
        businessUnitIds: created.businessUnitIds,
        productIds: created.productIds,
        serviceIds: created.serviceIds,
        capabilityIds: created.capabilityIds,
        technologyIds: created.technologyIds,
        industryIds: created.industryIds,
        experienceIds: created.experienceIds,
        status: KnowledgeArticleStatus.archived,
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      ),
    );

    final updated = await service.watchById(id).first;
    expect(updated!.id, id);
    expect(updated.status, KnowledgeArticleStatus.archived);
  });

  test('delete removes the document', () async {
    final id = await service.create(buildArticle());
    await service.delete(id);

    final doc = await service.watchById(id).first;
    expect(doc, isNull);
  });

  test('watchAll orders by updatedAt descending', () async {
    final older = KnowledgeArticle(
      id: '',
      title: 'Older',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final newer = KnowledgeArticle(
      id: '',
      title: 'Newer',
      createdAt: DateTime.utc(2024, 6, 1),
      updatedAt: DateTime.utc(2024, 6, 1),
    );
    await service.create(older);
    await service.create(newer);

    final all = await service.watchAll().first;
    expect(all.map((a) => a.title), ['Newer', 'Older']);
  });
}
