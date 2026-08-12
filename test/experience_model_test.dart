import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';

void main() {
  test('Experience round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 4, 1);
    final updatedAt = DateTime.utc(2024, 4, 2);
    final startDate = DateTime.utc(2022, 1, 15);
    final endDate = DateTime.utc(2023, 6, 30);

    final experience = Experience(
      id: 'experience-1',
      title: 'Rural water network rehabilitation',
      summary: 'Rehabilitated 40km of rural water pipeline',
      clientName: 'Ministry of Water',
      partnerName: 'Local Co-op',
      country: 'Kenya',
      region: 'Rift Valley',
      businessUnitIds: const ['unit-1'],
      productIds: const ['product-1'],
      capabilityIds: const ['cap-1'],
      technologyIds: const ['tech-1'],
      industryIds: const ['industry-1'],
      startDate: startDate,
      endDate: endDate,
      contractValue: 1500000,
      currency: 'USD',
      fundingSource: 'World Bank',
      outcome: 'Delivered on time and under budget',
      achievements: const ['40km rehabilitated', 'Zero safety incidents'],
      lessonsLearned: const ['Early community engagement reduces delays'],
      tags: const ['water', 'infrastructure'],
      status: ExperienceStatus.active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = experience.toMap();
    final restored = Experience.fromMap(experience.id, map);

    expect(restored.title, experience.title);
    expect(restored.summary, experience.summary);
    expect(restored.clientName, experience.clientName);
    expect(restored.partnerName, experience.partnerName);
    expect(restored.country, experience.country);
    expect(restored.region, experience.region);
    expect(restored.businessUnitIds, experience.businessUnitIds);
    expect(restored.productIds, experience.productIds);
    expect(restored.capabilityIds, experience.capabilityIds);
    expect(restored.technologyIds, experience.technologyIds);
    expect(restored.industryIds, experience.industryIds);
    expect(restored.startDate?.toUtc(), startDate.toUtc());
    expect(restored.endDate?.toUtc(), endDate.toUtc());
    expect(restored.contractValue, experience.contractValue);
    expect(restored.currency, experience.currency);
    expect(restored.fundingSource, experience.fundingSource);
    expect(restored.outcome, experience.outcome);
    expect(restored.achievements, experience.achievements);
    expect(restored.lessonsLearned, experience.lessonsLearned);
    expect(restored.tags, experience.tags);
    expect(restored.status, ExperienceStatus.active);
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test('Experience defaults missing optional fields', () {
    final now = DateTime.utc(2024, 4, 1);
    final restored = Experience.fromMap('experience-2', {
      'title': 'Bare Experience',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    expect(restored.status, ExperienceStatus.active);
    expect(restored.currency, 'EUR');
    expect(restored.summary, isEmpty);
    expect(restored.outcome, isEmpty);
    expect(restored.clientName, isNull);
    expect(restored.partnerName, isNull);
    expect(restored.country, isNull);
    expect(restored.region, isNull);
    expect(restored.startDate, isNull);
    expect(restored.endDate, isNull);
    expect(restored.contractValue, isNull);
    expect(restored.fundingSource, isNull);
    expect(restored.businessUnitIds, isEmpty);
    expect(restored.productIds, isEmpty);
    expect(restored.capabilityIds, isEmpty);
    expect(restored.technologyIds, isEmpty);
    expect(restored.industryIds, isEmpty);
    expect(restored.achievements, isEmpty);
    expect(restored.lessonsLearned, isEmpty);
    expect(restored.tags, isEmpty);
  });
}
