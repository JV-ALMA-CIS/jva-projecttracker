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
}
