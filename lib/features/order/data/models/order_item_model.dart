import '../../domain/entities/order_add_on.dart';
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
    super.addOns,
  });

  /// Reads the frozen `addOns` array. Missing/malformed → empty, so orders
  /// placed before add-ons existed keep reading cleanly. Only name + price are
  /// stored: an order snapshot must not point at a live menu definition.
  static List<OrderAddOn> _readAddOns(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => OrderAddOn(
              name: m[AppConstants.fieldName] as String? ?? '',
              price: (m[AppConstants.fieldPrice] as num?)?.toDouble() ?? 0.0,
            ))
        .toList(growable: false);
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      menuItemId: data[AppConstants.fieldMenuItemId] as String? ?? '',
      name: data[AppConstants.fieldName] as String? ?? '',
      price: (data[AppConstants.fieldPrice] as num?)?.toDouble() ?? 0.0,
      quantity: (data[AppConstants.fieldQuantity] as num?)?.toInt() ?? 0,
      addOns: _readAddOns(data[AppConstants.fieldAddOns]),
    );
  }

  Map<String, dynamic> toMap() => {
        AppConstants.fieldMenuItemId: menuItemId,
        AppConstants.fieldName: name,
        AppConstants.fieldPrice: price,
        AppConstants.fieldQuantity: quantity,
        AppConstants.fieldAddOns: [
          for (final a in addOns)
            {
              AppConstants.fieldName: a.name,
              AppConstants.fieldPrice: a.price,
            },
        ],
      };
}
