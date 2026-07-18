import 'add_on.dart';

/// Pure Dart MenuItem entity — no Flutter/Firebase dependencies.
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isBestSeller;
  final bool isAvailable;

  /// Customization options a customer may select for this item. Empty means the
  /// item isn't customizable — the common case, and the default for menu
  /// documents written before add-ons existed.
  final List<AddOn> availableAddOns;

  /// When the item was created. Menu queries order by this field, so it is
  /// required. Note: no `const` constructor because [DateTime] is not a
  /// const-constructible type.
  final DateTime createdAt;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.createdAt,
    this.isBestSeller = false,
    this.isAvailable = true,
    this.availableAddOns = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MenuItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MenuItem(id: $id, name: $name, price: $price, category: $category)';
}
