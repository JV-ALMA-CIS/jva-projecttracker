import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

void main() {
  final now = DateTime.utc(2024, 6, 1);

  Map<String, dynamic> baseMap({
    Object? syncFrequencyMinutes = 1440,
    Object? healthScore = 100,
    Object? aiQualityScore,
    Object? opportunitiesImported = 0,
    Object? opportunitiesPursued = 0,
    Object? wins = 0,
    Object? losses = 0,
  }) {
    return {
      'name': 'Tenders Kenya (PPIP)',
      'organization': 'Public Procurement Information Portal',
      'category': 'governmentAgency',
      'discoveryMethod': 'api',
      'status': 'active',
      'enabled': true,
      'syncFrequencyMinutes': syncFrequencyMinutes,
      'healthScore': healthScore,
      'aiQualityScore': aiQualityScore,
      'opportunitiesImported': opportunitiesImported,
      'opportunitiesPursued': opportunitiesPursued,
      'wins': wins,
      'losses': losses,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  group('TenderSource.fromMap numeric field parsing', () {
    // Regression coverage for the bug that made the Discovery Engine hang
    // indefinitely: Firestore (particularly cloud_firestore_web) can return
    // a whole-number field as a Dart `double` rather than `int`. A plain
    // `data['x'] as int?` cast throws a TypeError on a double, which
    // surfaces as a broken/never-resolving stream. Every numeric field here
    // must parse correctly whether Firestore hands back an int or a double.
    for (final shape in ['int', 'double']) {
      test(
        'parses every numeric field correctly when Firestore returns $shape values',
        () {
          Object asShape(num n) => shape == 'double' ? n.toDouble() : n.toInt();

          final map = baseMap(
            syncFrequencyMinutes: asShape(1440),
            healthScore: asShape(100),
            aiQualityScore: asShape(85),
            opportunitiesImported: asShape(12),
            opportunitiesPursued: asShape(4),
            wins: asShape(2),
            losses: asShape(1),
          );

          final source = TenderSource.fromMap('src-1', map);

          expect(source.syncFrequencyMinutes, 1440);
          expect(source.healthScore, 100);
          expect(source.aiQualityScore, 85);
          expect(source.opportunitiesImported, 12);
          expect(source.opportunitiesPursued, 4);
          expect(source.wins, 2);
          expect(source.losses, 1);
        },
      );
    }

    test('defaults correctly when numeric fields are absent', () {
      final map = baseMap()
        ..remove('syncFrequencyMinutes')
        ..remove('healthScore')
        ..remove('opportunitiesImported')
        ..remove('opportunitiesPursued')
        ..remove('wins')
        ..remove('losses');

      final source = TenderSource.fromMap('src-1', map);

      expect(source.syncFrequencyMinutes, 1440);
      expect(source.healthScore, 100);
      expect(source.aiQualityScore, isNull);
      expect(source.opportunitiesImported, 0);
      expect(source.opportunitiesPursued, 0);
      expect(source.wins, 0);
      expect(source.losses, 0);
    });

    test(
      'aiQualityScore stays null when absent, even though other fields default',
      () {
        final source = TenderSource.fromMap('src-1', baseMap());
        expect(source.aiQualityScore, isNull);
      },
    );
  });

  test('TenderSource round-trips through toMap/fromMap', () {
    final source = TenderSource(
      id: 'src-1',
      name: 'Tenders Kenya (PPIP)',
      organization: 'Public Procurement Information Portal',
      category: TenderSourceCategory.governmentAgency,
      discoveryMethod: TenderDiscoveryMethod.api,
      healthScore: 92,
      aiQualityScore: 77,
      opportunitiesImported: 5,
      opportunitiesPursued: 2,
      wins: 1,
      losses: 0,
      createdAt: now,
      updatedAt: now,
    );

    final restored = TenderSource.fromMap(source.id, source.toMap());

    expect(restored.healthScore, 92);
    expect(restored.aiQualityScore, 77);
    expect(restored.opportunitiesImported, 5);
    expect(restored.opportunitiesPursued, 2);
    expect(restored.wins, 1);
    expect(restored.losses, 0);
  });
}
