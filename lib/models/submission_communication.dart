import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of client-facing interaction tracked against a [Submission].
enum CommunicationType { meeting, email, clarification, addendum, reminder }

extension CommunicationTypeX on CommunicationType {
  String get label => switch (this) {
    CommunicationType.meeting => 'Meeting',
    CommunicationType.email => 'Email',
    CommunicationType.clarification => 'Clarification',
    CommunicationType.addendum => 'Addendum',
    CommunicationType.reminder => 'Reminder',
  };

  static CommunicationType fromString(String value) {
    return CommunicationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => CommunicationType.email,
    );
  }
}

/// One logged client interaction — meeting, email, clarification request,
/// addendum, or reminder — against a [Submission]. Its own collection
/// (`submissionCommunications`), keyed by `submissionId`, rather than an
/// embedded list on [Submission] itself, per this project's "never embed
/// entire objects" rule (same shape as [ProposalSection] vs [Proposal]).
/// [date] doubles as "when this happened" for past entries and "when this
/// is due" for a [CommunicationType.reminder] — whether it's still upcoming
/// is derived (`date.isAfter(now)`), not a separately stored flag.
class SubmissionCommunication {
  final String id;
  final String submissionId;
  final CommunicationType type;
  final String subject;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  const SubmissionCommunication({
    required this.id,
    required this.submissionId,
    required this.type,
    required this.subject,
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory SubmissionCommunication.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionCommunication(
      id: id,
      submissionId: map['submissionId'] as String? ?? '',
      type: CommunicationTypeX.fromString(map['type'] as String? ?? 'email'),
      subject: map['subject'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'submissionId': submissionId,
      'type': type.name,
      'subject': subject,
      'notes': notes,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
