import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/utils/external_url.dart';

void main() {
  group('normalizeExternalUrl', () {
    test('returns null for an empty string', () {
      expect(normalizeExternalUrl(''), isNull);
      expect(normalizeExternalUrl('   '), isNull);
    });

    test('returns null for a relative path', () {
      expect(normalizeExternalUrl('/some/path'), isNull);
    });

    test('prepends https:// when the string looks like a bare domain', () {
      final uri = normalizeExternalUrl('example.com/tender/1');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'example.com');
    });

    test('preserves an explicit http/https scheme', () {
      final uri = normalizeExternalUrl('http://example.com');
      expect(uri!.scheme, 'http');
    });

    test('rejects a non-http(s) scheme', () {
      expect(normalizeExternalUrl('ftp://example.com'), isNull);
    });

    test('rejects a real Gemini Google Search grounding-tool citation link '
        '(vertexaisearch.cloud.google.com/grounding-api-redirect/...) — the '
        'marker is in the path, not the host', () {
      expect(
        normalizeExternalUrl(
          'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AXQE123',
        ),
        isNull,
      );
    });

    test('does not reject a real vertexaisearch.cloud.google.com URL that is '
        'not a grounding-redirect path', () {
      expect(
        normalizeExternalUrl('https://vertexaisearch.cloud.google.com/other'),
        isNotNull,
      );
    });

    test('does not reject a legitimate tender URL that merely mentions '
        '"grounding-api-redirect" as an unrelated query string value', () {
      // Regression guard: the check must key on the real host+path shape,
      // not just search for the substring anywhere in the URL.
      expect(
        normalizeExternalUrl(
          'https://tenders.example.com/view?ref=grounding-api-redirect-2024',
        ),
        isNotNull,
      );
    });
  });

  group('isGroundingRedirectStub', () {
    test('true for the real Gemini grounding-redirect URL shape', () {
      final uri = Uri.parse(
        'https://vertexaisearch.cloud.google.com/grounding-api-redirect/AXQE123',
      );
      expect(isGroundingRedirectStub(uri), isTrue);
    });

    test('false for an unrelated host', () {
      final uri = Uri.parse(
        'https://example.com/grounding-api-redirect/AXQE123',
      );
      expect(isGroundingRedirectStub(uri), isFalse);
    });

    test(
      'false for vertexaisearch.cloud.google.com without the redirect path',
      () {
        final uri = Uri.parse('https://vertexaisearch.cloud.google.com/other');
        expect(isGroundingRedirectStub(uri), isFalse);
      },
    );
  });
}
