/// Converts [name] into a URL/id-safe slug: trimmed, lowercased, non
/// alphanumeric characters stripped, internal whitespace collapsed to
/// single hyphens. Purely a human-readable internal identifier — never a
/// public URL (a Product's `slug` field is not a Play Store/App Store
/// listing URL; see `Product.storeUrl` for that). Falls back to `'entity'`
/// for a name with no alphanumeric characters at all, matching the
/// convention already used by `ProjectExtractionReviewScreen._slugify`.
String slugify(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');
  return slug.isEmpty ? 'entity' : slug;
}
