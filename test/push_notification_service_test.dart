import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/push_notification_service.dart';

void main() {
  group('opportunityIdFromMessageData', () {
    test('returns the opportunityId when present and non-empty', () {
      expect(
        opportunityIdFromMessageData({
          'opportunityId': 'opp-1',
          'type': 'matchScore',
        }),
        'opp-1',
      );
    });

    test('returns null when the key is missing', () {
      expect(opportunityIdFromMessageData({'type': 'matchScore'}), isNull);
    });

    test('returns null when the value is an empty string', () {
      expect(opportunityIdFromMessageData({'opportunityId': ''}), isNull);
    });

    test('returns null when the value is not a string', () {
      expect(opportunityIdFromMessageData({'opportunityId': 42}), isNull);
    });

    test('returns null for an empty data map', () {
      expect(opportunityIdFromMessageData(const {}), isNull);
    });
  });
}
