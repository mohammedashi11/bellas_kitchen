/// A user's access role. Pure Dart.
///
/// Stored on `users/{uid}.role`. The field is ABSENT for ordinary
/// customers/anonymous users (they're implicitly [customer]); only an admin doc
/// carries `role: 'admin'`, set manually via the Firebase console.
enum UserRole {
  customer,
  admin;

  /// String stored in Firestore (the enum name).
  String get storageKey => name;

  /// Defensive parse: ONLY the exact string `'admin'` grants admin access.
  /// Anything else — absent (null), `'customer'`, or an unknown value — is a
  /// [customer]. This never crashes and never accidentally elevates.
  static UserRole fromStorage(String? value) =>
      value == UserRole.admin.name ? UserRole.admin : UserRole.customer;
}
