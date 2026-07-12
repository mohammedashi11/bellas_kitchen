import 'user_role.dart';

/// Application user profile. Pure Dart — no Flutter/Firebase imports.
///
/// [uid] is the Firebase Auth UID and also the `users` document id. This entity
/// gates Auth and Order ownership (an [Order].userId references [uid]).
class AppUser {
  final String uid;
  final String phoneNumber;
  final String? displayName;
  final List<String> savedAddresses;
  final DateTime createdAt;

  /// Access role. Defaults to [UserRole.customer]; only an admin doc reads back
  /// as [UserRole.admin]. See [isAdmin].
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    this.savedAddresses = const [],
    required this.createdAt,
    this.role = UserRole.customer,
  });

  bool get isAdmin => role == UserRole.admin;
}
