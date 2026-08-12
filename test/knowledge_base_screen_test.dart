import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/screens/company_intelligence/knowledge_base/knowledge_base_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
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
        knowledgeServiceProvider.overrideWithValue(
          KnowledgeService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: KnowledgeBaseScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when there are no articles', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noKnowledgeArticlesYet), findsOneWidget);
    // Two "add" affordances now — the FAB (always available) and the
    // EmptyState's own primary create action (B1: "not FAB-only").
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });

  testWidgets('shows an article card once data loads', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2024, 1, 1);
    await KnowledgeService(firestore: firestore).create(
      KnowledgeArticle(
        id: '',
        title: 'Company Overview',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpScreen(tester, firestore);

    expect(find.text('Company Overview'), findsOneWidget);
  });

  testWidgets('search narrows the visible list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = KnowledgeService(firestore: firestore);
    final now = DateTime.utc(2024, 1, 1);
    await service.create(
      KnowledgeArticle(
        id: '',
        title: 'Bidding methodology',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await service.create(
      KnowledgeArticle(
        id: '',
        title: 'Onboarding checklist',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpScreen(tester, firestore);
    expect(find.text('Bidding methodology'), findsOneWidget);
    expect(find.text('Onboarding checklist'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Bidding');
    await tester.pumpAndSettle();

    expect(find.text('Bidding methodology'), findsOneWidget);
    expect(find.text('Onboarding checklist'), findsNothing);
  });
}
