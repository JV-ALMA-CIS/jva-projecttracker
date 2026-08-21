/// Validates a raw URL string before it's handed to `launchUrl`, so a bad
/// value (empty, relative, or a Gemini grounding-redirect stub that only
/// resolves inside Google's infrastructure) fails with a SnackBar instead of
/// silently opening `localhost` or a 404. This only checks the string is
/// *syntactically* a real external URL — it says nothing about whether the
/// site is actually reachable.
Uri? normalizeExternalUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed)
      ? trimmed
      : 'https://$trimmed';

  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (isGroundingRedirectStub(uri)) return null;

  return uri;
}

/// True when [uri] is one of Gemini's Google Search grounding-tool citation
/// links — `https://vertexaisearch.cloud.google.com/grounding-api-redirect/...`
/// — rather than a real, independently resolvable source page. The model
/// returns these as its "source" when Google Search grounding is used
/// (`ApiConnector._syncAiSearch` in functions/connectors/apiConnector.js),
/// but they're session-scoped citation redirects, not stable public URLs:
/// they frequently 404/error for a user opening them fresh later, which is
/// exactly the "source link doesn't work" symptom this check exists to
/// catch before a user ever clicks it.
///
/// The marker string lives in the URL's *path*
/// (`vertexaisearch.cloud.google.com/grounding-api-redirect/...`), not its
/// host — checking `uri.host` alone (as an earlier version of this function
/// did) never matches, since the host is just `vertexaisearch.cloud.google.com`.
bool isGroundingRedirectStub(Uri uri) {
  return uri.host.contains('vertexaisearch.cloud.google.com') &&
      uri.path.contains('grounding-api-redirect');
}
