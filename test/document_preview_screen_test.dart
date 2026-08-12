import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/documents/document_preview_screen.dart';
import 'package:jva_projecttracker/services/company_intelligence/business_unit_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/capability_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/experience_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/industry_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/knowledge_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/product_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/service_service.dart';
import 'package:jva_projecttracker/services/company_intelligence/technology_service.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';
import 'package:jva_projecttracker/services/opportunity_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/proposal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  String documentId,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDocumentServiceProvider.overrideWithValue(
          LibraryDocumentService(firestore: firestore),
        ),
        proposalServiceProvider.overrideWithValue(
          ProposalService(firestore: firestore),
        ),
        opportunityServiceProvider.overrideWithValue(
          OpportunityService(firestore: firestore),
        ),
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
      ],
      child: MaterialApp(home: DocumentPreviewScreen(documentId: documentId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('renders the document metadata header', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    final doc = await firestore.collection('documents').add({
      'title': 'ISO 9001 Certificate',
      'category': 'isoCertificate',
      'version': '2024',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, doc.id);

    expect(find.text('ISO 9001 Certificate'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
  });

  testWidgets('toggling a related business unit persists the change', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    final doc = await firestore.collection('documents').add({
      'title': 'Company Profile',
      'category': 'companyProfile',
      'createdAt': now,
      'updatedAt': now,
    });
    await firestore.collection('businessUnits').add({
      'name': 'Construction',
      'slug': 'construction',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, doc.id);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, 'Construction'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilterChip, 'Construction'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final updated = await firestore.collection('documents').doc(doc.id).get();
    expect(updated.data()!['businessUnitIds'], isNotEmpty);
  });

  testWidgets(
    'a document with an expired date shows the expired chip instead of its status',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      final doc = await firestore.collection('documents').add({
        'title': 'Expired Insurance',
        'category': 'insurance',
        'expiryDate': now.subtract(const Duration(days: 5)),
        'createdAt': now,
        'updatedAt': now,
      });

      await _pumpScreen(tester, firestore, doc.id);

      expect(find.text(_strings.expiredDocumentsCountLabel(1)), findsOneWidget);
    },
  );
}
