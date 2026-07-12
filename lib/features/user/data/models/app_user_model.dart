import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue;
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../../../core/constants/app_constants.dart';

/// Data-layer model for [AppUser] with Firestore serialisation.
///
/// Stored in the `users` collection, one document per user keyed by [uid].
/// `createdAt` is server-stamped on create.
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.phoneNumber,
    super.displayName,
    super.savedAddresses,
    required super.createdAt,
    super.role,
  });

  static DateTime _readCreatedAt(Object? raw) =>
      (raw is Timestamp) ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  factory AppUserModel.fromMap(String id, Map<String, dynamic> data) {
    return AppUserModel(
      uid: id,
      phoneNumber: data[AppConstants.fieldPhoneNumber] as String? ?? '',
      displayName: data[AppConstants.fieldDisplayName] as String?,
      savedAddresses:
          (data[AppConstants.fieldSavedAddresses] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const [],
      createdAt: _readCreatedAt(data[AppConstants.fieldCreatedAt]),
      // Defensive: a missing/unknown role reads back as customer, never admin.
      role: UserRole.fromStorage(data[AppConstants.fieldRole] as String?),
    );
  }

  /// Serialise for writing to Firestore on create.
  /// `uid` is the document id, so it is not duplicated in the body.
  ///
  /// `role` is written ONLY for admins. Normal customer/anonymous creation omits
  /// it entirely (they read back as customer), and because an admin [AppUser]
  /// still serialises its `role: 'admin'`, a write never silently downgrades an
  /// admin. The app never sets `role` itself — admins are provisioned via the
  /// Firebase console.
  Map<String, dynamic> toFirestore() => {
        AppConstants.fieldPhoneNumber: phoneNumber,
        AppConstants.fieldDisplayName: displayName,
        AppConstants.fieldSavedAddresses: savedAddresses,
        AppConstants.fieldCreatedAt: FieldValue.serverTimestamp(),
        if (role == UserRole.admin) AppConstants.fieldRole: role.storageKey,
      };
}
