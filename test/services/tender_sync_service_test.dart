import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/tender_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class FakeHttpsCallableResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  FakeHttpsCallableResult(this.data);
  @override
  final Map<String, dynamic> data;
}

void main() {
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late TenderSyncService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    when(
      () => functions.httpsCallable(
        'runTenderSourceSync',
        options: any(named: 'options'),
      ),
    ).thenReturn(callable);
    service = TenderSyncService(functions: functions);
  });

  group('TenderSyncService.runSource', () {
    test('calls runTenderSourceSync with sourceId + manual trigger and '
        'returns opportunitiesCreated', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => FakeHttpsCallableResult({'opportunitiesCreated': 3}),
      );

      final created = await service.runSource('src-1');

      expect(created, 3);
      final captured =
          verify(
                () => callable.call<Map<String, dynamic>>(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['sourceId'], 'src-1');
      expect(captured['trigger'], 'manual');
    });

    test('defaults to 0 when opportunitiesCreated is missing', () async {
      when(
        () => callable.call<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => FakeHttpsCallableResult({}));

      final created = await service.runSource('src-1');

      expect(created, 0);
    });

    test('wraps FirebaseFunctionsException as TenderSyncException', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'No connector registered for discovery method "unknown".',
          code: 'unimplemented',
        ),
      );

      expect(
        () => service.runSource('src-1'),
        throwsA(
          isA<TenderSyncException>().having(
            (e) => e.message,
            'message',
            contains('No connector registered'),
          ),
        ),
      );
    });
  });
}
