import 'order_add_on.dart';

/// A single line within an [Order]. Pure Dart.
///
/// This is a FROZEN SNAPSHOT captured at checkout — it deliberately does NOT
/// hold a live [MenuItem] reference. Menu prices/names change over time, but a
/// placed order must preserve exactly what was ordered and what was charged.
/// Only [menuItemId] links back to the (possibly since-changed) menu item.
class OrderItem {
  final String menuItemId;
  final String name;

  /// The item's BASE unit price at checkout, excluding add-ons. Add-on prices
  /// are held separately in [addOns] so a receipt can itemise them; the charged
  /// unit price is [unitPrice].
  final double price;
  final int quantity;

  /// The add-ons selected for this line, frozen at checkout (name + price).
  /// Empty for a plain line, and the default when reading an order document
  /// written before add-ons existed.
  final List<OrderAddOn> addOns;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.addOns = const [],
  });

  /// Charged price of ONE unit: frozen base price plus frozen add-on prices.
  double get unitPrice =>
      price + addOns.fold<double>(0.0, (sum, a) => sum + a.price);

  /// Line subtotal (unit price × quantity), computed from the frozen prices.
  double get lineTotal => unitPrice * quantity;
}
