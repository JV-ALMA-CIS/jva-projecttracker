import 'package:cloud_firestore/cloud_firestore.dart';

/// Descriptive classification of who the source represents. Deliberately
/// separate from [TenderDiscoveryMethod] — under the old `DiscoverySource`
/// model these were conflated into one enum (`rss`/`api` sat alongside
/// `governmentProcurement`/`ngo`/etc.), which meant the connector registry
/// couldn't be keyed cleanly. See ADR — Tender Source Connector Abstraction.
enum TenderSourceCategory {
  governmentAgency,
  countyGovernment,
  developmentPartner,
  unAgency,
  ngo,
  privateSector,
  customEnterprise,
}

/// The connector dispatch key. This — not [TenderSourceCategory] — is what
/// `TENDER_CONNECTORS` in Cloud Functions is keyed by. Adding a new fetch
/// mechanism means adding one value here, one connector class, and one
/// registry line; it never requires touching `runTenderSourceSync`.
enum TenderDiscoveryMethod { api, rss, htmlScraping, email, manual }

/// Operational status, distinct from [enabled]. `enabled` is the
/// administrator's on/off switch; [status] reflects observed health
/// (derived server-side from recent sync outcomes) and is informational —
/// the client never sets `offline`/`error` directly.
enum TenderSourceStatus { active, paused, offline, error }

/// English fallback labels — [AppStrings] enum-label getters return these
/// directly when the active locale isn't Italian, matching every other
/// enum in this codebase (e.g. `DiscoverySourceType.label`).
extension TenderSourceCategoryLabel on TenderSourceCategory {
  String get label => switch (this) {
    TenderSourceCategory.governmentAgency => 'Government Agency',
    TenderSourceCategory.countyGovernment => 'County Government',
    TenderSourceCategory.developmentPartner => 'Development Partner',
    TenderSourceCategory.unAgency => 'UN Agency',
    TenderSourceCategory.ngo => 'NGO',
    TenderSourceCategory.privateSector => 'Private Sector',
    TenderSourceCategory.customEnterprise => 'Custom Enterprise',
  };
}

extension TenderDiscoveryMethodLabel on TenderDiscoveryMethod {
  String get label => switch (this) {
    TenderDiscoveryMethod.api => 'API',
    TenderDiscoveryMethod.rss => 'RSS Feed',
    TenderDiscoveryMethod.htmlScraping => 'HTML Scraping',
    TenderDiscoveryMethod.email => 'Email Inbox',
    TenderDiscoveryMethod.manual => 'Manual Import',
  };
}

extension TenderSourceStatusLabel on TenderSourceStatus {
  String get label => switch (this) {
    TenderSourceStatus.active => 'Active',
    TenderSourceStatus.paused => 'Paused',
    TenderSourceStatus.offline => 'Offline',
    TenderSourceStatus.error => 'Error',
  };
}

TenderSourceCategory _categoryFromName(String? name) =>
    TenderSourceCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TenderSourceCategory.customEnterprise,
    );

TenderDiscoveryMethod _methodFromName(String? name) =>
    TenderDiscoveryMethod.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TenderDiscoveryMethod.manual,
    );

TenderSourceStatus _statusFromName(String? name) => TenderSourceStatus.values
    .firstWhere((e) => e.name == name, orElse: () => TenderSourceStatus.active);

DateTime? _dateFromTimestamp(Object? value) =>
    value is Timestamp ? value.toDate() : null;

/// A configured procurement source the Discovery Engine monitors.
///
/// [connectorConfig] holds method-specific settings the relevant connector
/// reads (e.g. `rssUrl` for [TenderDiscoveryMethod.rss], `endpointUrl` +
/// `fieldMap` for [TenderDiscoveryMethod.api], `pageUrl` + `selectors` for
/// [TenderDiscoveryMethod.htmlScraping]). [authConfig] never stores raw
/// secrets — only an auth `type` and a Secret Manager secret *name*, the
/// same pattern already used for the NuaSense proxy.
class TenderSource {
  const TenderSource({
    required this.id,
    required this.name,
    required this.organization,
    required this.category,
    required this.discoveryMethod,
    this.country,
    this.website,
    this.searchQuery,
    this.connectorConfig = const {},
    this.authConfig = const {},
    this.status = TenderSourceStatus.active,
    this.enabled = true,
    this.syncFrequencyMinutes = 1440,
    this.lastSyncAt,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastErrorMessage,
    this.healthScore = 100,
    this.aiQualityScore,
    this.historicalWinRatePercent,
    this.opportunitiesImported = 0,
    this.opportunitiesPursued = 0,
    this.wins = 0,
    this.losses = 0,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String organization;
  final TenderSourceCategory category;
  final TenderDiscoveryMethod discoveryMethod;
  final String? country;
  final String? website;

  /// Free-text targeting used by [TenderDiscoveryMethod.api] when running
  /// in AI-search mode (the historical behavior for the 5 "searchable"
  /// categories) — see `connectorConfig['mode']`.
  final String? searchQuery;

  final Map<String, dynamic> connectorConfig;
  final Map<String, dynamic> authConfig;

  final TenderSourceStatus status;
  final bool enabled;

  /// Minimum minutes between scheduled syncs. Checked by
  /// `scheduledTenderSourceSync` against [lastSyncAt]; a manual "Run now"
  /// ignores this.
  final int syncFrequencyMinutes;

  final DateTime? lastSyncAt;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastErrorMessage;

  /// 0-100, derived server-side from recent run success rate.
  final int healthScore;

  /// 0-100, AI-estimated quality of opportunities this source produces —
  /// distinct from [healthScore] (uptime/reliability) and updated by
  /// analytics (Milestone 3.8d), not by the sync itself.
  final int? aiQualityScore;
  final double? historicalWinRatePercent;

  final int opportunitiesImported;
  final int opportunitiesPursued;
  final int wins;
  final int losses;

  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TenderSource.fromMap(String id, Map<String, dynamic> data) {
    return TenderSource(
      id: id,
      name: data['name'] as String? ?? '',
      organization: data['organization'] as String? ?? '',
      category: _categoryFromName(data['category'] as String?),
      discoveryMethod: _methodFromName(data['discoveryMethod'] as String?),
      country: data['country'] as String?,
      website: data['website'] as String?,
      searchQuery: data['searchQuery'] as String?,
      connectorConfig: Map<String, dynamic>.from(
        data['connectorConfig'] as Map? ?? {},
      ),
      authConfig: Map<String, dynamic>.from(data['authConfig'] as Map? ?? {}),
      status: _statusFromName(data['status'] as String?),
      enabled: data['enabled'] as bool? ?? true,
      syncFrequencyMinutes: data['syncFrequencyMinutes'] as int? ?? 1440,
      lastSyncAt: _dateFromTimestamp(data['lastSyncAt']),
      lastSuccessAt: _dateFromTimestamp(data['lastSuccessAt']),
      lastFailureAt: _dateFromTimestamp(data['lastFailureAt']),
      lastErrorMessage: data['lastErrorMessage'] as String?,
      healthScore: data['healthScore'] as int? ?? 100,
      aiQualityScore: data['aiQualityScore'] as int?,
      historicalWinRatePercent: (data['historicalWinRatePercent'] as num?)
          ?.toDouble(),
      opportunitiesImported: data['opportunitiesImported'] as int? ?? 0,
      opportunitiesPursued: data['opportunitiesPursued'] as int? ?? 0,
      wins: data['wins'] as int? ?? 0,
      losses: data['losses'] as int? ?? 0,
      tags: List<String>.from(data['tags'] as List? ?? const []),
      createdAt: _dateFromTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'organization': organization,
    'category': category.name,
    'discoveryMethod': discoveryMethod.name,
    'country': country,
    'website': website,
    'searchQuery': searchQuery,
    'connectorConfig': connectorConfig,
    'authConfig': authConfig,
    'status': status.name,
    'enabled': enabled,
    'syncFrequencyMinutes': syncFrequencyMinutes,
    'lastSyncAt': lastSyncAt == null ? null : Timestamp.fromDate(lastSyncAt!),
    'lastSuccessAt': lastSuccessAt == null
        ? null
        : Timestamp.fromDate(lastSuccessAt!),
    'lastFailureAt': lastFailureAt == null
        ? null
        : Timestamp.fromDate(lastFailureAt!),
    'lastErrorMessage': lastErrorMessage,
    'healthScore': healthScore,
    'aiQualityScore': aiQualityScore,
    'historicalWinRatePercent': historicalWinRatePercent,
    'opportunitiesImported': opportunitiesImported,
    'opportunitiesPursued': opportunitiesPursued,
    'wins': wins,
    'losses': losses,
    'tags': tags,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  TenderSource copyWith({
    String? name,
    String? organization,
    TenderSourceCategory? category,
    TenderDiscoveryMethod? discoveryMethod,
    String? country,
    String? website,
    String? searchQuery,
    Map<String, dynamic>? connectorConfig,
    Map<String, dynamic>? authConfig,
    TenderSourceStatus? status,
    bool? enabled,
    int? syncFrequencyMinutes,
    DateTime? lastSyncAt,
    DateTime? lastSuccessAt,
    DateTime? lastFailureAt,
    String? lastErrorMessage,
    int? healthScore,
    int? aiQualityScore,
    double? historicalWinRatePercent,
    int? opportunitiesImported,
    int? opportunitiesPursued,
    int? wins,
    int? losses,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return TenderSource(
      id: id,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      category: category ?? this.category,
      discoveryMethod: discoveryMethod ?? this.discoveryMethod,
      country: country ?? this.country,
      website: website ?? this.website,
      searchQuery: searchQuery ?? this.searchQuery,
      connectorConfig: connectorConfig ?? this.connectorConfig,
      authConfig: authConfig ?? this.authConfig,
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      syncFrequencyMinutes: syncFrequencyMinutes ?? this.syncFrequencyMinutes,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      healthScore: healthScore ?? this.healthScore,
      aiQualityScore: aiQualityScore ?? this.aiQualityScore,
      historicalWinRatePercent:
          historicalWinRatePercent ?? this.historicalWinRatePercent,
      opportunitiesImported:
          opportunitiesImported ?? this.opportunitiesImported,
      opportunitiesPursued: opportunitiesPursued ?? this.opportunitiesPursued,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
