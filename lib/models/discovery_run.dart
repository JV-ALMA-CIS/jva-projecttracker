import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

enum DiscoveryRunStatus { running, completed, failed }

extension DiscoveryRunStatusX on DiscoveryRunStatus {
  String get label => switch (this) {
    DiscoveryRunStatus.running => 'Running',
    DiscoveryRunStatus.completed => 'Completed',
    DiscoveryRunStatus.failed => 'Failed',
  };

  static DiscoveryRunStatus fromString(String value) {
    return DiscoveryRunStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DiscoveryRunStatus.failed,
    );
  }
}

enum DiscoveryRunTrigger { manual, scheduled }

extension DiscoveryRunTriggerX on DiscoveryRunTrigger {
  String get label => switch (this) {
    DiscoveryRunTrigger.manual => 'Manual',
    DiscoveryRunTrigger.scheduled => 'Scheduled',
  };

  static DiscoveryRunTrigger fromString(String value) {
    return DiscoveryRunTrigger.values.firstWhere(
      (t) => t.name == value,
      orElse: () => DiscoveryRunTrigger.manual,
    );
  }
}

/// A single execution of a [DiscoverySource]'s adapter — the audit trail
/// behind the Discovery History screen. Written by the `runDiscoverySource`
/// Cloud Function, which bookends every attempt (including one that fails
/// because the source type has no automated adapter yet) with exactly one
/// terminal run doc, so no attempt is ever silently lost. See the
/// Opportunity Discovery Engine (Milestone 3.7).
///
/// [sourceName]/[sourceType] are denormalized from the [DiscoverySource] at
/// run time (same reasoning as [Recommendation] not joining back to
/// [Opportunity] for its title) so History renders without a join and keeps
/// showing what a since-deleted source was.
class DiscoveryRun {
  final String id;
  final String sourceId;
  final String sourceName;
  final DiscoverySourceType sourceType;
  final DiscoveryRunStatus status;
  final DiscoveryRunTrigger trigger;
  final int candidatesFound;
  final int opportunitiesCreated;
  final int duplicatesSkipped;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const DiscoveryRun({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    this.status = DiscoveryRunStatus.running,
    this.trigger = DiscoveryRunTrigger.manual,
    this.candidatesFound = 0,
    this.opportunitiesCreated = 0,
    this.duplicatesSkipped = 0,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  factory DiscoveryRun.fromMap(String id, Map<String, dynamic> map) {
    return DiscoveryRun(
      id: id,
      sourceId: map['sourceId'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? '',
      sourceType: DiscoverySourceTypeX.fromString(
        map['sourceType'] as String? ?? 'manual',
      ),
      status: DiscoveryRunStatusX.fromString(
        map['status'] as String? ?? 'failed',
      ),
      trigger: DiscoveryRunTriggerX.fromString(
        map['trigger'] as String? ?? 'manual',
      ),
      candidatesFound: (map['candidatesFound'] as num?)?.toInt() ?? 0,
      opportunitiesCreated: (map['opportunitiesCreated'] as num?)?.toInt() ?? 0,
      duplicatesSkipped: (map['duplicatesSkipped'] as num?)?.toInt() ?? 0,
      errorMessage: map['errorMessage'] as String?,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceId': sourceId,
      'sourceName': sourceName,
      'sourceType': sourceType.name,
      'status': status.name,
      'trigger': trigger.name,
      'candidatesFound': candidatesFound,
      'opportunitiesCreated': opportunitiesCreated,
      'duplicatesSkipped': duplicatesSkipped,
      'errorMessage': errorMessage,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }
}
