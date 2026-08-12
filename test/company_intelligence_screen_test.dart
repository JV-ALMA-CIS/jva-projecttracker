import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/company_intelligence/company_intelligence_screen.dart';
import 'package:jva_projecttracker/screens/company_intelligence/technologies/technologies_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
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
        businessUnitServiceProvider.overrideWithValue(
          BusinessUnitService(firestore: firestore),
        ),
        productServiceProvider.overrideWithValue(
          ProductService(firestore: firestore),
        ),
        serviceServiceProvider.overrideWithValue(
          ServiceService(firestore: firestore),
        ),
        capabilityServiceProvider.overrideWithValue(
          CapabilityService(firestore: firestore),
        ),
        technologyServiceProvider.overrideWithValue(
          TechnologyService(firestore: firestore),
        ),
        industryServiceProvider.overrideWithValue(
          IndustryService(firestore: firestore),
        ),
        experienceServiceProvider.overrideWithValue(
          ExperienceService(firestore: firestore),
        ),
        knowledgeServiceProvider.overrideWithValue(
          KnowledgeService(firestore: firestore),
        ),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
      ],
      child: const MaterialApp(home: CompanyIntelligenceScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _seedBusinessUnit(
  FakeFirebaseFirestore firestore,
  String name, {
  DateTime? updatedAt,
}) async {
  final now = updatedAt ?? DateTime.utc(2024, 1, 1);
  await firestore.collection('businessUnits').add({
    'name': name,
    'slug': name.toLowerCase(),
    'status': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
}

Future<void> _seedCapability(
  FakeFirebaseFirestore firestore,
  String name,
) async {
  final now = DateTime.utc(2024, 1, 1);
  await firestore.collection('capabilities').add({
    'name': name,
    'status': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('renders a card for each entity type with its live count', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedBusinessUnit(firestore, 'Water Infrastructure');
    await _seedBusinessUnit(firestore, 'Digital Services');

    await _pumpScreen(tester, firestore);

    expect(find.text(_strings.businessUnitsTitle), findsOneWidget);
    // findsWidgets, not findsOneWidget: the business unit card's own count
    // and the executive summary's total-knowledge-items count both
    // legitimately read "2" here (2 business units, nothing else seeded).
    expect(find.text('2'), findsWidgets);
  });

  testWidgets(
    'shows the capability-gap health chip for a type with no referencing opportunities',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedCapability(firestore, 'Water network design');

      await _pumpScreen(tester, firestore);

      expect(
        find.text(_strings.knowledgeHealthLabel(KnowledgeHealth.gap)),
        findsWidgets,
      );
    },
  );

  testWidgets('the executive summary totals knowledge items across all types', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedBusinessUnit(firestore, 'Water Infrastructure');
    await _seedCapability(firestore, 'Water network design');

    await _pumpScreen(tester, firestore);

    expect(find.text(_strings.totalKnowledgeItemsLabel), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('tapping the Technologies card opens the Technologies screen', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.scrollUntilVisible(
      find.text(_strings.technologiesTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(_strings.technologiesTitle),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TechnologiesScreen), findsOneWidget);
  });
}
