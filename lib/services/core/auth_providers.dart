import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/user_profile.dart';
import 'package:jva_projecttracker/services/auth_service.dart';
import 'package:jva_projecttracker/services/user_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final userServiceProvider = Provider((ref) => UserService());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in user's Firestore profile (including role), or null if
/// signed out or the profile hasn't been created yet.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watch(user.uid);
});
