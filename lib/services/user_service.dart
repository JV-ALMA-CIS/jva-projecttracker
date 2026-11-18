import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jva_projecttracker/models/user_profile.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  Stream<UserProfile?> watch(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.id, doc.data()!);
    });
  }

  /// Creates the caller's own profile at sign-up, always as role "user" —
  /// firestore.rules rejects any other role here. Promotion to admin is a
  /// manual edit in the Firebase console.
  Future<void> createOwnProfile(String uid, String email) {
    return _collection.doc(uid).set({
      'email': email,
      'role': 'user',
      'createdAt': Timestamp.now(),
    });
  }

  /// Creates the caller's profile if it's missing — called on every
  /// sign-in. Accounts created outside the app's sign-up screen (Firebase
  /// console, an older build, ...) otherwise have no `users/{uid}` doc, so
  /// the app shows no role for them and admins can't see them. Never
  /// overwrites an existing profile (rules forbid client updates anyway).
  Future<void> ensureOwnProfile(String uid, String? email) async {
    final doc = await _collection.doc(uid).get();
    if (doc.exists) return;
    try {
      await createOwnProfile(uid, email ?? '');
    } on FirebaseException {
      // Sign-up and the sign-in hook can race to create it; a second create
      // is an update, which the rules reject. Fine if the doc now exists.
      final again = await _collection.doc(uid).get();
      if (!again.exists) rethrow;
    }
  }
}
