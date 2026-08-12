import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/models/discovery_source.dart';
import 'package:jva_projecttracker/services/discovery_engine_service.dart';
import 'package:jva_projecttracker/services/discovery_run_service.dart';
import 'package:jva_projecttracker/services/discovery_source_service.dart';

final discoverySourceServiceProvider = Provider(
  (ref) => DiscoverySourceService(),
);
final discoveryRunServiceProvider = Provider((ref) => DiscoveryRunService());
final discoveryEngineServiceProvider = Provider(
  (ref) => DiscoveryEngineService(),
);

final discoverySourcesStreamProvider = StreamProvider<List<DiscoverySource>>((
  ref,
) {
  return ref.watch(discoverySourceServiceProvider).watchAll();
});

/// A single discovery source by id, live. See [projectByIdProvider] for the
/// autoDispose/family reasoning.
final discoverySourceByIdProvider = StreamProvider.autoDispose
    .family<DiscoverySource?, String>((ref, id) {
      return ref.watch(discoverySourceServiceProvider).watchById(id);
    });

/// Every discovery run across every source, live, most recent first — backs
/// the Discovery History screen.
final discoveryRunsStreamProvider = StreamProvider<List<DiscoveryRun>>((ref) {
  return ref.watch(discoveryRunServiceProvider).watchAll();
});

/// A single source's run history, live. See
/// [opportunityEventsByOpportunityProvider] for the family-not-autoDispose
/// reasoning.
final discoveryRunsBySourceProvider =
    StreamProvider.family<List<DiscoveryRun>, String>((ref, sourceId) {
      return ref.watch(discoveryRunServiceProvider).watchBySource(sourceId);
    });
