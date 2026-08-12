import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/tender_source.dart';

enum TenderSyncRunStatus { running, completed, failed }

enum TenderSyncTrigger { manual, scheduled }

extension TenderSyncRunStatusLabel on TenderSyncRunStatus {
  String get label => switch (this) {
    TenderSyncRunStatus.running => 'Running',
    TenderSyncRunStatus.completed => 'Completed',
    TenderSyncRunStatus.failed => 'Failed',
  };
}

extension TenderSyncTriggerLabel on TenderSyncTrigger {
  String get label => switch (this) {
    TenderSyncTrigger.manual => 'Manual',
    TenderSyncTrigger.scheduled => 'Scheduled',
  };
}

TenderSyncRunStatus _statusFromName(String? name) =>
    TenderSyncRunStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TenderSyncRunStatus.failed,
    );

TenderSyncTrigger _triggerFromName(String? name) => TenderSyncTrigger.values
    .firstWhere((e) => e.name == name, orElse: () => TenderSyncTrigger.manual);

TenderDiscoveryMethod _methodFromName(String? name) =>
    TenderDiscoveryMethod.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TenderDiscoveryMethod.manual,
    );

DateTime? _dateFromTimestamp(Object? value) =>
    value is Timestamp ? value.toDate() : null;

/// Audit-trail document for one connector invocation, written by
/// `runTenderSourceSync`. Mirrors the existing `DiscoveryRun` shape/lifecycle
/// (`running` -> `completed`/`failed`) so the Discovery History UX pattern
/// carries over unchanged onto the `tenderSyncRuns` collection.
class TenderSyncRun {
  const TenderSyncRun({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.discoveryMethod,
    required this.status,
    required this.trigger,
    required this.startedAt,
    this.completedAt,
    this.candidatesFound = 0,
    this.opportunitiesCreated = 0,
    this.duplicatesSkipped = 0,
    this.errorMessage,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final TenderDiscoveryMethod discoveryMethod;
  final TenderSyncRunStatus status;
  final TenderSyncTrigger trigger;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int candidatesFound;
  final int opportunitiesCreated;
  final int duplicatesSkipped;
  final String? errorMessage;

  factory TenderSyncRun.fromMap(String id, Map<String, dynamic> data) {
    return TenderSyncRun(
      id: id,
      sourceId: data['sourceId'] as String? ?? '',
      sourceName: data['sourceName'] as String? ?? '',
      discoveryMethod: _methodFromName(data['discoveryMethod'] as String?),
      status: _statusFromName(data['status'] as String?),
      trigger: _triggerFromName(data['trigger'] as String?),
      startedAt: _dateFromTimestamp(data['startedAt']) ?? DateTime.now(),
      completedAt: _dateFromTimestamp(data['completedAt']),
      candidatesFound: data['candidatesFound'] as int? ?? 0,
      opportunitiesCreated: data['opportunitiesCreated'] as int? ?? 0,
      duplicatesSkipped: data['duplicatesSkipped'] as int? ?? 0,
      errorMessage: data['errorMessage'] as String?,
    );
  }
}
