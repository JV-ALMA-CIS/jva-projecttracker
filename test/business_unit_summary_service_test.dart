import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/business_unit_summary_service.dart';

void main() {
  test(
    'generateSummary forwards the requested businessUnitId to the invoke callback',
    () async {
      String? seenBusinessUnitId;
      final service = BusinessUnitSummaryService(
        invokeOverride: ({required businessUnitId}) async {
          seenBusinessUnitId = businessUnitId;
        },
      );

      await service.generateSummary(businessUnitId: 'bu-42');

      expect(seenBusinessUnitId, 'bu-42');
    },
  );

  test(
    'wraps an unexpected thrown error (e.g. a network failure) as BusinessUnitSummaryException',
    () async {
      final service = BusinessUnitSummaryService(
        invokeOverride: ({required businessUnitId}) async =>
            throw Exception('Gemini unavailable'),
      );

      expect(
        () => service.generateSummary(businessUnitId: 'bu-1'),
        throwsA(
          isA<BusinessUnitSummaryException>().having(
            (e) => e.toString(),
            'message',
            contains('Gemini unavailable'),
          ),
        ),
      );
    },
  );
}
