/// A single line within an [Order]. Pure Dart.
///
/// This is a FROZEN SNAPSHOT captured at checkout — it deliberately does NOT
/// hold a live [MenuItem] reference. Menu prices/names change over time, but a
/// placed order must preserve exactly what was ordered and what was charged.
/// Only [menuItemId] links back to the (possibly since-changed) menu item.
class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  /// Line subtotal (unit price × quantity), computed from the frozen price.
  double get lineTotal => price * quantity;
}
