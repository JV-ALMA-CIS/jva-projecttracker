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

  group('foregroundAlertFrom', () {
    test(
      'uses the title, tag, link and stay-on-screen flag the server sends',
      () {
        final alert = foregroundAlertFrom({
          'type': 'newOpportunity',
          'opportunityId': 'abc',
          'title': 'New tender — 84% match',
          'body': 'Rosslyn roof',
          'tag': 'opp-abc',
          'link': 'https://jva-projecttracker.web.app/?opportunityId=abc',
          'sticky': '1',
          'channel': 'opportunities',
        })!;
        expect(alert.title, 'New tender — 84% match');
        expect(alert.body, 'Rosslyn roof');
        expect(alert.tag, 'opp-abc');
        expect(alert.sticky, isTrue);
        expect(alert.channel, 'opportunities');
      },
    );

    test('falls back to the notification block for older pushes', () {
      final alert = foregroundAlertFrom(
        {'type': 'deadline', 'opportunityId': 'x'},
        notificationTitle: 'Deadline tomorrow',
        notificationBody: 'Tender X',
      )!;
      expect(alert.title, 'Deadline tomorrow');
      expect(alert.tag, 'opp-x');
      expect(alert.link, '/?opportunityId=x');
      expect(alert.sticky, isFalse);
      expect(alert.channel, 'general');
    });

    test(
      'unknown channels fall back to general; no title means nothing to show',
      () {
        expect(
          foregroundAlertFrom({'title': 'Hi', 'channel': 'nope'})!.channel,
          'general',
        );
        expect(foregroundAlertFrom({'type': 'test'}), isNull);
      },
    );

    test(
      'the same tag always gives the same Android id (replaces, not stacks)',
      () {
        ForegroundAlert alertWithTag(String tag) =>
            foregroundAlertFrom({'title': 't', 'tag': tag})!;
        expect(
          alertWithTag('opp-abc').androidId,
          alertWithTag('opp-abc').androidId,
        );
        expect(
          alertWithTag('opp-abc').androidId,
          isNot(alertWithTag('opp-abd').androidId),
        );
        expect(alertWithTag('opp-abc').androidId, greaterThanOrEqualTo(0));
      },
    );
  });

  group('navigationDataFromLink', () {
    test('reads an opportunity link', () {
      expect(
        navigationDataFromLink(
          'https://jva-projecttracker.web.app/?opportunityId=a%20b',
        ),
        {'opportunityId': 'a b'},
      );
    });

    test('reads the inbox link', () {
      expect(navigationDataFromLink('/?open=inbox'), {'open': 'inbox'});
    });

    test('anything else opens nothing', () {
      expect(
        navigationDataFromLink('https://jva-projecttracker.web.app/'),
        isEmpty,
      );
    });
  });
}
