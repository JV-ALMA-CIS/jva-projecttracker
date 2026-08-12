import 'package:jva_projecttracker/models/library_document.dart';

/// Which [DocumentCategory] values are mandatory for a proposal to be
/// submission-ready. A deliberately simple, fixed default — nothing in this
/// app models tender-specific document requirements yet. Flagged as a
/// follow-up recommendation (make this configurable), not a blocker, in the
/// Document Library milestone report.
const kRequiredDocumentCategories = {
  DocumentCategory.companyRegistration,
  DocumentCategory.taxCertificate,
  DocumentCategory.license,
  DocumentCategory.insurance,
  DocumentCategory.financialStatement,
};

/// A proposal's document-based submission readiness — see the Document
/// Library (Milestone 4.3). [isReady] is true only when every required
/// category has at least one active, unexpired document linked.
class SubmissionReadiness {
  const SubmissionReadiness({
    required this.isReady,
    required this.requiredCategories,
    required this.uploadedCategories,
    required this.missingCategories,
    required this.expiredDocuments,
    required this.pendingReviewDocuments,
    required this.needsUpdateDocuments,
  });

  final bool isReady;
  final Set<DocumentCategory> requiredCategories;
  final Set<DocumentCategory> uploadedCategories;
  final Set<DocumentCategory> missingCategories;
  final List<LibraryDocument> expiredDocuments;
  final List<LibraryDocument> pendingReviewDocuments;
  final List<LibraryDocument> needsUpdateDocuments;
}

/// Derives [SubmissionReadiness] purely from the documents already linked
/// to a proposal ([proposalDocuments]) — no new Firestore reads. "Expired"
/// is always computed from `expiryDate` vs [now], never read from a stored
/// field (see [LibraryDocument]'s own doc comment on [DocumentStatus]).
SubmissionReadiness deriveSubmissionReadiness({
  required List<LibraryDocument> proposalDocuments,
  required DateTime now,
}) {
  final expired = proposalDocuments
      .where((d) => d.expiryDate != null && d.expiryDate!.isBefore(now))
      .toList();
  final expiredIds = expired.map((d) => d.id).toSet();

  final pendingReview = proposalDocuments
      .where((d) => d.status == DocumentStatus.pendingReview)
      .toList();
  final needsUpdate = proposalDocuments
      .where((d) => d.status == DocumentStatus.needsUpdate)
      .toList();

  final validCoverage = proposalDocuments.where(
    (d) => d.status != DocumentStatus.archived && !expiredIds.contains(d.id),
  );
  final uploadedCategories = validCoverage.map((d) => d.category).toSet();
  final missingCategories = kRequiredDocumentCategories.difference(
    uploadedCategories,
  );

  return SubmissionReadiness(
    isReady: missingCategories.isEmpty,
    requiredCategories: kRequiredDocumentCategories,
    uploadedCategories: uploadedCategories,
    missingCategories: missingCategories,
    expiredDocuments: expired,
    pendingReviewDocuments: pendingReview,
    needsUpdateDocuments: needsUpdate,
  );
}
