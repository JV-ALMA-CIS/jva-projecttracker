import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/services/company_intelligence/certification_service.dart';

final certificationServiceProvider = Provider((ref) => CertificationService());

final certificationsStreamProvider = StreamProvider<List<Certification>>((ref) {
  return ref.watch(certificationServiceProvider).watchAll();
});

/// A single certification by id, live. See `projectByIdProvider` for the
/// autoDispose/family reasoning shared by every "detail screen" provider in
/// this app.
final certificationByIdProvider = StreamProvider.autoDispose
    .family<Certification?, String>((ref, id) {
      return ref.watch(certificationServiceProvider).watchById(id);
    });
