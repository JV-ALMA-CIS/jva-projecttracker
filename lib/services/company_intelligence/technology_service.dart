import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/services/slugify.dart';

class TechnologyService {
  TechnologyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('technologies');

  Stream<List<Technology>> watchAll() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Technology.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Technology?> watchById(String id) {
    return _collection
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? Technology.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Finds an existing Technology whose `slug` matches [name] once both are
  /// normalized via [slugify] — e.g. "Google Gemini / Gemini AI" and
  /// "google gemini/gemini-ai " both slug to the same key. Used by [create]
  /// to prevent duplicate records when the same technology is entered twice
  /// (once via the standalone Technology form, once via a Product form's
  /// "+ Add Technology" quick-create) — both paths funnel through this same
  /// service method, so there is exactly one place duplicate-prevention has
  /// to live.
  Future<Technology?> findByNormalizedName(String name) async {
    final targetSlug = slugify(name);
    final snapshot = await _collection
        .where('slug', isEqualTo: targetSlug)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Technology.fromMap(doc.id, doc.data());
  }

  /// Creates [technology], unless one with the same normalized name (see
  /// [findByNormalizedName]) already exists — in which case that existing
  /// document's id is returned instead and nothing new is written. Every
  /// creation path (manual entry, AI-assisted, quick-add from a Product
  /// form) should call this rather than writing to Firestore directly, so
  /// duplicate prevention can never be bypassed by a caller that forgets to
  /// check first.
  ///
  /// The dedup lookup always keys off [slugify] of [technology.name] — see
  /// [findByNormalizedName] — regardless of what [technology.slug] the
  /// caller supplied, so a custom user-typed slug can never hide a genuine
  /// duplicate name from detection. The *stored* slug still respects the
  /// caller's own value when they provided one (the Technology form's slug
  /// field is user-editable, unlike Product's auto-derived one), and only
  /// falls back to [slugify] of the name when left blank.
  Future<String> create(Technology technology) async {
    final existing = await findByNormalizedName(technology.name);
    if (existing != null) return existing.id;

    final toWrite = technology.slug.trim().isEmpty
        ? Technology(
            id: technology.id,
            name: technology.name,
            slug: slugify(technology.name),
            summary: technology.summary,
            description: technology.description,
            category: technology.category,
            vendor: technology.vendor,
            website: technology.website,
            keywords: technology.keywords,
            tags: technology.tags,
            status: technology.status,
            notes: technology.notes,
            businessUnitIds: technology.businessUnitIds,
            productIds: technology.productIds,
            capabilityIds: technology.capabilityIds,
            aiExpertiseSummary: technology.aiExpertiseSummary,
            aiExpertiseHighlights: technology.aiExpertiseHighlights,
            aiExpertiseSummaryGeneratedAt:
                technology.aiExpertiseSummaryGeneratedAt,
            createdAt: technology.createdAt,
            updatedAt: technology.updatedAt,
          )
        : technology;

    final doc = await _collection.add(toWrite.toMap());
    return doc.id;
  }

  Future<void> update(Technology technology) {
    return _collection.doc(technology.id).update(technology.toMap());
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
