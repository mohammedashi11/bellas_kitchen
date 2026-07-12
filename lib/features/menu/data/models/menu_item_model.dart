import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/menu_item.dart';
import '../../../../core/constants/app_constants.dart';

/// Data-layer model: extends MenuItem and adds Firestore serialisation.
class MenuItemModel extends MenuItem {
  MenuItemModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.imageUrl,
    required super.category,
    required super.createdAt,
    super.isBestSeller,
    super.isAvailable,
  });

  /// Reads a Firestore [Timestamp] into a [DateTime], falling back to the Unix
  /// epoch when the field is missing (e.g. a doc written before this field
  /// existed) so ordering degrades gracefully instead of throwing.
  static DateTime _readCreatedAt(Object? raw) =>
      (raw is Timestamp) ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  /// Construct from a Firestore [DocumentSnapshot].
  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItemModel.fromMap(doc.id, data);
  }

  /// Construct from a raw [Map] (e.g., from QueryDocumentSnapshot.data()).
  factory MenuItemModel.fromMap(String id, Map<String, dynamic> data) {
    return MenuItemModel(
      id: id,
      name: data[AppConstants.fieldName] as String? ?? '',
      description: data[AppConstants.fieldDescription] as String? ?? '',
      price: (data[AppConstants.fieldPrice] as num?)?.toDouble() ?? 0.0,
      imageUrl: data[AppConstants.fieldImageUrl] as String? ?? '',
      category: data[AppConstants.fieldCategory] as String? ??
          AppConstants.defaultCategory,
      isBestSeller: data[AppConstants.fieldIsBestSeller] as bool? ?? false,
      isAvailable: data[AppConstants.fieldIsAvailable] as bool? ?? true,
      createdAt: _readCreatedAt(data[AppConstants.fieldCreatedAt]),
    );
  }

  /// Serialise for writing to Firestore on create.
  ///
  /// `createdAt` is written as [FieldValue.serverTimestamp] so the server, not
  /// the client clock, stamps the creation time. The in-memory [createdAt] is
  /// only used for reads/ordering.
  Map<String, dynamic> toFirestore() => {
        AppConstants.fieldName: name,
        AppConstants.fieldDescription: description,
        AppConstants.fieldPrice: price,
        AppConstants.fieldImageUrl: imageUrl,
        AppConstants.fieldCategory: category,
        AppConstants.fieldIsBestSeller: isBestSeller,
        AppConstants.fieldIsAvailable: isAvailable,
        AppConstants.fieldCreatedAt: FieldValue.serverTimestamp(),
      };
}
