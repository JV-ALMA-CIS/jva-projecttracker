import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/company_intelligence/company_intelligence_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/products/products_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

void main() {
  testWidgets('mobile viewport: no overflow and cards are tappable', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: CompanyIntelligenceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final productsCard = find.ancestor(
      of: find.text(_strings.productsTitle),
      matching: find.byType(InkWell),
    );
    await tester.scrollUntilVisible(
      productsCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(productsCard, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductsScreen), findsOneWidget);
  });
}
