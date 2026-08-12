import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { planned, running, past }

extension ProjectStatusX on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.planned => 'Planned',
    ProjectStatus.running => 'Running',
    ProjectStatus.past => 'Past',
  };

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProjectStatus.planned,
    );
  }
}

/// Construction project category/taxonomy.
enum ProjectCategory {
  residential,
  roads,
  waterSanitation,
  commercial,
  industrial,
  other,
}

extension ProjectCategoryX on ProjectCategory {
  String get label => switch (this) {
    ProjectCategory.residential => 'Residential',
    ProjectCategory.roads => 'Roads',
    ProjectCategory.waterSanitation => 'Water & Sanitation',
    ProjectCategory.commercial => 'Commercial',
    ProjectCategory.industrial => 'Industrial',
    ProjectCategory.other => 'Other',
  };

  static ProjectCategory fromString(String value) {
    return ProjectCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ProjectCategory.other,
    );
  }
}

/// JVA's role on a given project.
enum ContractorRole { mainContractor, subcontractor, consultant }

extension ContractorRoleX on ContractorRole {
  String get label => switch (this) {
    ContractorRole.mainContractor => 'Main Contractor',
    ContractorRole.subcontractor => 'Subcontractor',
    ContractorRole.consultant => 'Consultant',
  };

  static ContractorRole fromString(String value) {
    return ContractorRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ContractorRole.mainContractor,
    );
  }
}

enum ClientType { government, privateClient, ngo }

extension ClientTypeX on ClientType {
  String get label => switch (this) {
    ClientType.government => 'Government',
    ClientType.privateClient => 'Private',
    ClientType.ngo => 'NGO',
  };

  static ClientType fromString(String value) {
    return ClientType.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ClientType.privateClient,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String client;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> teamMembers;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Construction taxonomy for this project (roads, water & sanitation, etc).
  final ProjectCategory category;

  /// Free-text site/location description.
  final String location;

  /// Contract value as entered, in [contractValueCurrency]. Null means
  /// unknown/confidential — never rendered as 0 or a placeholder.
  final double? contractValueAmount;

  /// ISO currency code the amount was entered in (e.g. 'USD'). Only
  /// meaningful when [contractValueAmount] is non-null.
  final String contractValueCurrency;

  /// Free-text scope-of-works description.
  final String scopeOfWorks;

  /// The funding/financing/contracting agency behind the contract when
  /// identifiable as distinct from [client] — e.g. AICS, USG/DOS, World
  /// Bank, an embassy program funder. [client] stays the customer/
  /// contracting office/end-user named on the contract; this is who paid
  /// for it when that's a different party. Empty string (not null) so it
  /// matches every other free-text Project field's "missing = ''"
  /// convention — never rendered as a fabricated value either way.
  final String fundingAgency;

  /// JVA's role on this project.
  final ContractorRole contractorRole;

  /// Flexible free-text project scale, e.g. "12,500 sq.m", "4.2 km".
  final String projectSize;

  final ClientType clientType;

  /// The `Opportunity` this project originated from, if any — set when a
  /// project is started from the Opportunity Workspace once an opportunity
  /// reaches `awarded`. Closes the `Awarded -> Project Started` link in the
  /// Opportunity Lifecycle that previously didn't exist. `null` for a
  /// project created directly (not every project needs to have come from a
  /// tracked opportunity).
  final String? sourceOpportunityId;

  /// The `Experience` entry created from this completed project, if it has
  /// been promoted to one — makes "Add as Company Experience" idempotent
  /// (an already-promoted project offers "View Company Experience" instead,
  /// never a second, duplicate Experience).
  final String? experienceId;

  /// Company Intelligence relationships — same flat-doc-ID-list convention
  /// as every other entity (see `PROJECT_CONTEXT.md` architecture rule 4).
  /// Populated by hand for now. A future AI Knowledge Extraction review
  /// workflow (upload project documents -> AI extracts structured info ->
  /// user reviews/approves -> Project and Company Intelligence are updated)
  /// is planned for a later milestone alongside the document ingestion
  /// pipeline — not implemented yet, and nothing here should be read as
  /// implying it already is.
  final List<String> businessUnitIds;
  final List<String> industryIds;
  final List<String> technologyIds;
  final List<String> serviceIds;
  final List<String> capabilityIds;
  final List<String> productIds;

  // --- Project Delivery Workspace additions ---

  /// The project's owner — free-text name/email, same convention as
  /// `assignedTo` everywhere else in this app (no user-directory picker
  /// exists). Distinct from the flat `teamMembers` list: this is the one
  /// person the Executive Overview names as accountable for delivery.
  final String? projectManager;

  /// Internal cost plan, distinct from [contractValueAmount] (what the
  /// client pays). Both null means budget hasn't been set up yet — an
  /// honest empty state, not a fabricated 0. Reuses
  /// [contractValueCurrency] rather than adding a third currency field.
  final double? plannedBudgetAmount;
  final double? currentExpenditureAmount;

  /// A manually-entered projected final cost. Deliberately a plain field,
  /// not a formula — the Project Workspace does not invent a forecasting
  /// model; it shows what was entered and lets the PM update it as reality
  /// changes. (A statistical forecast, if ever wanted, belongs alongside
  /// the Executive Dashboard's Milestone 5.5-equivalent work, not here.)
  final double? forecastAmount;

  /// Free-text lessons-learned capture — successes, failures,
  /// recommendations, reusable knowledge. This is the seed content used
  /// when promoting the project to a Company Experience (via
  /// [experienceId]) or to one or more Knowledge Articles (via
  /// [knowledgeArticleIds]); it is not itself a new Company Intelligence
  /// entity, per this project's "no duplicate knowledge entities" rule
  /// (ADR-002) — Experience/KnowledgeArticle remain the only real assets.
  final String lessonsLearned;

  /// Knowledge Articles published from this project's lessons learned.
  /// Plural and separate from the single [experienceId] promotion — a
  /// project can spin off several distinct knowledge articles (e.g. one
  /// per lesson) while still promoting to at most one Experience record.
  final List<String> knowledgeArticleIds;

  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.client,
    required this.status,
    this.startDate,
    this.endDate,
    this.teamMembers = const [],
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.category = ProjectCategory.other,
    this.location = '',
    this.contractValueAmount,
    this.contractValueCurrency = 'EUR',
    this.scopeOfWorks = '',
    this.fundingAgency = '',
    this.contractorRole = ContractorRole.mainContractor,
    this.projectSize = '',
    this.clientType = ClientType.privateClient,
    this.sourceOpportunityId,
    this.experienceId,
    this.businessUnitIds = const [],
    this.industryIds = const [],
    this.technologyIds = const [],
    this.serviceIds = const [],
    this.capabilityIds = const [],
    this.productIds = const [],
    this.projectManager,
    this.plannedBudgetAmount,
    this.currentExpenditureAmount,
    this.forecastAmount,
    this.lessonsLearned = '',
    this.knowledgeArticleIds = const [],
  });

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    return Project(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      client: map['client'] as String? ?? '',
      status: ProjectStatusX.fromString(map['status'] as String? ?? 'planned'),
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      teamMembers: List<String>.from(map['teamMembers'] as List? ?? const []),
      notes: map['notes'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: ProjectCategoryX.fromString(
        map['category'] as String? ?? 'other',
      ),
      location: map['location'] as String? ?? '',
      contractValueAmount: (map['contractValueAmount'] as num?)?.toDouble(),
      contractValueCurrency: map['contractValueCurrency'] as String? ?? 'EUR',
      scopeOfWorks: map['scopeOfWorks'] as String? ?? '',
      fundingAgency: map['fundingAgency'] as String? ?? '',
      contractorRole: ContractorRoleX.fromString(
        map['contractorRole'] as String? ?? 'mainContractor',
      ),
      projectSize: map['projectSize'] as String? ?? '',
      clientType: ClientTypeX.fromString(
        map['clientType'] as String? ?? 'privateClient',
      ),
      sourceOpportunityId: map['sourceOpportunityId'] as String?,
      experienceId: map['experienceId'] as String?,
      businessUnitIds: List<String>.from(
        map['businessUnitIds'] as List? ?? const [],
      ),
      industryIds: List<String>.from(map['industryIds'] as List? ?? const []),
      technologyIds: List<String>.from(
        map['technologyIds'] as List? ?? const [],
      ),
      serviceIds: List<String>.from(map['serviceIds'] as List? ?? const []),
      capabilityIds: List<String>.from(
        map['capabilityIds'] as List? ?? const [],
      ),
      productIds: List<String>.from(map['productIds'] as List? ?? const []),
      projectManager: map['projectManager'] as String?,
      plannedBudgetAmount: (map['plannedBudgetAmount'] as num?)?.toDouble(),
      currentExpenditureAmount: (map['currentExpenditureAmount'] as num?)
          ?.toDouble(),
      forecastAmount: (map['forecastAmount'] as num?)?.toDouble(),
      lessonsLearned: map['lessonsLearned'] as String? ?? '',
      knowledgeArticleIds: List<String>.from(
        map['knowledgeArticleIds'] as List? ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'client': client,
      'status': status.name,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'teamMembers': teamMembers,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'category': category.name,
      'location': location,
      'contractValueAmount': contractValueAmount,
      'contractValueCurrency': contractValueCurrency,
      'scopeOfWorks': scopeOfWorks,
      'fundingAgency': fundingAgency,
      'contractorRole': contractorRole.name,
      'projectSize': projectSize,
      'clientType': clientType.name,
      'sourceOpportunityId': sourceOpportunityId,
      'experienceId': experienceId,
      'businessUnitIds': businessUnitIds,
      'industryIds': industryIds,
      'technologyIds': technologyIds,
      'serviceIds': serviceIds,
      'capabilityIds': capabilityIds,
      'productIds': productIds,
      'projectManager': projectManager,
      'plannedBudgetAmount': plannedBudgetAmount,
      'currentExpenditureAmount': currentExpenditureAmount,
      'forecastAmount': forecastAmount,
      'lessonsLearned': lessonsLearned,
      'knowledgeArticleIds': knowledgeArticleIds,
    };
  }

  Project copyWith({
    String? name,
    String? description,
    String? client,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? teamMembers,
    String? notes,
    ProjectCategory? category,
    String? location,
    double? contractValueAmount,
    bool clearContractValueAmount = false,
    String? contractValueCurrency,
    String? scopeOfWorks,
    String? fundingAgency,
    ContractorRole? contractorRole,
    String? projectSize,
    ClientType? clientType,
    List<String>? businessUnitIds,
    List<String>? industryIds,
    List<String>? technologyIds,
    List<String>? serviceIds,
    List<String>? capabilityIds,
    List<String>? productIds,
    String? projectManager,
    double? plannedBudgetAmount,
    bool clearPlannedBudgetAmount = false,
    double? currentExpenditureAmount,
    bool clearCurrentExpenditureAmount = false,
    double? forecastAmount,
    bool clearForecastAmount = false,
    String? lessonsLearned,
    List<String>? knowledgeArticleIds,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      client: client ?? this.client,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teamMembers: teamMembers ?? this.teamMembers,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      category: category ?? this.category,
      location: location ?? this.location,
      contractValueAmount: clearContractValueAmount
          ? null
          : (contractValueAmount ?? this.contractValueAmount),
      contractValueCurrency:
          contractValueCurrency ?? this.contractValueCurrency,
      scopeOfWorks: scopeOfWorks ?? this.scopeOfWorks,
      fundingAgency: fundingAgency ?? this.fundingAgency,
      contractorRole: contractorRole ?? this.contractorRole,
      projectSize: projectSize ?? this.projectSize,
      clientType: clientType ?? this.clientType,
      // Never settable via copyWith — sourceOpportunityId is immutable once
      // set at creation, and experienceId is only ever set via
      // ProjectService.linkExperience — both must survive an ordinary
      // edit-and-save untouched.
      sourceOpportunityId: sourceOpportunityId,
      experienceId: experienceId,
      businessUnitIds: businessUnitIds ?? this.businessUnitIds,
      industryIds: industryIds ?? this.industryIds,
      technologyIds: technologyIds ?? this.technologyIds,
      serviceIds: serviceIds ?? this.serviceIds,
      capabilityIds: capabilityIds ?? this.capabilityIds,
      productIds: productIds ?? this.productIds,
      projectManager: projectManager ?? this.projectManager,
      plannedBudgetAmount: clearPlannedBudgetAmount
          ? null
          : (plannedBudgetAmount ?? this.plannedBudgetAmount),
      currentExpenditureAmount: clearCurrentExpenditureAmount
          ? null
          : (currentExpenditureAmount ?? this.currentExpenditureAmount),
      forecastAmount: clearForecastAmount
          ? null
          : (forecastAmount ?? this.forecastAmount),
      lessonsLearned: lessonsLearned ?? this.lessonsLearned,
      knowledgeArticleIds: knowledgeArticleIds ?? this.knowledgeArticleIds,
    );
  }
}
