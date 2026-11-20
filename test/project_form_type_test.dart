import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/screens/projects/project_form_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AppStrings _strings = AppStrings(Locale('en'));

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final firestore = FakeFirebaseFirestore();
  await firestore.collection('businessUnits').add({
    'name': 'Information Technology',
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        projectServiceProvider.overrideWithValue(
          ProjectService(firestore: firestore),
        ),
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: ProjectFormScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (String label, Size size) in [
    ('desktop', const Size(1400, 1000)),
    ('phone', const Size(400, 900)),
  ]) {
    testWidgets('new project form ($label): Project type shows and switches '
        'to the IT fields', (tester) async {
      await _pump(tester, size);

      await tester.scrollUntilVisible(
        find.text(_strings.fieldProjectType),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.fieldProjectType), findsOneWidget);

      await tester.tap(
        find.text(_strings.projectTypeLabel(ProjectType.construction)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_strings.projectTypeLabel(ProjectType.itSoftware)).last,
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(_strings.deliveryModelFieldLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.deliveryModelFieldLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
