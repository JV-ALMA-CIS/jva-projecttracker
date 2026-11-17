/// AI-generated text (recommendations, executive insights) sometimes
/// contains raw Firestore document IDs such as `[aB3xK9pQ2mZ7rT1vW8yL]`
/// instead of the tender's name — the model is shown those IDs so it can
/// return structured references, and occasionally copies them into prose.
/// [humanizeIds] swaps each ID for the entry's name (or drops it when the
/// name isn't known), so staff see readable text.
///
/// Mirrors `functions/lib/humanizeIds.js`, which cleans new AI output on the
/// server; this side cleans text that was stored before that existed. Keep
/// the two in sync.
library;

final RegExp _idPattern = RegExp(
  r'\[([A-Za-z0-9]{20})\]|\(([A-Za-z0-9]{20})\)|\b([A-Za-z0-9]{20})\b',
);

/// True when a 20-char token looks like a generated ID rather than a word:
/// it contains a digit, or mixes upper and lower case.
bool looksLikeGeneratedId(String token) {
  return RegExp(r'\d').hasMatch(token) ||
      (RegExp(r'[a-z]').hasMatch(token) && RegExp(r'[A-Z]').hasMatch(token));
}

/// Replaces generated IDs in [text] with `"Name"` from [namesById], or
/// removes them when unknown, then tidies leftover spacing/punctuation.
String humanizeIds(String text, Map<String, String> namesById) {
  if (text.isEmpty) return text;

  final replaced = text.replaceAllMapped(_idPattern, (match) {
    final id = match.group(1) ?? match.group(2) ?? match.group(3)!;
    if (!looksLikeGeneratedId(id)) return match.group(0)!;
    final name = namesById[id];
    return name == null || name.isEmpty ? '' : '"$name"';
  });

  return replaced
      .replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAllMapped(RegExp(r'\s+([.,;:!?)])'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'\(\s+'), '(')
      .trim();
}
