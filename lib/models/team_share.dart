import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// Someone in the office bringing an opportunity to everyone's attention
/// ("Share with team"), or announcing one they added by hand. Written only
/// by the `shareOpportunityWithTeam` Cloud Function (`teamShares`
/// collection); shown in everyone's Notifications tab.
class TeamShare {
  const TeamShare({
    required this.id,
    required this.opportunityId,
    required this.opportunityTitle,
    required this.kind,
    required this.sharedByUid,
    required this.sharedByName,
    required this.note,
    required this.justAdded,
    required this.createdAt,
  });

  final String id;
  final String opportunityId;
  final String opportunityTitle;
  final OpportunityKind kind;
  final String sharedByUid;
  final String sharedByName;

  /// Optional message from the sharer ("Boss, this fits our school work").
  final String note;

  /// True when this announces an opportunity the person just added by hand.
  final bool justAdded;
  final DateTime createdAt;

  factory TeamShare.fromMap(String id, Map<String, dynamic> map) {
    return TeamShare(
      id: id,
      opportunityId: map['opportunityId'] as String? ?? '',
      opportunityTitle: map['opportunityTitle'] as String? ?? '',
      kind: OpportunityKindX.fromString(map['kind'] as String?),
      sharedByUid: map['sharedByUid'] as String? ?? '',
      sharedByName: map['sharedByName'] as String? ?? '',
      note: map['note'] as String? ?? '',
      justAdded: map['justAdded'] as bool? ?? false,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
