import '../entities/menu_item.dart';
import '../../../../core/utils/result.dart';

/// Abstract repository contract — domain layer.
/// Implementations live in the data layer.
///
/// Returns a [Result] so the presentation layer consumes a clean
/// success/failure value and never contains data-fetching fallback logic.
abstract class MenuRepository {
  /// Returns all menu items, optionally filtered by [category].
  /// Pass null or 'All' to fetch every item.
  Future<Result<List<MenuItem>>> getMenuItems({String? category});

  /// Returns a single menu item by [id]. Success carries null when not found.
  Future<Result<MenuItem?>> getMenuItemById(String id);

  // ── Admin (write) surface ───────────────────────────────────────────────

  /// Live list of ALL items — including unavailable ones — for the admin menu
  /// manager. Unlike [getMenuItems], this never serves mock data: the admin
  /// must see the true collection state (empty = empty).
  Stream<Result<List<MenuItem>>> watchAllMenuItems();

  /// Creates a menu item (`createdAt` is server-stamped). Rejects invalid
  /// items (empty name, price <= 0, non-storable category) with a
  /// `ValidationFailure` before writing.
  Future<Result<MenuItem>> addMenuItem(MenuItem item);

  /// Updates an existing item by [MenuItem.id]. Never overwrites `createdAt`.
  /// Same write-side validation as [addMenuItem].
  Future<Result<void>> updateMenuItem(MenuItem item);

  /// Deletes the item. The UI must confirm before calling this.
  Future<Result<void>> deleteMenuItem(String id);

  /// Lightweight single-field availability toggle.
  Future<Result<void>> setAvailability(String id, bool isAvailable);
}
