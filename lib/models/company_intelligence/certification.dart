import 'package:cloud_firestore/cloud_firestore.dart';

/// What kind of company-level eligibility credential this is. Deliberately
/// separate from [DocumentCategory] on `LibraryDocument` — a certification
/// is the company-level *fact* of holding a credential (e.g. "we are NCA
/// class 5"); a `LibraryDocument` is the supporting file evidencing it, and
/// is linked optionally via [Certification.documentId], never merged into
/// one entity.
enum CertificationType {
  nca,
  tax,
  agpo,
  iso,
  businessPermit,
  professionalLicense,
  other,
}

extension CertificationTypeX on CertificationType {
  String get label => switch (this) {
    CertificationType.nca => 'NCA Registration',
    CertificationType.tax => 'Tax Compliance',
    CertificationType.agpo => 'AGPO',
    CertificationType.iso => 'ISO Certification',
    CertificationType.businessPermit => 'Business Permit',
    CertificationType.professionalLicense => 'Professional License',
    CertificationType.other => 'Other',
  };

  static CertificationType fromString(String value) {
    return CertificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => CertificationType.other,
    );
  }
}

/// [status] is the human-recorded lifecycle state — separate from whether
/// the certificate has actually lapsed by date. A cert can be recorded
/// `active` and still be past its [Certification.expiryDate]; callers that
/// care about "does this genuinely still count" (e.g. the eligibility gap
/// engine) must check `isCurrentlyValid`, not just `status == active` — see
/// `certification_eligibility.dart`.
enum CertificationStatus { active, expired, revoked, pending }

extension CertificationStatusX on CertificationStatus {
  String get label => switch (this) {
    CertificationStatus.active => 'Active',
    CertificationStatus.expired => 'Expired',
    CertificationStatus.revoked => 'Revoked',
    CertificationStatus.pending => 'Pending',
  };

  static CertificationStatus fromString(String value) {
    return CertificationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CertificationStatus.active,
    );
  }
}

/// A company-level eligibility credential (NCA contractor grade, tax
/// compliance, AGPO, ISO, business permit, professional license, …) — org
/// eligibility, not a project delivery field. Never auto-created from
/// project document extraction (`aiExtractedCertifications` on
/// `LibraryDocument` stays narrative-only, per the Phase 1 boundary); only
/// ever entered here by a human who actually holds the credential.
class Certification {
  final String id;
  final String name;
  final CertificationType type;

  /// Free-text grade/class (e.g. "5", "7", "NCA5") — deliberately a string,
  /// not an int, since not every certification type has a numeric grade
  /// (tax compliance, AGPO, ISO don't). [certification_eligibility.dart]
  /// parses this when [type] is [CertificationType.nca].
  final String? gradeOrClass;
  final String? issuingBody;
  final String? certificateNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final CertificationStatus status;

  /// Optional link to the supporting `LibraryDocument` evidencing this
  /// certification (e.g. the scanned NCA certificate). Singular, matching
  /// `LibraryDocument.projectId`'s "one document, one thing it supports"
  /// convention — a certification with multiple supporting files would
  /// need multiple `LibraryDocument`s, each still pointing back here is not
  /// modeled since nothing in this codebase needs a reverse index yet.
  final String? documentId;

  final String notes;

  /// Stable identifier for a future idempotent seed (mirrors every other
  /// Company Intelligence seed's `seedKey` convention) — unused by any seed
  /// today; reserved so one can be added later without a schema change.
  final String? seedKey;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Certification({
    required this.id,
    required this.name,
    required this.type,
    this.gradeOrClass,
    this.issuingBody,
    this.certificateNumber,
    this.issueDate,
    this.expiryDate,
    this.status = CertificationStatus.active,
    this.documentId,
    this.notes = '',
    this.seedKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Certification.fromMap(String id, Map<String, dynamic> map) {
    return Certification(
      id: id,
      name: map['name'] as String? ?? '',
      type: CertificationTypeX.fromString(map['type'] as String? ?? 'other'),
      gradeOrClass: map['gradeOrClass'] as String?,
      issuingBody: map['issuingBody'] as String?,
      certificateNumber: map['certificateNumber'] as String?,
      issueDate: (map['issueDate'] as Timestamp?)?.toDate(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      status: CertificationStatusX.fromString(
        map['status'] as String? ?? 'active',
      ),
      documentId: map['documentId'] as String?,
      notes: map['notes'] as String? ?? '',
      seedKey: map['seedKey'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'gradeOrClass': gradeOrClass,
      'issuingBody': issuingBody,
      'certificateNumber': certificateNumber,
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'status': status.name,
      'documentId': documentId,
      'notes': notes,
      'seedKey': seedKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Certification copyWith({
    String? name,
    CertificationType? type,
    String? gradeOrClass,
    String? issuingBody,
    String? certificateNumber,
    DateTime? issueDate,
    bool clearIssueDate = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    CertificationStatus? status,
    String? documentId,
    bool clearDocumentId = false,
    String? notes,
  }) {
    return Certification(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      gradeOrClass: gradeOrClass ?? this.gradeOrClass,
      issuingBody: issuingBody ?? this.issuingBody,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      issueDate: clearIssueDate ? null : (issueDate ?? this.issueDate),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      status: status ?? this.status,
      documentId: clearDocumentId ? null : (documentId ?? this.documentId),
      notes: notes ?? this.notes,
      seedKey: seedKey,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
