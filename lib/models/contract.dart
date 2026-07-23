import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractStatus { discovered, reviewing, applied, won, lost, dismissed }

extension ContractStatusX on ContractStatus {
  String get label => switch (this) {
    ContractStatus.discovered => 'Discovered',
    ContractStatus.reviewing => 'Reviewing',
    ContractStatus.applied => 'Applied',
    ContractStatus.won => 'Won',
    ContractStatus.lost => 'Lost',
    ContractStatus.dismissed => 'Dismissed',
  };

  static ContractStatus fromString(String value) {
    return ContractStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ContractStatus.discovered,
    );
  }
}

/// A contract/tender opportunity discovered via automated web search,
/// scored against the company's project & application history.
class Contract {
  final String id;
  final String title;
  final String description;
  final String sourceUrl;
  final String? client;
  final DateTime? deadline;
  final ContractStatus status;

  /// 0-100 estimated fit, produced by the Gemini scoring pipeline.
  final int fitScorePercent;
  final String fitReasoning;

  final List<String> tags;
  final DateTime discoveredAt;
  final DateTime updatedAt;

  const Contract({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceUrl,
    this.client,
    this.deadline,
    this.status = ContractStatus.discovered,
    this.fitScorePercent = 0,
    this.fitReasoning = '',
    this.tags = const [],
    required this.discoveredAt,
    required this.updatedAt,
  });

  factory Contract.fromMap(String id, Map<String, dynamic> map) {
    return Contract(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String? ?? '',
      client: map['client'] as String?,
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      status: ContractStatusX.fromString(
        map['status'] as String? ?? 'discovered',
      ),
      fitScorePercent: (map['fitScorePercent'] as num?)?.toInt() ?? 0,
      fitReasoning: map['fitReasoning'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      discoveredAt:
          (map['discoveredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'sourceUrl': sourceUrl,
      'client': client,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'status': status.name,
      'fitScorePercent': fitScorePercent,
      'fitReasoning': fitReasoning,
      'tags': tags,
      'discoveredAt': Timestamp.fromDate(discoveredAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
