import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/models/contract.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/user_profile.dart';
import 'package:jva_projecttracker/services/application_service.dart';
import 'package:jva_projecttracker/services/auth_service.dart';
import 'package:jva_projecttracker/services/contract_service.dart';
import 'package:jva_projecttracker/services/currency_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'package:jva_projecttracker/services/user_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final projectServiceProvider = Provider((ref) => ProjectService());
final applicationServiceProvider = Provider((ref) => ApplicationService());
final contractServiceProvider = Provider((ref) => ContractService());
final userServiceProvider = Provider((ref) => UserService());
final currencyServiceProvider = Provider((ref) => CurrencyService());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in user's Firestore profile (including role), or null if
/// signed out or the profile hasn't been created yet.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watch(user.uid);
});

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

/// Project counts per status, derived from [projectsStreamProvider]. Kept as
/// a separate provider (rather than computed inline in the dashboard) so the
/// dashboard can `.select()` a single status count and skip rebuilding when
/// unrelated counts change.
final projectStatusCountsProvider = Provider<Map<ProjectStatus, int>>((ref) {
  final projects = ref.watch(projectsStreamProvider).value ?? const [];
  final counts = <ProjectStatus, int>{
    for (final s in ProjectStatus.values) s: 0,
  };
  for (final p in projects) {
    counts[p.status] = (counts[p.status] ?? 0) + 1;
  }
  return counts;
});

/// The top 5 contracts by fit score, derived from [contractsStreamProvider]
/// (already ordered by `fitScorePercent` desc at the Firestore query level).
final topContractsProvider = Provider<List<Contract>>((ref) {
  final contracts = ref.watch(contractsStreamProvider).value ?? const [];
  return contracts.take(5).toList();
});

/// A single project by id, live. Scoped to navigation (edit screen) rather
/// than the app lifetime, so autoDispose is correct here — unlike the
/// top-level [projectsStreamProvider], which backs an always-visible list.
final projectByIdProvider = StreamProvider.autoDispose.family<Project?, String>(
  (ref, id) {
    return ref.watch(projectServiceProvider).watchById(id);
  },
);

/// A single application by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final applicationByIdProvider = StreamProvider.autoDispose
    .family<CompanyApplication?, String>((ref, id) {
      return ref.watch(applicationServiceProvider).watchById(id);
    });

/// Live exchange rates from [base] to the other supported currencies, kept
/// alive for 30 minutes so switching fields/screens doesn't re-hit the API
/// on every rebuild, while still refreshing periodically rather than being
/// pinned to a stale value for the whole session.
final exchangeRatesProvider = FutureProvider.autoDispose
    .family<Map<String, double>, String>((ref, base) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 30), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(currencyServiceProvider).fetchRates(base);
    });
