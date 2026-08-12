import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// A single immutable entry in an opportunity's pipeline history — one row
/// per stage transition, written automatically by
/// `OpportunityService.transitionStage`. Never updated or deleted once
/// created; the `opportunityEvents` collection is an append-only audit log,
/// not an editable entity like the rest of Company Intelligence.
class OpportunityEvent {
  final String id;
  final String opportunityId;
  final OpportunityPipelineStage stage;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? createdBy;

  /// Flexible, unstructured extra data — currently just
  /// `{'fromStage': ..., 'toStage': ...}` written by every transition, but
  /// deliberately a free-form map (rather than typed fields) so future
  /// event producers (e.g. an AI classification pass logging its own
  /// events) can attach whatever context they need without a schema change.
  final Map<String, dynamic> metadata;

  const OpportunityEvent({
    required this.id,
    required this.opportunityId,
    required this.stage,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.createdBy,
    this.metadata = const {},
  });

  factory OpportunityEvent.fromMap(String id, Map<String, dynamic> map) {
    return OpportunityEvent(
      id: id,
      opportunityId: map['opportunityId'] as String? ?? '',
      stage: OpportunityPipelineStageX.fromString(
        map['stage'] as String? ?? 'discovered',
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opportunityId': opportunityId,
      'stage': stage.name,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }
}
