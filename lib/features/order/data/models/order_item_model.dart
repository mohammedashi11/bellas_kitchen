import '../../domain/entities/order_item.dart';
import '../../../../core/constants/app_constants.dart';

/// Data-layer model for [OrderItem]. Order items are stored as an array of
/// maps nested inside the order document (not their own collection), so this
/// (de)serialises to/from a plain [Map] rather than a Firestore snapshot.
class OrderItemModel extends OrderItem {
  const OrderItemModel({
    required super.menuItemId,
    required super.name,
    required super.price,
    required super.quantity,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      menuItemId: data[AppConstants.fieldMenuItemId] as String? ?? '',
      name: data[AppConstants.fieldName] as String? ?? '',
      price: (data[AppConstants.fieldPrice] as num?)?.toDouble() ?? 0.0,
      quantity: (data[AppConstants.fieldQuantity] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        AppConstants.fieldMenuItemId: menuItemId,
        AppConstants.fieldName: name,
        AppConstants.fieldPrice: price,
        AppConstants.fieldQuantity: quantity,
      };
}
