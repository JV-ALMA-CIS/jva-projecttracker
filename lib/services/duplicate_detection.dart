import 'package:jva_projecttracker/models/opportunity.dart';

/// Lowercases [title], strips punctuation, and collapses whitespace runs —
/// the normalization used for exact-title duplicate matching.
String normalizeTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Jaccard similarity (intersection / union) of the two titles' word sets,
/// after [normalizeTitle]. `0` if either title is empty.
double titleTokenOverlap(String a, String b) {
  final tokensA = normalizeTitle(
    a,
  ).split(' ').where((t) => t.isNotEmpty).toSet();
  final tokensB = normalizeTitle(
    b,
  ).split(' ').where((t) => t.isNotEmpty).toSet();
  if (tokensA.isEmpty || tokensB.isEmpty) return 0;

  final intersection = tokensA.intersection(tokensB).length;
  final union = tokensA.union(tokensB).length;
  return intersection / union;
}

const _kTitleOverlapThreshold = 0.5;

bool _looksLikeDuplicate(Opportunity a, Opportunity b) {
  final normalizedA = normalizeTitle(a.title);
  final normalizedB = normalizeTitle(b.title);
  if (normalizedA.isNotEmpty && normalizedA == normalizedB) return true;

  final clientA = a.client?.trim().toLowerCase();
  final clientB = b.client?.trim().toLowerCase();
  final sameClient =
      clientA != null && clientA.isNotEmpty && clientA == clientB;
  if (!sameClient) return false;

  return titleTokenOverlap(a.title, b.title) >= _kTitleOverlapThreshold;
}

/// For every opportunity in [all], finds the earliest-discovered *other*
/// opportunity it looks like a duplicate of (same normalized title, or
/// shared non-empty client + significant title word-overlap). Only ever
/// points a later-discovered opportunity at an earlier one — the earliest
/// opportunity in a duplicate cluster is treated as the "original" and never
/// flagged against itself. Pure, Firestore-free, and safe to call on every
/// rebuild of `opportunityDuplicatesProvider`.
Map<String, Opportunity> findPossibleDuplicates(List<Opportunity> all) {
  final result = <String, Opportunity>{};

  for (final candidate in all) {
    Opportunity? earliestMatch;

    for (final other in all) {
      if (other.id == candidate.id) continue;
      if (!_looksLikeDuplicate(candidate, other)) continue;

      final otherIsEarlier =
          other.discoveredAt.isBefore(candidate.discoveredAt) ||
          (other.discoveredAt.isAtSameMomentAs(candidate.discoveredAt) &&
              other.id.compareTo(candidate.id) < 0);
      if (!otherIsEarlier) continue;

      if (earliestMatch == null ||
          other.discoveredAt.isBefore(earliestMatch.discoveredAt)) {
        earliestMatch = other;
      }
    }

    if (earliestMatch != null) {
      result[candidate.id] = earliestMatch;
    }
  }

  return result;
}
