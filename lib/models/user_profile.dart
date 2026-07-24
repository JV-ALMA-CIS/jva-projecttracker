import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, user }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.user => 'User',
  };

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.user,
    );
  }
}

/// A staff account. Created by the client at sign-up (see
/// `UserService.createOwnProfile`), always with role "user" — firestore.rules
/// rejects any other role on create, and forbids client updates entirely, so
/// promotion to "admin" can only be done by hand in the Firebase console.
class UserProfile {
  final String uid;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'user'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
