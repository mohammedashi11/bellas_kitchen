import '../../../menu/domain/entities/add_on.dart';
import '../../../menu/domain/entities/menu_item.dart';

/// A single line in the cart: a [MenuItem], the add-ons selected for it, and a
/// quantity. Pure Dart — no Flutter/Firebase dependencies.
class CartItem {
  final MenuItem item;
  final int quantity;

  /// The add-ons the customer chose for THIS line. Two lines of the same menu
  /// item with different selections are distinct lines — see [lineKey].
  final List<AddOn> selectedAddOns;

  const CartItem({
    required this.item,
    required this.quantity,
    this.selectedAddOns = const [],
  });

  /// Price of ONE unit: base price plus every selected add-on.
  double get unitPrice =>
      item.price + selectedAddOns.fold<double>(0.0, (sum, a) => sum + a.price);

  /// Line subtotal (unit price × quantity).
  double get lineTotal => unitPrice * quantity;

  /// Identity of this line within the cart.
  ///
  /// The same item with the SAME add-on selection must merge (increment
  /// quantity); with a DIFFERENT selection it must stay a separate line. The
  /// key is therefore derived from the item id plus the selected add-on ids,
  /// SORTED so that picking the same add-ons in a different order still merges.
  ///
  /// A line with no add-ons keys to the bare item id, which keeps the cart map
  /// (and every caller that removes/decrements by menu item id) working exactly
  /// as it did before add-ons existed.
  String get lineKey => keyFor(item.id, selectedAddOns);

  /// [lineKey] for an item/selection pair, without building a [CartItem].
  static String keyFor(String itemId, List<AddOn> addOns) {
    if (addOns.isEmpty) return itemId;
    final ids = addOns.map((a) => a.id).toList()..sort();
    return '$itemId#${ids.join(",")}';
  }

  CartItem copyWith({int? quantity}) => CartItem(
        item: item,
        quantity: quantity ?? this.quantity,
        selectedAddOns: selectedAddOns,
      );
}
