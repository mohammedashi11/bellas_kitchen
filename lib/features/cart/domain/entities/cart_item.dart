import '../../../menu/domain/entities/menu_item.dart';

/// A single line in the cart: a [MenuItem] plus its quantity.
/// Pure Dart — no Flutter/Firebase dependencies.
class CartItem {
  final MenuItem item;
  final int quantity;

  const CartItem({required this.item, required this.quantity});

  /// Line subtotal (unit price × quantity).
  double get lineTotal => item.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(item: item, quantity: quantity ?? this.quantity);
}
