import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// A configured external opportunity source — see the Opportunity Discovery
/// Engine (Milestone 3.7). Which [DiscoverySourceType]s actually have a
/// working automated adapter is a server-side concern
/// (`functions/index.js`'s `DISCOVERY_ADAPTERS` registry); a source can be
/// created here for any type even before its adapter exists, so the UI can
/// exercise the full architecture ahead of every integration being built.
class DiscoverySource {
  final String id;
  final String name;
  final DiscoverySourceType type;

  /// Free-text hint fed into the AI search prompt for the "searchable"
  /// source types (government/development/UN/NGO/private-sector). Unused by
  /// `rss`/`api`/`manual`.
  final String? searchQuery;

  /// Reserved for future `rss`/`api` adapters — unused by
  /// `runAiWebSearchAdapter` today.
  final String? endpointUrl;
  final bool enabled;
  final DateTime? lastRunAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiscoverySource({
    required this.id,
    required this.name,
    required this.type,
    this.searchQuery,
    this.endpointUrl,
    this.enabled = true,
    this.lastRunAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiscoverySource.fromMap(String id, Map<String, dynamic> map) {
    return DiscoverySource(
      id: id,
      name: map['name'] as String? ?? '',
      type: DiscoverySourceTypeX.fromString(map['type'] as String? ?? 'manual'),
      searchQuery: map['searchQuery'] as String?,
      endpointUrl: map['endpointUrl'] as String?,
      enabled: map['enabled'] as bool? ?? true,
      lastRunAt: (map['lastRunAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'searchQuery': searchQuery,
      'endpointUrl': endpointUrl,
      'enabled': enabled,
      'lastRunAt': lastRunAt != null ? Timestamp.fromDate(lastRunAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
