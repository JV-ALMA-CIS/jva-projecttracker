import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/company_intelligence/business_units/business_unit_workspace_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/opportunity_event_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/project_service.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/recommendation_service.dart';
import 'package:jva_projecttracker/services/submission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<String> _seedBusinessUnit(FakeFirebaseFirestore firestore) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('businessUnits').add({
    'name': 'Information Technology',
    'slug': 'information-technology',
    'summary': 'IT services and software delivery.',
    'description': '',
    'status': 'active',
    'productIds': const [],
    'serviceIds': const [],
    'createdAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<String> _seedOpportunity(
  FakeFirebaseFirestore firestore,
  String businessUnitId,
) async {
  final now = DateTime.utc(2024, 1, 1);
  final doc = await firestore.collection('opportunities').add({
    'title': 'Rural water monitoring platform',
    'description': 'A monitoring platform tender',
    'sourceUrl': 'https://example.com/tender/2',
    'fitScorePercent': 80,
    'status': 'discovered',
    'pipelineStage': 'qualified',
    'businessUnitIds': [businessUnitId],
    'discoveredAt': now,
    'updatedAt': now,
  });
  return doc.id;
}

Future<void> _seedProduct(
  FakeFirebaseFirestore firestore,
  String businessUnitId,
) async {
  final now = DateTime.utc(2024, 1, 1);
  await firestore.collection('products').add({
    'name': 'ALMA Works',
    'slug': 'alma-works',
    'businessUnitId': businessUnitId,
    'status': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String businessUnitId,
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
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
        proposalServiceProvider.overrideWithValue(
          ProposalService(firestore: firestore),
        ),
        submissionServiceProvider.overrideWithValue(
          SubmissionService(firestore: firestore),
        ),
        projectServiceProvider.overrideWithValue(
          ProjectService(firestore: firestore),
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
        recommendationServiceProvider.overrideWithValue(
          RecommendationService(firestore: firestore),
        ),
        opportunityEventServiceProvider.overrideWithValue(
          OpportunityEventService(firestore: firestore),
        ),
      ],
      child: MaterialApp(
        home: BusinessUnitWorkspaceScreen(businessUnitId: businessUnitId),
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
    'shows the business unit name, an active opportunity, and a linked product',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final businessUnitId = await _seedBusinessUnit(firestore);
      await _seedOpportunity(firestore, businessUnitId);
      await _seedProduct(firestore, businessUnitId);

      await _pumpScreen(tester, firestore, businessUnitId);

      expect(find.text('Information Technology'), findsOneWidget);
      // Only the KPI tile is mounted this close to the top — the section
      // header further down (sharing the same wording) isn't in the
      // viewport/cache range yet.
      expect(find.text(_strings.activeOpportunitiesLabel), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // The opportunity row now sits below the fold — the AI Summary of
      // Expertise card pushed content further down, and `ListView` only
      // mounts elements near the viewport, so it must be scrolled into
      // view before `find.text` can see it, same as the existing
      // productsTitle scroll below.
      await tester.scrollUntilVisible(
        find.text('Rural water monitoring platform'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rural water monitoring platform'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(_strings.productsTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(_strings.productsTitle));
      await tester.pumpAndSettle();
      expect(find.text('ALMA Works'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the empty-data message for a business unit with nothing linked',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final businessUnitId = await _seedBusinessUnit(firestore);

      await _pumpScreen(tester, firestore, businessUnitId);

      await tester.scrollUntilVisible(
        find.text(_strings.noBusinessUnitDataMessage),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_strings.noBusinessUnitDataMessage), findsOneWidget);
    },
  );
}
