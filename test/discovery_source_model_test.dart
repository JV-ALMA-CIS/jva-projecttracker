import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/discovery_source.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

void main() {
  test('DiscoverySource round-trips from Firestore maps', () {
    final createdAt = DateTime.utc(2024, 8, 1);
    final updatedAt = DateTime.utc(2024, 8, 2);
    final lastRunAt = DateTime.utc(2024, 8, 3);

    final source = DiscoverySource(
      id: 'source-1',
      name: 'World Bank tenders',
      type: DiscoverySourceType.developmentOrganization,
      searchQuery: 'water infrastructure',
      endpointUrl: 'https://example.com/feed',
      enabled: false,
      lastRunAt: lastRunAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final map = source.toMap();
    final restored = DiscoverySource.fromMap(source.id, map);

    expect(restored.name, source.name);
    expect(restored.type, DiscoverySourceType.developmentOrganization);
    expect(restored.searchQuery, source.searchQuery);
    expect(restored.endpointUrl, source.endpointUrl);
    expect(restored.enabled, isFalse);
    expect(restored.lastRunAt?.toUtc(), lastRunAt.toUtc());
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
    expect(restored.updatedAt.toUtc(), updatedAt.toUtc());
  });

  test(
    'DiscoverySource defaults enabled to true and lastRunAt/searchQuery/endpointUrl to null when missing',
    () {
      final now = DateTime.utc(2024, 8, 1);
      final restored = DiscoverySource.fromMap('source-2', {
        'name': 'UN procurement',
        'type': 'unProcurement',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(restored.type, DiscoverySourceType.unProcurement);
      expect(restored.searchQuery, isNull);
      expect(restored.endpointUrl, isNull);
      expect(restored.enabled, isTrue);
      expect(restored.lastRunAt, isNull);
    },
  );

  test('DiscoverySourceType falls back to manual for an unknown value', () {
    expect(
      DiscoverySourceTypeX.fromString('something-unknown'),
      DiscoverySourceType.manual,
    );
  });
}
