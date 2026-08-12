import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/screens/company_intelligence/experiences/experiences_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
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
        experienceServiceProvider.overrideWithValue(
          ExperienceService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: ExperiencesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when there are no experiences', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noExperiencesYet), findsOneWidget);
    // Two "add" affordances now — the FAB (always available) and the
    // EmptyState's own primary create action (B1: "not FAB-only").
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });

  testWidgets('shows an experience card once data loads', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 1, 1);
    await ExperienceService(firestore: firestore).create(
      Experience(
        id: '',
        title: 'Rural electrification project',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpScreen(tester, firestore);

    expect(find.text('Rural electrification project'), findsOneWidget);
  });

  testWidgets('search narrows the visible list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ExperienceService(firestore: firestore);
    final now = DateTime.utc(2024, 1, 1);
    await service.create(
      Experience(
        id: '',
        title: 'Water project',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await service.create(
      Experience(id: '', title: 'Road project', createdAt: now, updatedAt: now),
    );

    await _pumpScreen(tester, firestore);
    expect(find.text('Water project'), findsOneWidget);
    expect(find.text('Road project'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Water');
    await tester.pumpAndSettle();

    expect(find.text('Water project'), findsOneWidget);
    expect(find.text('Road project'), findsNothing);
  });
}
