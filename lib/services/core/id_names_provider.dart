import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/services/providers.dart';

/// Every document ID the AI might quote, mapped to the name staff know it
/// by: opportunity titles plus every Company Intelligence entity (business
/// units, products, services, capabilities, technologies, industries,
/// experiences, knowledge articles). Used with `humanizeIds` wherever
/// AI-written text is shown, so an ID is replaced by its real name instead
/// of being shown raw (or merely dropped).
final idNamesProvider = Provider<Map<String, String>>((ref) {
  final names = <String, String>{};
  void add(String id, String name) {
    if (id.isNotEmpty && name.trim().isNotEmpty) names[id] = name.trim();
  }

  for (final o in ref.watch(opportunitiesStreamProvider).value ?? const []) {
    add(o.id, o.title);
  }
  for (final e in ref.watch(businessUnitsStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(productsStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(servicesStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(capabilitiesStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(technologiesStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(industriesStreamProvider).value ?? const []) {
    add(e.id, e.name);
  }
  for (final e in ref.watch(experiencesStreamProvider).value ?? const []) {
    add(e.id, e.title);
  }
  for (final e
      in ref.watch(knowledgeArticlesStreamProvider).value ?? const []) {
    add(e.id, e.title);
  }
  return names;
});
