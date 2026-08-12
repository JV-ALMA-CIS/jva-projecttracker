import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/screens/opportunities/opportunity_pipeline_screen.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedOpportunity(FakeFirebaseFirestore firestore) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water tender',
    'description': 'Design and build rural water network',
    'sourceUrl': 'https://example.com/tender/1',
    'status': 'discovered',
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
        opportunityEventServiceProvider.overrideWithValue(
          OpportunityEventService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: OpportunityPipelineScreen(opportunityId: opportunityId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets(
    'shows the current stage and empty pipeline history for a new opportunity',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      await _pumpScreen(tester, firestore, id);

      expect(
        find.text(
          _strings.pipelineStageLabel(OpportunityPipelineStage.discovered),
        ),
        findsOneWidget,
      );

      // The pipeline history sits below several form fields, past the
      // default test viewport — scroll the page's ListView until it builds.
      await tester.scrollUntilVisible(
        find.text(_strings.noEventsYet),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.noEventsYet), findsOneWidget);
    },
  );

  testWidgets(
    'changing stage via the dialog updates the indicator and adds a timeline entry',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final id = await _seedOpportunity(firestore);

      await _pumpScreen(tester, firestore, id);

      await tester.tap(find.text(_strings.changeStageButton));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byType(DropdownButtonFormField<OpportunityPipelineStage>),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          _strings.pipelineStageLabel(OpportunityPipelineStage.qualified),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.confirmButton));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Stage changed to Qualified'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Stage changed to Qualified'), findsOneWidget);
    },
  );
}
