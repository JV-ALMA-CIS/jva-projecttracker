import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/product_form_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technology_form_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedBusinessUnit(FakeFirebaseFirestore firestore) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('businessUnits').add({
    'name': 'Information Technology',
    'slug': 'information-technology',
    'status': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
        capabilityServiceProvider.overrideWithValue(
          CapabilityService(firestore: firestore),
        ),
        industryServiceProvider.overrideWithValue(
          IndustryService(firestore: firestore),
        ),
        technologyServiceProvider.overrideWithValue(
          TechnologyService(firestore: firestore),
        ),
        productServiceProvider.overrideWithValue(
          ProductService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: ProductFormScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredProductFields(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, _strings.fieldProductName),
    'Kilimo Mkononi',
  );
  await tester.tap(find.text('Information Technology'));
  await tester.pumpAndSettle();
}

Future<void> _openQuickAddDialog(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text(_strings.addTechnologyButton),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(_strings.addTechnologyButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the "+ Add Technology" action opens a compact dialog rather than the '
    'full Technology form, and never navigates away from the Product form',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedBusinessUnit(firestore);
      await _pumpScreen(tester, firestore);

      await _fillRequiredProductFields(tester);
      await _openQuickAddDialog(tester);

      // The compact dialog is up, the Product form (its title/AppBar) is
      // still in the tree behind it — no navigation occurred.
      expect(find.text(_strings.quickAddTechnologyTitle), findsOneWidget);
      expect(find.text(_strings.newProductTitle), findsOneWidget);
      // The full Technology form was never opened.
      expect(find.byType(TechnologyFormScreen), findsNothing);
      // Only the compact dialog's three fields are present. The Technology
      // form's status dropdown (TechnologyStatus, distinct from Product's
      // own ProductStatus dropdown which legitimately shares the
      // "fieldStatus" label) never appears, nor does any of its
      // vendor/website/keywords/tags/notes/relationship fields.
      expect(find.text(_strings.fieldTechnologyName), findsOneWidget);
      expect(find.text(_strings.fieldDescription), findsOneWidget);
      expect(find.text(_strings.fieldTechnologyCategory), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<TechnologyStatus>),
        findsNothing,
      );
      expect(
        find.text(_strings.fieldTechnologyVendor, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(_strings.fieldTechnologyWebsite, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(_strings.relatedBusinessUnitsLabel, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(_strings.relatedProductsLabel, skipOffstage: false),
        findsNothing,
      );
      // Product's own form legitimately has a "Related capabilities"
      // picker for itself, so this checks there's still only the one
      // (Product's), not a second copy leaking in from the dialog.
      expect(
        find.text(_strings.relatedCapabilitiesLabel, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologyNotes, skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets('an empty Technology name is rejected with validation feedback', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedBusinessUnit(firestore);
    await _pumpScreen(tester, firestore);

    await _fillRequiredProductFields(tester);
    await _openQuickAddDialog(tester);

    await tester.tap(find.text(_strings.addTechnologyDialogButton));
    await tester.pumpAndSettle();

    expect(find.text(_strings.requiredValidator), findsOneWidget);
    // Dialog is still open — nothing was created.
    expect(find.text(_strings.quickAddTechnologyTitle), findsOneWidget);
    final technologies = await firestore.collection('technologies').get();
    expect(technologies.docs, isEmpty);
  });

  testWidgets(
    'creating a Technology from the quick-add dialog selects it and the '
    'saved Product references its id, not a free-text name',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final businessUnitId = await _seedBusinessUnit(firestore);

      await _pumpScreen(tester, firestore);
      await _fillRequiredProductFields(tester);
      await _openQuickAddDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, _strings.fieldTechnologyName),
        'Flutter',
      );
      await tester.tap(find.text(_strings.addTechnologyDialogButton));
      await tester.pumpAndSettle();

      // Dialog closed, back on the Product form (still open, not navigated
      // away), with the newly created Technology written to Firestore.
      expect(find.text(_strings.quickAddTechnologyTitle), findsNothing);
      expect(find.text(_strings.newProductTitle), findsOneWidget);
      final technologies = await firestore.collection('technologies').get();
      expect(technologies.docs, hasLength(1));
      final technologyId = technologies.docs.single.id;
      expect(technologies.docs.single.data()['name'], 'Flutter');

      // The Product does not need to be saved for the Technology to exist,
      // but saving now should persist the selection as an id, not a string.
      await tester.scrollUntilVisible(
        find.text(_strings.saveButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(_strings.saveButton));
      await tester.pumpAndSettle();

      final products = await firestore.collection('products').get();
      expect(products.docs, hasLength(1));
      final saved = products.docs.single.data();
      expect(saved['technologyIds'], [technologyId]);
      expect(saved['businessUnitIds'], [businessUnitId]);
    },
  );

  testWidgets(
    'quick-adding a Technology whose normalized name already exists reuses '
    'the existing record instead of creating a duplicate',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedBusinessUnit(firestore);
      final now = DateTime.utc(2024, 1, 1);
      final existing = await firestore.collection('technologies').add({
        'name': 'Flutter',
        'slug': 'flutter',
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore);
      await _fillRequiredProductFields(tester);
      await _openQuickAddDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, _strings.fieldTechnologyName),
        'flutter',
      );
      await tester.tap(find.text(_strings.addTechnologyDialogButton));
      await tester.pumpAndSettle();

      final technologies = await firestore.collection('technologies').get();
      expect(technologies.docs, hasLength(1));
      expect(technologies.docs.single.id, existing.id);
    },
  );

  testWidgets(
    'the full Technology form (Company Intelligence -> Technologies) still '
    'works unchanged, with every field and no quick-add caption',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            businessUnitServiceProvider.overrideWithValue(
              BusinessUnitService(firestore: firestore),
            ),
            capabilityServiceProvider.overrideWithValue(
              CapabilityService(firestore: firestore),
            ),
            industryServiceProvider.overrideWithValue(
              IndustryService(firestore: firestore),
            ),
            technologyServiceProvider.overrideWithValue(
              TechnologyService(firestore: firestore),
            ),
            productServiceProvider.overrideWithValue(
              ProductService(firestore: firestore),
            ),
          ],
          child: const MaterialApp(home: TechnologyFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_strings.newTechnologyTitle), findsOneWidget);
      expect(
        find.text(_strings.fieldTechnologyName, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologySlug, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologySummary, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldStatus, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologyVendor, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologyWebsite, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologyKeywords, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.fieldTechnologyTags, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.relatedBusinessUnitsLabel, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.relatedProductsLabel, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(_strings.relatedCapabilitiesLabel, skipOffstage: false),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, _strings.fieldTechnologyNotes),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.widgetWithText(
          TextFormField,
          _strings.fieldTechnologyNotes,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text(_strings.quickAddTechnologyCaption, skipOffstage: false),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, _strings.fieldTechnologyName),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, _strings.fieldTechnologyName),
        'Firebase',
      );
      await tester.scrollUntilVisible(
        find.text(_strings.saveButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(_strings.saveButton));
      await tester.pumpAndSettle();

      final technologies = await firestore.collection('technologies').get();
      expect(technologies.docs, hasLength(1));
      expect(technologies.docs.single.data()['name'], 'Firebase');
    },
  );
}
