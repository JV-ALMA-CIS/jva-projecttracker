import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/screens/company_intelligence/industries/industries_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

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
        industryServiceProvider.overrideWithValue(
          IndustryService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: IndustriesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when there are no industries', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noIndustriesYet), findsOneWidget);
    // Two "add" affordances now — the FAB (always available) and the
    // EmptyState's own primary create action (B1: "not FAB-only").
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });

  testWidgets('shows an industry card once data loads', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 1, 1);
    await IndustryService(firestore: firestore).create(
      Industry(id: '', name: 'Agriculture', createdAt: now, updatedAt: now),
    );

    await _pumpScreen(tester, firestore);

    expect(find.text('Agriculture'), findsOneWidget);
  });

  testWidgets('search narrows the visible list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = IndustryService(firestore: firestore);
    final now = DateTime.utc(2024, 1, 1);
    await service.create(
      Industry(id: '', name: 'Agriculture', createdAt: now, updatedAt: now),
    );
    await service.create(
      Industry(id: '', name: 'Construction', createdAt: now, updatedAt: now),
    );

    await _pumpScreen(tester, firestore);
    expect(find.text('Agriculture'), findsOneWidget);
    expect(find.text('Construction'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Agri');
    await tester.pumpAndSettle();

    expect(find.text('Agriculture'), findsOneWidget);
    expect(find.text('Construction'), findsNothing);
  });
}
