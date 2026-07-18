/// A customization option offered on a [MenuItem] — "Extra Cheese", "Bacon".
/// Pure Dart, no Flutter/Firebase.
///
/// This is the LIVE, admin-managed definition. When a customer checks out, the
/// selected add-ons are frozen into `OrderAddOn` snapshots on the order (see
/// `features/order/domain/entities/order_add_on.dart`) so a later price edit
/// never rewrites what a past order was charged.
class AddOn {
  /// Stable id, unique within the owning menu item. Used for cart line identity
  /// and selection tracking, so it must not change once customers have it.
  final String id;
  final String name;

  /// Amount ADDED to the item's base price. Zero is legitimate: a free
  /// preference like "No Onions" is an add-on priced at 0.
  final double price;

  const AddOn({required this.id, required this.name, required this.price});

  /// Whether this is a free preference rather than a paid extra. Drives the UI
  /// affordance (switch vs. priced checkbox) — derived, never stored, so admins
  /// don't maintain a flag that could contradict the price.
  bool get isFreePreference => price == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AddOn && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AddOn(id: $id, name: $name, price: $price)';
}
