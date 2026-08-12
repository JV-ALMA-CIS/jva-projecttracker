import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedOpportunity(
  FakeFirebaseFirestore firestore, {
  required String pipelineStage,
}) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'discovered',
    'pipelineStage': pipelineStage,
    'fitScorePercent': 70,
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String opportunityId,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        projectServiceProvider.overrideWithValue(
          ProjectService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: _KeepOpportunityAlive(
          opportunityId: opportunityId,
          child: ProjectFormScreen(
            sourceOpportunityId: opportunityId,
            initialName: 'Rural water tender',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Keeps `opportunityByIdProvider`/`projectByOpportunityIdProvider` for
/// [opportunityId] subscribed for the lifetime of the test widget tree.
/// `_save` reads both autoDispose providers' `.future` without the form
/// itself ever watching them (create mode has no other subscriber), so
/// under `FakeFirebaseFirestore` a provider can be disposed before its
/// first snapshot arrives. A real app always has another screen (e.g. the
/// Opportunity Workspace) already watching the same id, so this only
/// compensates for that missing subscriber in an isolated widget test — it
/// changes no production code.
class _KeepOpportunityAlive extends ConsumerWidget {
  const _KeepOpportunityAlive({
    required this.opportunityId,
    required this.child,
  });

  final String opportunityId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(opportunityByIdProvider(opportunityId));
    ref.watch(projectByOpportunityIdProvider(opportunityId));
    return child;
  }
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text(_strings.saveButton),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(_strings.saveButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets(
    'refuses to create a Project when the opportunity is not awarded',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final opportunityId = await _seedOpportunity(
        firestore,
        pipelineStage: 'submitted',
      );

      await _pumpScreen(tester, firestore, opportunityId);
      await _tapSave(tester);

      expect(find.text(_strings.projectRequiresAwardMessage), findsOneWidget);
      final projects = await firestore.collection('projects').get();
      expect(projects.docs, isEmpty);
    },
  );

  testWidgets('creates exactly one Project when the opportunity is awarded', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final opportunityId = await _seedOpportunity(
      firestore,
      pipelineStage: 'awarded',
    );

    await _pumpScreen(tester, firestore, opportunityId);
    await _tapSave(tester);

    final projects = await firestore.collection('projects').get();
    expect(projects.docs, hasLength(1));
    expect(projects.docs.single.data()['sourceOpportunityId'], opportunityId);

    final opportunityDoc = await firestore
        .collection('opportunities')
        .doc(opportunityId)
        .get();
    expect(opportunityDoc.data()!['pipelineStage'], 'projectStarted');
  });

  testWidgets(
    'a repeated creation attempt resolves to the existing Project instead of duplicating it',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final opportunityId = await _seedOpportunity(
        firestore,
        pipelineStage: 'awarded',
      );
      // Simulate a project that already exists for this opportunity — e.g.
      // created moments earlier from another tab.
      final now = DateTime.utc(2024, 8, 1);
      await firestore.collection('projects').add({
        'name': 'Rural water tender',
        'description': '',
        'client': '',
        'status': 'planned',
        'notes': '',
        'createdAt': now,
        'updatedAt': now,
        'category': 'other',
        'location': '',
        'contractValueCurrency': 'EUR',
        'scopeOfWorks': '',
        'contractorRole': 'mainContractor',
        'projectSize': '',
        'clientType': 'privateClient',
        'sourceOpportunityId': opportunityId,
      });

      await _pumpScreen(tester, firestore, opportunityId);
      await _tapSave(tester);

      final projects = await firestore.collection('projects').get();
      expect(projects.docs, hasLength(1));
    },
  );
}
