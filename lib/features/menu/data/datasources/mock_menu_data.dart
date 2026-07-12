import '../../domain/entities/menu_item.dart';
import '../../../../core/constants/app_constants.dart';

/// Local mock menu used as a fallback when Firestore is unavailable
/// (e.g. before `google-services.json` / Firebase is configured).
///
/// Lives in the data layer so the presentation layer never has to know a
/// fallback exists — it simply consumes whatever the repository returns.
abstract final class MockMenuData {
  // Fixed base time for synthetic `createdAt` values. Each item is offset by
  // its position so the ascending `createdAt` ordering matches list order,
  // keeping offline (mock) ordering stable and deterministic.
  static final DateTime _base = DateTime.utc(2024, 1, 1);

  static final List<MenuItem> items = <MenuItem>[
    MenuItem(
      id: '1',
      name: 'Classic Cheeseburger',
      description:
          'Juicy beef patty with aged cheddar, caramelized onions, and our secret house sau...',
      price: 12.99,
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
      category: 'Burgers',
      isBestSeller: true,
      createdAt: _base.add(const Duration(minutes: 1)),
    ),
    MenuItem(
      id: '2',
      name: 'Margherita Pizza',
      description:
          'Wood-fired thin crust topped with San Marzano tomatoes, fresh buffalo mozzarella, and...',
      price: 15.50,
      imageUrl:
          'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=800&q=80',
      category: 'Pizza',
      createdAt: _base.add(const Duration(minutes: 2)),
    ),
    MenuItem(
      id: '3',
      name: 'Truffle Parm Fries',
      description:
          'Hand-cut golden fries tossed in aromatic truffle oil, finished with aged parmesan and sea salt.',
      price: 8.99,
      imageUrl:
          'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800&q=80',
      category: 'Sides',
      createdAt: _base.add(const Duration(minutes: 3)),
    ),
    MenuItem(
      id: '4',
      name: 'Molten Lava Cake',
      description:
          'Dark chocolate cake with a gooey molten center, served warm with a dusting of sugar.',
      price: 9.25,
      imageUrl:
          'https://images.unsplash.com/photo-1624353365286-3f8d62daad51?w=800&q=80',
      category: 'Desserts',
      createdAt: _base.add(const Duration(minutes: 4)),
    ),
    MenuItem(
      id: '5',
      name: 'BBQ Bacon Burger',
      description:
          'Smoky BBQ sauce, crispy bacon strips, cheddar cheese, and fresh lettuce on a brioche bun.',
      price: 14.50,
      imageUrl:
          'https://images.unsplash.com/photo-1553979459-d2229ba7433a?w=800&q=80',
      category: 'Burgers',
      createdAt: _base.add(const Duration(minutes: 5)),
    ),
    MenuItem(
      id: '6',
      name: 'Pepperoni Feast',
      description:
          'Loaded with premium pepperoni, mozzarella, and a rich tomato sauce on our signature crust.',
      price: 16.99,
      imageUrl:
          'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=800&q=80',
      category: 'Pizza',
      createdAt: _base.add(const Duration(minutes: 6)),
    ),
  ];

  /// Returns the mock items filtered by [category].
  /// `null`, empty, or 'All' returns every item.
  static List<MenuItem> byCategory(String? category) {
    final effective = category == null ||
            category.isEmpty ||
            category == AppConstants.categoryAll
        ? null
        : category;
    if (effective == null) return items;
    return items.where((item) => item.category == effective).toList();
  }
}
