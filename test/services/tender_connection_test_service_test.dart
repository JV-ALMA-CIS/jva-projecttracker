import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/services/tender_connection_test_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class FakeHttpsCallableResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  FakeHttpsCallableResult(this.data);
  @override
  final Map<String, dynamic> data;
}

TenderSource _draft() {
  final now = DateTime(2026, 1, 1);
  return TenderSource(
    id: '',
    name: 'Test Source',
    organization: 'Test Org',
    category: TenderSourceCategory.ngo,
    discoveryMethod: TenderDiscoveryMethod.rss,
    connectorConfig: const {'feedUrl': 'https://example.com/feed.xml'},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late TenderConnectionTestService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    when(
      () => functions.httpsCallable('testTenderSourceConnection'),
    ).thenReturn(callable);
    service = TenderConnectionTestService(functions: functions);
  });

  group('TenderConnectionTestService.testSaved', () {
    test('sends sourceId and maps a successful result', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => FakeHttpsCallableResult({
          'ok': true,
          'message': 'Connected successfully — feed has 5 item(s).',
          'sampleCount': 5,
        }),
      );

      final result = await service.testSaved('src-1');

      expect(result.ok, isTrue);
      expect(result.sampleCount, 5);
      final captured =
          verify(
                () => callable.call<Map<String, dynamic>>(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['sourceId'], 'src-1');
      expect(captured.containsKey('draft'), isFalse);
    });
  });

  group('TenderConnectionTestService.testDraft', () {
    test('sends a draft payload built from the TenderSource', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => FakeHttpsCallableResult({
          'ok': false,
          'message': 'connectorConfig.feedUrl is required for RSS sources',
        }),
      );

      final result = await service.testDraft(_draft());

      expect(result.ok, isFalse);
      expect(result.sampleCount, isNull);
      final captured =
          verify(
                () => callable.call<Map<String, dynamic>>(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      final draft = captured['draft'] as Map<String, dynamic>;
      expect(draft['discoveryMethod'], 'rss');
      expect(draft['connectorConfig'], {
        'feedUrl': 'https://example.com/feed.xml',
      });
    });

    test('never sends sourceId for a draft test', () async {
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => FakeHttpsCallableResult({'ok': true, 'message': 'ok'}),
      );

      await service.testDraft(_draft());

      final captured =
          verify(
                () => callable.call<Map<String, dynamic>>(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured.containsKey('sourceId'), isFalse);
    });
  });

  group('TenderConnectionTestService — failure handling', () {
    test(
      'wraps FirebaseFunctionsException as ok:false rather than throwing',
      () async {
        when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
          FirebaseFunctionsException(
            message: 'deadline exceeded',
            code: 'deadline-exceeded',
          ),
        );

        final result = await service.testSaved('src-1');

        expect(result.ok, isFalse);
        expect(result.message, 'deadline exceeded');
      },
    );
  });
}
