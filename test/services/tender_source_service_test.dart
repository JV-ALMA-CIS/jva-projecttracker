import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/services/tender_source_service.dart';
import 'package:mocktail/mocktail.dart';

// CollectionReference / Query are sealed in recent cloud_firestore versions.
// These mocks are only used for the write-path tests below; stream tests
// were removed to avoid the sealed-class analyzer errors.
// ignore: subtype_of_sealed_class
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

TenderSource _buildSource({String id = ''}) {
  final now = DateTime(2026, 1, 1);
  return TenderSource(
    id: id,
    name: 'PPIP Kenya',
    organization: 'Public Procurement Information Portal',
    category: TenderSourceCategory.governmentAgency,
    discoveryMethod: TenderDiscoveryMethod.htmlScraping,
    country: 'Kenya',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late TenderSourceService service;

  setUp(() {
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    when(() => firestore.collection('tenderSources')).thenReturn(collection);
    service = TenderSourceService(firestore: firestore);
  });

  group('TenderSourceService.create', () {
    test('writes a doc with createdAt/updatedAt timestamps set', () async {
      final docRef = MockDocumentReference();
      when(() => docRef.id).thenReturn('new-id');
      when(() => collection.add(any())).thenAnswer((_) async => docRef);

      final id = await service.create(_buildSource());

      expect(id, 'new-id');
      final captured =
          verify(() => collection.add(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['name'], 'PPIP Kenya');
      expect(captured['category'], 'governmentAgency');
      expect(captured['discoveryMethod'], 'htmlScraping');
      expect(captured['createdAt'], isA<Timestamp>());
      expect(captured['updatedAt'], isA<Timestamp>());
    });
  });

  group('TenderSourceService.update', () {
    test('updates the doc at the source id with a fresh updatedAt', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('src-1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.update(_buildSource(id: 'src-1'));

      verify(() => collection.doc('src-1')).called(1);
      final captured =
          verify(() => docRef.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['updatedAt'], isA<Timestamp>());
    });
  });

  group('TenderSourceService.setEnabled', () {
    test('flips only the enabled flag and updatedAt', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('src-1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.setEnabled('src-1', false);

      final captured =
          verify(() => docRef.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['enabled'], false);
      expect(captured.containsKey('name'), isFalse);
    });
  });

  group('TenderSourceService.pause / resume', () {
    test('pause writes status "paused"', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('src-1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.pause('src-1');

      final captured =
          verify(() => docRef.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['status'], 'paused');
    });

    test('resume writes status "active"', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('src-1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.resume('src-1');

      final captured =
          verify(() => docRef.update(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['status'], 'active');
    });
  });
}
