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

  /// JVA's role on this project.
  final ContractorRole contractorRole;

  /// Flexible free-text project scale, e.g. "12,500 sq.m", "4.2 km".
  final String projectSize;

  final ClientType clientType;

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
    this.contractorRole = ContractorRole.mainContractor,
    this.projectSize = '',
    this.clientType = ClientType.privateClient,
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
      contractorRole: ContractorRoleX.fromString(
        map['contractorRole'] as String? ?? 'mainContractor',
      ),
      projectSize: map['projectSize'] as String? ?? '',
      clientType: ClientTypeX.fromString(
        map['clientType'] as String? ?? 'privateClient',
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
      'contractorRole': contractorRole.name,
      'projectSize': projectSize,
      'clientType': clientType.name,
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
    ContractorRole? contractorRole,
    String? projectSize,
    ClientType? clientType,
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
      contractorRole: contractorRole ?? this.contractorRole,
      projectSize: projectSize ?? this.projectSize,
      clientType: clientType ?? this.clientType,
    );
  }
}
