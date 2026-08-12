import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/documents/document_library_screen.dart';
import 'package:jva_projecttracker/services/library_document_service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = AppStrings(Locale('en'));

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore, {
  String? proposalId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDocumentServiceProvider.overrideWithValue(
          LibraryDocumentService(firestore: firestore),
        ),
      ],
      child: MaterialApp(home: DocumentLibraryScreen(proposalId: proposalId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('shows the empty state when no documents exist', (tester) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    expect(find.text(_strings.noDocumentsYet), findsOneWidget);
  });

  testWidgets('renders a document tile once documents are loaded', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    await firestore.collection('documents').add({
      'title': 'ISO 9001 Certificate',
      'category': 'isoCertificate',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore);

    expect(find.text('ISO 9001 Certificate'), findsOneWidget);
  });

  testWidgets('search filters documents by title', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    await firestore.collection('documents').add({
      'title': 'ISO 9001 Certificate',
      'category': 'isoCertificate',
      'createdAt': now,
      'updatedAt': now,
    });
    await firestore.collection('documents').add({
      'title': 'Tax Compliance Certificate',
      'category': 'taxCertificate',
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore);
    await tester.enterText(find.byType(SearchBar), 'Tax');
    await tester.pumpAndSettle();

    expect(find.text('Tax Compliance Certificate'), findsOneWidget);
    expect(find.text('ISO 9001 Certificate'), findsNothing);
  });

  testWidgets('scoped to a proposal, only documents linked to it are shown', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    await firestore.collection('documents').add({
      'title': 'Linked document',
      'category': 'other',
      'relatedProposalIds': ['proposal-1'],
      'createdAt': now,
      'updatedAt': now,
    });
    await firestore.collection('documents').add({
      'title': 'Unrelated document',
      'category': 'other',
      'relatedProposalIds': ['proposal-2'],
      'createdAt': now,
      'updatedAt': now,
    });

    await _pumpScreen(tester, firestore, proposalId: 'proposal-1');

    expect(find.text('Linked document'), findsOneWidget);
    expect(find.text('Unrelated document'), findsNothing);
  });

  testWidgets('the add-document dialog disables Save until a file is chosen', (
    tester,
  ) async {
    await _pumpScreen(tester, FakeFirebaseFirestore());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, _strings.fieldDocumentTitle),
      'New Certificate',
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _strings.addDocumentButton),
    );
    expect(saveButton.onPressed, isNull);
  });
}
