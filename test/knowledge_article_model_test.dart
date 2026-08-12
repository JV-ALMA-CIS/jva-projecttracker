import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';

void main() {
  test('KnowledgeArticle round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 5, 1);
    final updatedAt = DateTime.utc(2024, 5, 2);

    final article = KnowledgeArticle(
      id: 'article-1',
      title: 'Water infrastructure proposal playbook',
      category: 'Proposal Guidance',
      summary: 'How to structure a winning water infrastructure proposal',
      content: 'Long-form guidance text goes here...',
      tags: const ['proposals', 'water'],
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      serviceIds: const ['service-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      industryIds: const ['industry-1'],
      experienceIds: const ['experience-1'],
      status: KnowledgeArticleStatus.active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = article.toMap();
    final restored = KnowledgeArticle.fromMap(article.id, map);

    expect(restored.title, article.title);
    expect(restored.category, article.category);
    expect(restored.summary, article.summary);
    expect(restored.content, article.content);
    expect(restored.tags, article.tags);
    expect(restored.businessUnitIds, article.businessUnitIds);
    expect(restored.productIds, article.productIds);
    expect(restored.serviceIds, article.serviceIds);
    expect(restored.capabilityIds, article.capabilityIds);
    expect(restored.technologyIds, article.technologyIds);
    expect(restored.industryIds, article.industryIds);
    expect(restored.experienceIds, article.experienceIds);
    expect(restored.status, KnowledgeArticleStatus.active);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('KnowledgeArticle defaults missing optional fields', () {
    final now = DateTime.utc(2024, 5, 1);
    final restored = KnowledgeArticle.fromMap('article-2', {
      'title': 'Bare Article',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.status, KnowledgeArticleStatus.active);
    expect(restored.category, isEmpty);
    expect(restored.summary, isEmpty);
    expect(restored.content, isEmpty);
    expect(restored.tags, isEmpty);
    expect(restored.businessUnitIds, isEmpty);
    expect(restored.productIds, isEmpty);
    expect(restored.serviceIds, isEmpty);
    expect(restored.capabilityIds, isEmpty);
    expect(restored.technologyIds, isEmpty);
    expect(restored.industryIds, isEmpty);
    expect(restored.experienceIds, isEmpty);
  });

  test('category accepts a value outside the suggested list', () {
    final now = DateTime.utc(2024, 5, 1);
    final article = KnowledgeArticle(
      id: 'article-3',
      title: 'Custom category article',
      category: 'A Brand New Category Nobody Predicted',
      createdAt: now,
      updatedAt: now,
    );

    final restored = KnowledgeArticle.fromMap(article.id, article.toMap());

    expect(restored.category, 'A Brand New Category Nobody Predicted');
    expect(suggestedKnowledgeCategories.contains(restored.category), isFalse);
  });
}
