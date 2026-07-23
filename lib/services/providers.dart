import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/models/contract.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/application_service.dart';
import 'package:jva_projecttracker/services/contract_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';

final projectServiceProvider = Provider((ref) => ProjectService());
final applicationServiceProvider = Provider((ref) => ApplicationService());
final contractServiceProvider = Provider((ref) => ContractService());

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectServiceProvider).watchAll();
});

final applicationsStreamProvider = StreamProvider<List<CompanyApplication>>((
  ref,
) {
  return ref.watch(applicationServiceProvider).watchAll();
});

final contractsStreamProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractServiceProvider).watchAll();
});
