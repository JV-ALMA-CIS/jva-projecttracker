import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/services/submission_readiness.dart';

/// Which kind of gap or opportunity a [DocumentSuggestion] flags.
enum DocumentSuggestionCategory {
  missingMandatoryDocument,
  expiringCertificate,
  similarPreviousProposal,
  relevantTechnicalBrochure,
  recommendedExperienceDocument,
}

/// One suggestion for a proposal's Submission Readiness card. Carries only
/// structured data, never a pre-formatted sentence — the app's own chrome
/// text (including "why" reasons) is always assembled by
/// `AppStrings.documentSuggestionReason`, never hardcoded in this pure
/// derivation layer. [documentTitle] (an entity's own name/title, never
/// translated — same rule as every other entity name in this app) is set
/// for every category except [DocumentSuggestionCategory.missingMandatoryDocument],
/// which instead sets [missingCategory] (a fixed enum needing its own
/// localized label). [daysUntilExpiry] is set only for
/// [DocumentSuggestionCategory.expiringCertificate].
class DocumentSuggestion {
  const DocumentSuggestion({
    required this.category,
    this.documentTitle,
    this.missingCategory,
    this.daysUntilExpiry,
  });

  final DocumentSuggestionCategory category;
  final String? documentTitle;
  final DocumentCategory? missingCategory;
  final int? daysUntilExpiry;
}

const _kExpiryWarningDays = 30;
const _kMaxSuggestions = 8;

bool _isActiveAndUnexpired(LibraryDocument doc, DateTime now) {
  if (doc.status == DocumentStatus.archived) return false;
  if (doc.expiryDate != null && doc.expiryDate!.isBefore(now)) return false;
  return true;
}

/// Derives contextual document suggestions for one proposal — pure
/// set-differences and date comparisons over data already loaded elsewhere
/// (the opportunity's own classification IDs, the company-wide document
/// library, and the documents already linked to this proposal). No new
/// Firestore reads, no AI call — see the Document Library (Milestone 4.3)
/// Decision 6.
List<DocumentSuggestion> deriveDocumentSuggestions({
  required Opportunity opportunity,
  required Proposal proposal,
  required List<LibraryDocument> allDocuments,
  required List<LibraryDocument> linkedDocuments,
  required DateTime now,
}) {
  final suggestions = <DocumentSuggestion>[];
  final linkedIds = linkedDocuments.map((d) => d.id).toSet();
  final coveredCategories = linkedDocuments
      .where((d) => _isActiveAndUnexpired(d, now))
      .map((d) => d.category)
      .toSet();

  for (final category in kRequiredDocumentCategories.difference(
    coveredCategories,
  )) {
    suggestions.add(
      DocumentSuggestion(
        category: DocumentSuggestionCategory.missingMandatoryDocument,
        missingCategory: category,
      ),
    );
  }

  for (final doc in linkedDocuments) {
    final expiry = doc.expiryDate;
    if (expiry == null) continue;
    final daysLeft = expiry.difference(now).inDays;
    if (daysLeft >= 0 && daysLeft <= _kExpiryWarningDays) {
      suggestions.add(
        DocumentSuggestion(
          category: DocumentSuggestionCategory.expiringCertificate,
          documentTitle: doc.title,
          daysUntilExpiry: daysLeft,
        ),
      );
    }
  }

  for (final doc in allDocuments) {
    if (linkedIds.contains(doc.id) || doc.status == DocumentStatus.archived) {
      continue;
    }

    if (doc.category == DocumentCategory.technicalBrochure &&
        doc.technologyIds.any(opportunity.technologyIds.contains)) {
      suggestions.add(
        DocumentSuggestion(
          category: DocumentSuggestionCategory.relevantTechnicalBrochure,
          documentTitle: doc.title,
        ),
      );
    }

    if (doc.category == DocumentCategory.previousProjectEvidence &&
        doc.experienceIds.any(opportunity.experienceIds.contains)) {
      suggestions.add(
        DocumentSuggestion(
          category: DocumentSuggestionCategory.recommendedExperienceDocument,
          documentTitle: doc.title,
        ),
      );
    }

    if (doc.relatedProposalIds.isNotEmpty &&
        !doc.relatedProposalIds.contains(proposal.id) &&
        doc.industryIds.any(opportunity.industryIds.contains)) {
      suggestions.add(
        DocumentSuggestion(
          category: DocumentSuggestionCategory.similarPreviousProposal,
          documentTitle: doc.title,
        ),
      );
    }
  }

  return suggestions.take(_kMaxSuggestions).toList();
}
