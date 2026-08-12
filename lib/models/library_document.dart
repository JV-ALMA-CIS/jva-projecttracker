import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of supporting evidence a proposal may need to submit. See the
/// Document Library (Milestone 4.3).
enum DocumentCategory {
  companyRegistration,
  taxCertificate,
  license,
  technicalCertification,
  isoCertificate,
  insurance,
  cv,
  companyProfile,
  financialStatement,
  referenceLetter,
  previousProjectEvidence,
  technicalBrochure,
  other,
}

extension DocumentCategoryX on DocumentCategory {
  String get label => switch (this) {
    DocumentCategory.companyRegistration => 'Company Registration',
    DocumentCategory.taxCertificate => 'Tax Certificate',
    DocumentCategory.license => 'License',
    DocumentCategory.technicalCertification => 'Technical Certification',
    DocumentCategory.isoCertificate => 'ISO Certificate',
    DocumentCategory.insurance => 'Insurance',
    DocumentCategory.cv => 'CV',
    DocumentCategory.companyProfile => 'Company Profile',
    DocumentCategory.financialStatement => 'Financial Statement',
    DocumentCategory.referenceLetter => 'Reference Letter',
    DocumentCategory.previousProjectEvidence => 'Previous Project Evidence',
    DocumentCategory.technicalBrochure => 'Technical Brochure',
    DocumentCategory.other => 'Other',
  };

  static DocumentCategory fromString(String value) {
    return DocumentCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => DocumentCategory.other,
    );
  }
}

/// A document's own lifecycle state. `archived` aside, none of these imply
/// anything about [LibraryDocument.expiryDate] — "expired" is deliberately
/// never stored here; it's always derived from `expiryDate` vs now (see
/// `submission_readiness.dart`), so there's exactly one source of truth for
/// it.
enum DocumentStatus { active, pendingReview, needsUpdate, archived }

extension DocumentStatusX on DocumentStatus {
  String get label => switch (this) {
    DocumentStatus.active => 'Active',
    DocumentStatus.pendingReview => 'Pending Review',
    DocumentStatus.needsUpdate => 'Needs Update',
    DocumentStatus.archived => 'Archived',
  };

  static DocumentStatus fromString(String value) {
    return DocumentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DocumentStatus.active,
    );
  }
}

/// Where a document sits in the AI Knowledge Extraction flow (Upload →
/// Extract → Review → Approve). `extracted` means `extractProjectDocumentKnowledge`
/// has populated the `aiExtracted*` fields below and they're awaiting human
/// review in `ProjectExtractionReviewScreen`; `reviewed` means the user has
/// approved (a subset of) them and they've been applied to the `Project`.
enum DocumentExtractionStatus { none, extracted, reviewed }

extension DocumentExtractionStatusX on DocumentExtractionStatus {
  String get label => switch (this) {
    DocumentExtractionStatus.none => 'Not extracted',
    DocumentExtractionStatus.extracted => 'Extracted — review pending',
    DocumentExtractionStatus.reviewed => 'Reviewed',
  };

  static DocumentExtractionStatus fromString(String value) {
    return DocumentExtractionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DocumentExtractionStatus.none,
    );
  }
}

/// One entry in the company-wide Document Library — a 9th Company
/// Intelligence-graph entity. Created once, then *linked* to however many
/// proposals need it via [relatedProposalIds], exactly like every other
/// Company Intelligence entity is linked to opportunities — never
/// duplicated per proposal. See the Document Library (Milestone 4.3).
///
/// Only metadata lives here — the binary file itself lives in Firebase
/// Storage at `documents/{id}/{fileName}`; [storagePath]/[downloadUrl]
/// point to it.
class LibraryDocument {
  final String id;
  final String title;
  final DocumentCategory category;
  final String description;
  final String version;
  final DocumentStatus status;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? owner;

  final String? storagePath;
  final String? downloadUrl;
  final String? fileName;
  final String? contentType;
  final int? fileSizeBytes;

  // Same 8-field relationship shape as every other Company Intelligence
  // entity, plus relatedProposalIds — the first entity type to relate
  // directly to a Proposal.
  final List<String> businessUnitIds;
  final List<String> productIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> technologyIds;
  final List<String> industryIds;
  final List<String> experienceIds;
  final List<String> knowledgeArticleIds;
  final List<String> relatedProposalIds;

  /// The `Project` this document was uploaded to support, if any — set by
  /// the AI Knowledge Extraction upload flow. Singular (unlike
  /// [relatedProposalIds]): a project-record document supports one project.
  final String? projectId;

  // --- AI Knowledge Extraction (Upload → Extract → Review → Approve) ---
  // Explicit named fields, matching this app's established AI-feature
  // convention (see `Proposal.submissionReview*`, `Opportunity.strategicReview*`)
  // rather than an untyped blob. Relationship-suggestion lists are always
  // pre-filtered server-side against the live knowledge graph's valid IDs —
  // they can only ever reference entities that already exist.
  final DocumentExtractionStatus aiExtractionStatus;
  final DateTime? aiExtractedAt;
  final String? aiExtractedProjectTitle;
  final String? aiExtractedDescription;
  final String? aiExtractedClient;
  final String? aiExtractedFundingAgency;
  final String? aiExtractedCountry;
  final String? aiExtractedLocation;
  final double? aiExtractedContractValueAmount;
  final String? aiExtractedContractValueCurrency;
  final String? aiExtractedContractDuration;
  final DateTime? aiExtractedStartDate;
  final DateTime? aiExtractedCompletionDate;
  final List<String> aiExtractedBusinessUnitIds;
  final List<String> aiExtractedIndustryIds;
  final List<String> aiExtractedTechnologyIds;
  final List<String> aiExtractedServiceIds;
  final List<String> aiExtractedCapabilityIds;
  final List<String> aiExtractedProductIds;

  /// Plain-language names (never IDs — nothing here is a real entity yet)
  /// for a kind of work the document clearly implies but that has no
  /// adequate match in the knowledge graph at extraction time. Shown as
  /// "create & link" suggestions in [ProjectExtractionReviewScreen]; only
  /// become real Business Unit/Industry/Service/Capability documents (and
  /// only then get linked onto the Project) if the reviewing user
  /// explicitly accepts one — extraction itself never creates graph
  /// entities, per this app's "AI must not invent company entities" rule.
  final List<String> aiSuggestedBusinessUnitNames;
  final List<String> aiSuggestedIndustryNames;
  final List<String> aiSuggestedServiceNames;
  final List<String> aiSuggestedCapabilityNames;

  final List<String> aiExtractedTeamDisciplines;
  final List<String> aiExtractedDeliverables;
  final List<String> aiExtractedEquipment;
  final List<String> aiExtractedRisks;
  final List<String> aiExtractedSuccessFactors;
  final List<String> aiExtractedLessonsLearned;
  final List<String> aiExtractedCertifications;
  final List<String> aiExtractedStandards;
  final List<String> aiExtractedKeyAchievements;

  final DateTime createdAt;
  final DateTime updatedAt;

  const LibraryDocument({
    required this.id,
    required this.title,
    required this.category,
    this.description = '',
    this.version = '',
    this.status = DocumentStatus.active,
    this.issueDate,
    this.expiryDate,
    this.owner,
    this.storagePath,
    this.downloadUrl,
    this.fileName,
    this.contentType,
    this.fileSizeBytes,
    this.businessUnitIds = const [],
    this.productIds = const [],
    this.serviceIds = const [],
    this.capabilityIds = const [],
    this.technologyIds = const [],
    this.industryIds = const [],
    this.experienceIds = const [],
    this.knowledgeArticleIds = const [],
    this.relatedProposalIds = const [],
    this.projectId,
    this.aiExtractionStatus = DocumentExtractionStatus.none,
    this.aiExtractedAt,
    this.aiExtractedProjectTitle,
    this.aiExtractedDescription,
    this.aiExtractedClient,
    this.aiExtractedFundingAgency,
    this.aiExtractedCountry,
    this.aiExtractedLocation,
    this.aiExtractedContractValueAmount,
    this.aiExtractedContractValueCurrency,
    this.aiExtractedContractDuration,
    this.aiExtractedStartDate,
    this.aiExtractedCompletionDate,
    this.aiExtractedBusinessUnitIds = const [],
    this.aiExtractedIndustryIds = const [],
    this.aiExtractedTechnologyIds = const [],
    this.aiExtractedServiceIds = const [],
    this.aiExtractedCapabilityIds = const [],
    this.aiExtractedProductIds = const [],
    this.aiSuggestedBusinessUnitNames = const [],
    this.aiSuggestedIndustryNames = const [],
    this.aiSuggestedServiceNames = const [],
    this.aiSuggestedCapabilityNames = const [],
    this.aiExtractedTeamDisciplines = const [],
    this.aiExtractedDeliverables = const [],
    this.aiExtractedEquipment = const [],
    this.aiExtractedRisks = const [],
    this.aiExtractedSuccessFactors = const [],
    this.aiExtractedLessonsLearned = const [],
    this.aiExtractedCertifications = const [],
    this.aiExtractedStandards = const [],
    this.aiExtractedKeyAchievements = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory LibraryDocument.fromMap(String id, Map<String, dynamic> map) {
    return LibraryDocument(
      id: id,
      title: map['title'] as String? ?? '',
      category: DocumentCategoryX.fromString(
        map['category'] as String? ?? 'other',
      ),
      description: map['description'] as String? ?? '',
      version: map['version'] as String? ?? '',
      status: DocumentStatusX.fromString(map['status'] as String? ?? 'active'),
      issueDate: (map['issueDate'] as Timestamp?)?.toDate(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      owner: map['owner'] as String?,
      storagePath: map['storagePath'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
      fileName: map['fileName'] as String?,
      contentType: map['contentType'] as String?,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt(),
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      experienceIds: List<String>.from(
        map['experienceIds'] as List? ?? const [],
      ),
      knowledgeArticleIds: List<String>.from(
        map['knowledgeArticleIds'] as List? ?? const [],
      ),
      relatedProposalIds: List<String>.from(
        map['relatedProposalIds'] as List? ?? const [],
      ),
      projectId: map['projectId'] as String?,
      aiExtractionStatus: DocumentExtractionStatusX.fromString(
        map['aiExtractionStatus'] as String? ?? 'none',
      ),
      aiExtractedAt: (map['aiExtractedAt'] as Timestamp?)?.toDate(),
      aiExtractedProjectTitle: map['aiExtractedProjectTitle'] as String?,
      aiExtractedDescription: map['aiExtractedDescription'] as String?,
      aiExtractedClient: map['aiExtractedClient'] as String?,
      aiExtractedFundingAgency: map['aiExtractedFundingAgency'] as String?,
      aiExtractedCountry: map['aiExtractedCountry'] as String?,
      aiExtractedLocation: map['aiExtractedLocation'] as String?,
      aiExtractedContractValueAmount:
          (map['aiExtractedContractValueAmount'] as num?)?.toDouble(),
      aiExtractedContractValueCurrency:
          map['aiExtractedContractValueCurrency'] as String?,
      aiExtractedContractDuration:
          map['aiExtractedContractDuration'] as String?,
      aiExtractedStartDate: (map['aiExtractedStartDate'] as Timestamp?)
          ?.toDate(),
      aiExtractedCompletionDate:
          (map['aiExtractedCompletionDate'] as Timestamp?)?.toDate(),
      aiExtractedBusinessUnitIds: List<String>.from(
        map['aiExtractedBusinessUnitIds'] as List? ?? const [],
      ),
      aiExtractedIndustryIds: List<String>.from(
        map['aiExtractedIndustryIds'] as List? ?? const [],
      ),
      aiExtractedTechnologyIds: List<String>.from(
        map['aiExtractedTechnologyIds'] as List? ?? const [],
      ),
      aiExtractedServiceIds: List<String>.from(
        map['aiExtractedServiceIds'] as List? ?? const [],
      ),
      aiExtractedCapabilityIds: List<String>.from(
        map['aiExtractedCapabilityIds'] as List? ?? const [],
      ),
      aiExtractedProductIds: List<String>.from(
        map['aiExtractedProductIds'] as List? ?? const [],
      ),
      aiSuggestedBusinessUnitNames: List<String>.from(
        map['aiSuggestedBusinessUnitNames'] as List? ?? const [],
      ),
      aiSuggestedIndustryNames: List<String>.from(
        map['aiSuggestedIndustryNames'] as List? ?? const [],
      ),
      aiSuggestedServiceNames: List<String>.from(
        map['aiSuggestedServiceNames'] as List? ?? const [],
      ),
      aiSuggestedCapabilityNames: List<String>.from(
        map['aiSuggestedCapabilityNames'] as List? ?? const [],
      ),
      aiExtractedTeamDisciplines: List<String>.from(
        map['aiExtractedTeamDisciplines'] as List? ?? const [],
      ),
      aiExtractedDeliverables: List<String>.from(
        map['aiExtractedDeliverables'] as List? ?? const [],
      ),
      aiExtractedEquipment: List<String>.from(
        map['aiExtractedEquipment'] as List? ?? const [],
      ),
      aiExtractedRisks: List<String>.from(
        map['aiExtractedRisks'] as List? ?? const [],
      ),
      aiExtractedSuccessFactors: List<String>.from(
        map['aiExtractedSuccessFactors'] as List? ?? const [],
      ),
      aiExtractedLessonsLearned: List<String>.from(
        map['aiExtractedLessonsLearned'] as List? ?? const [],
      ),
      aiExtractedCertifications: List<String>.from(
        map['aiExtractedCertifications'] as List? ?? const [],
      ),
      aiExtractedStandards: List<String>.from(
        map['aiExtractedStandards'] as List? ?? const [],
      ),
      aiExtractedKeyAchievements: List<String>.from(
        map['aiExtractedKeyAchievements'] as List? ?? const [],
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category.name,
      'description': description,
      'version': version,
      'status': status.name,
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'owner': owner,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'contentType': contentType,
      'fileSizeBytes': fileSizeBytes,
      'businessUnitIds': businessUnitIds,
      'productIds': productIds,
      'serviceIds': serviceIds,
      'capabilityIds': capabilityIds,
      'technologyIds': technologyIds,
      'industryIds': industryIds,
      'experienceIds': experienceIds,
      'knowledgeArticleIds': knowledgeArticleIds,
      'relatedProposalIds': relatedProposalIds,
      'projectId': projectId,
      'aiExtractionStatus': aiExtractionStatus.name,
      'aiExtractedAt': aiExtractedAt != null
          ? Timestamp.fromDate(aiExtractedAt!)
          : null,
      'aiExtractedProjectTitle': aiExtractedProjectTitle,
      'aiExtractedDescription': aiExtractedDescription,
      'aiExtractedClient': aiExtractedClient,
      'aiExtractedFundingAgency': aiExtractedFundingAgency,
      'aiExtractedCountry': aiExtractedCountry,
      'aiExtractedLocation': aiExtractedLocation,
      'aiExtractedContractValueAmount': aiExtractedContractValueAmount,
      'aiExtractedContractValueCurrency': aiExtractedContractValueCurrency,
      'aiExtractedContractDuration': aiExtractedContractDuration,
      'aiExtractedStartDate': aiExtractedStartDate != null
          ? Timestamp.fromDate(aiExtractedStartDate!)
          : null,
      'aiExtractedCompletionDate': aiExtractedCompletionDate != null
          ? Timestamp.fromDate(aiExtractedCompletionDate!)
          : null,
      'aiExtractedBusinessUnitIds': aiExtractedBusinessUnitIds,
      'aiExtractedIndustryIds': aiExtractedIndustryIds,
      'aiExtractedTechnologyIds': aiExtractedTechnologyIds,
      'aiExtractedServiceIds': aiExtractedServiceIds,
      'aiExtractedCapabilityIds': aiExtractedCapabilityIds,
      'aiExtractedProductIds': aiExtractedProductIds,
      'aiSuggestedBusinessUnitNames': aiSuggestedBusinessUnitNames,
      'aiSuggestedIndustryNames': aiSuggestedIndustryNames,
      'aiSuggestedServiceNames': aiSuggestedServiceNames,
      'aiSuggestedCapabilityNames': aiSuggestedCapabilityNames,
      'aiExtractedTeamDisciplines': aiExtractedTeamDisciplines,
      'aiExtractedDeliverables': aiExtractedDeliverables,
      'aiExtractedEquipment': aiExtractedEquipment,
      'aiExtractedRisks': aiExtractedRisks,
      'aiExtractedSuccessFactors': aiExtractedSuccessFactors,
      'aiExtractedLessonsLearned': aiExtractedLessonsLearned,
      'aiExtractedCertifications': aiExtractedCertifications,
      'aiExtractedStandards': aiExtractedStandards,
      'aiExtractedKeyAchievements': aiExtractedKeyAchievements,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// A shallow copy with just the extraction-review outcome updated —
  /// used by `ProjectExtractionReviewScreen` on Approve. Everything else
  /// (including the `aiExtracted*` values themselves, kept for audit/
  /// re-review) is left untouched.
  LibraryDocument copyWithExtractionStatus(DocumentExtractionStatus status) {
    return LibraryDocument(
      id: id,
      title: title,
      category: category,
      description: description,
      version: version,
      status: this.status,
      issueDate: issueDate,
      expiryDate: expiryDate,
      owner: owner,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      fileName: fileName,
      contentType: contentType,
      fileSizeBytes: fileSizeBytes,
      businessUnitIds: businessUnitIds,
      productIds: productIds,
      serviceIds: serviceIds,
      capabilityIds: capabilityIds,
      technologyIds: technologyIds,
      industryIds: industryIds,
      experienceIds: experienceIds,
      knowledgeArticleIds: knowledgeArticleIds,
      relatedProposalIds: relatedProposalIds,
      projectId: projectId,
      aiExtractionStatus: status,
      aiExtractedAt: aiExtractedAt,
      aiExtractedProjectTitle: aiExtractedProjectTitle,
      aiExtractedDescription: aiExtractedDescription,
      aiExtractedClient: aiExtractedClient,
      aiExtractedFundingAgency: aiExtractedFundingAgency,
      aiExtractedCountry: aiExtractedCountry,
      aiExtractedLocation: aiExtractedLocation,
      aiExtractedContractValueAmount: aiExtractedContractValueAmount,
      aiExtractedContractValueCurrency: aiExtractedContractValueCurrency,
      aiExtractedContractDuration: aiExtractedContractDuration,
      aiExtractedStartDate: aiExtractedStartDate,
      aiExtractedCompletionDate: aiExtractedCompletionDate,
      aiExtractedBusinessUnitIds: aiExtractedBusinessUnitIds,
      aiExtractedIndustryIds: aiExtractedIndustryIds,
      aiExtractedTechnologyIds: aiExtractedTechnologyIds,
      aiExtractedServiceIds: aiExtractedServiceIds,
      aiExtractedCapabilityIds: aiExtractedCapabilityIds,
      aiExtractedProductIds: aiExtractedProductIds,
      aiSuggestedBusinessUnitNames: aiSuggestedBusinessUnitNames,
      aiSuggestedIndustryNames: aiSuggestedIndustryNames,
      aiSuggestedServiceNames: aiSuggestedServiceNames,
      aiSuggestedCapabilityNames: aiSuggestedCapabilityNames,
      aiExtractedTeamDisciplines: aiExtractedTeamDisciplines,
      aiExtractedDeliverables: aiExtractedDeliverables,
      aiExtractedEquipment: aiExtractedEquipment,
      aiExtractedRisks: aiExtractedRisks,
      aiExtractedSuccessFactors: aiExtractedSuccessFactors,
      aiExtractedLessonsLearned: aiExtractedLessonsLearned,
      aiExtractedCertifications: aiExtractedCertifications,
      aiExtractedStandards: aiExtractedStandards,
      aiExtractedKeyAchievements: aiExtractedKeyAchievements,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
