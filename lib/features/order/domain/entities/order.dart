import 'order_item.dart';
import 'order_status.dart';
import 'payment_method.dart';

/// A placed order. Pure Dart — no Flutter/Firebase imports.
///
/// The pricing fields ([subtotal], [tax], [total]) and [items] are frozen at
/// checkout (see [OrderItem]). [userId] is the Firebase Auth UID of the owner.
///
/// Pickup-only: there is no delivery fee. `total` is exactly `subtotal + tax`.
class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final OrderStatus status;
  final PaymentMethod payment;
  final String deliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.payment,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total number of individual units across all line items.
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}
