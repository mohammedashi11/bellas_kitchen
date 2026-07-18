// Import only what's needed: cloud_firestore also exports an `Order` enum,
// which would clash with our domain `Order` entity below.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue;
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment_method.dart';
import '../../../../core/constants/app_constants.dart';
import 'order_item_model.dart';

/// Data-layer model for [Order] with Firestore serialisation.
///
/// The order document owns its line [items] as a nested array of maps (see
/// [OrderItemModel]). `status` and `payment` are stored as their enum
/// `storageKey` strings. `createdAt` is server-stamped on create; `updatedAt`
/// is server-stamped on every write.
class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.userId,
    required super.items,
    required super.subtotal,
    required super.tax,
    required super.total,
    required super.status,
    required super.payment,
    required super.createdAt,
    required super.updatedAt,
  });

  static DateTime _readTime(Object? raw) =>
      (raw is Timestamp) ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    final rawItems =
        (data[AppConstants.fieldItems] as List<dynamic>?) ?? const [];
    return OrderModel(
      id: id,
      userId: data[AppConstants.fieldUserId] as String? ?? '',
      items: rawItems
          .map((e) => OrderItemModel.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: (data[AppConstants.fieldSubtotal] as num?)?.toDouble() ?? 0.0,
      tax: (data[AppConstants.fieldTax] as num?)?.toDouble() ?? 0.0,
      total: (data[AppConstants.fieldTotal] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromStorage(data[AppConstants.fieldStatus] as String?),
      payment:
          PaymentMethod.fromStorage(data[AppConstants.fieldPayment] as String?),
      createdAt: _readTime(data[AppConstants.fieldCreatedAt]),
      updatedAt: _readTime(data[AppConstants.fieldUpdatedAt]),
    );
  }

  /// Serialise for writing to Firestore.
  ///
  /// `createdAt`/`updatedAt` use [FieldValue.serverTimestamp]. On create both
  /// are stamped; for an update the caller should omit `createdAt` (not modelled
  /// here yet, since no OrderRepository exists).
  Map<String, dynamic> toFirestore() => {
        AppConstants.fieldUserId: userId,
        AppConstants.fieldItems: items
            .map((i) => OrderItemModel(
                  menuItemId: i.menuItemId,
                  name: i.name,
                  price: i.price,
                  quantity: i.quantity,
                  // MUST be carried through. Omitting this silently dropped
                  // every selected add-on at write time: the customer was
                  // charged for them (they are inside subtotal/total) while the
                  // stored document showed a bare line item.
                  addOns: i.addOns,
                ).toMap())
            .toList(),
        AppConstants.fieldSubtotal: subtotal,
        AppConstants.fieldTax: tax,
        AppConstants.fieldTotal: total,
        AppConstants.fieldStatus: status.storageKey,
        AppConstants.fieldPayment: payment.storageKey,
        AppConstants.fieldCreatedAt: FieldValue.serverTimestamp(),
        AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      };
}
