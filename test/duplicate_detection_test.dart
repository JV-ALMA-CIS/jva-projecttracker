import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/duplicate_detection.dart';

Opportunity _opportunity({
  required String id,
  required String title,
  String? client,
  required DateTime discoveredAt,
}) {
  return Opportunity(
    id: id,
    title: title,
    description: '',
    sourceUrl: 'https://example.com/$id',
    client: client,
    discoveredAt: discoveredAt,
    updatedAt: discoveredAt,
  );
}

void main() {
  test(
    'normalizeTitle lowercases, strips punctuation, and collapses whitespace',
    () {
      expect(normalizeTitle('Rural  Water   Tender!!'), 'rural water tender');
    },
  );

  test(
    'titleTokenOverlap is 1.0 for identical titles and 0 for disjoint ones',
    () {
      expect(
        titleTokenOverlap('Rural water tender', 'Rural water tender'),
        1.0,
      );
      expect(titleTokenOverlap('Rural water tender', 'Urban road bridge'), 0.0);
    },
  );

  test('flags an exact normalized-title match as a duplicate', () {
    final original = _opportunity(
      id: 'a',
      title: 'Rural Water Tender',
      discoveredAt: DateTime.utc(2024, 1, 1),
    );
    final duplicate = _opportunity(
      id: 'b',
      title: 'rural water tender!',
      discoveredAt: DateTime.utc(2024, 2, 1),
    );

    final result = findPossibleDuplicates([original, duplicate]);

    expect(result['b'], original);
    expect(result.containsKey('a'), isFalse);
  });

  test(
    'flags a shared-client + overlapping-title pair even with different titles',
    () {
      final original = _opportunity(
        id: 'a',
        title: 'Rural water network rehabilitation',
        client: 'Ministry of Water',
        discoveredAt: DateTime.utc(2024, 1, 1),
      );
      final duplicate = _opportunity(
        id: 'b',
        title: 'Rural water network rehabilitation project',
        client: 'Ministry of Water',
        discoveredAt: DateTime.utc(2024, 2, 1),
      );

      final result = findPossibleDuplicates([original, duplicate]);

      expect(result['b'], original);
    },
  );

  test('does not flag genuinely different opportunities', () {
    final a = _opportunity(
      id: 'a',
      title: 'Rural water network rehabilitation',
      client: 'Ministry of Water',
      discoveredAt: DateTime.utc(2024, 1, 1),
    );
    final b = _opportunity(
      id: 'b',
      title: 'Urban road bridge construction',
      client: 'Ministry of Transport',
      discoveredAt: DateTime.utc(2024, 2, 1),
    );

    final result = findPossibleDuplicates([a, b]);

    expect(result, isEmpty);
  });

  test(
    'points every later duplicate at the single earliest-discovered original',
    () {
      final original = _opportunity(
        id: 'a',
        title: 'Rural water tender',
        discoveredAt: DateTime.utc(2024, 1, 1),
      );
      final middle = _opportunity(
        id: 'b',
        title: 'Rural water tender',
        discoveredAt: DateTime.utc(2024, 2, 1),
      );
      final latest = _opportunity(
        id: 'c',
        title: 'Rural water tender',
        discoveredAt: DateTime.utc(2024, 3, 1),
      );

      final result = findPossibleDuplicates([latest, original, middle]);

      expect(result['b'], original);
      expect(result['c'], original);
      expect(result.containsKey('a'), isFalse);
    },
  );
}
