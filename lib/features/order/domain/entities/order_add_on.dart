/// A selected add-on, FROZEN onto an [OrderItem] at checkout. Pure Dart.
///
/// Deliberately NOT the menu domain's `AddOn`: like [OrderItem] itself, this
/// captures only what was ordered and what was charged (name + price) rather
/// than referencing a live menu definition. An admin renaming "Bacon" or
/// changing its price must never alter an order already placed — and the order
/// domain stays free of any menu-layer import.
class OrderAddOn {
  final String name;

  /// The add-on's price at checkout time, already included in the parent
  /// [OrderItem]'s unit price.
  final double price;

  const OrderAddOn({required this.name, required this.price});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAddOn && other.name == name && other.price == price;

  @override
  int get hashCode => Object.hash(name, price);

  @override
  String toString() => 'OrderAddOn(name: $name, price: $price)';
}
