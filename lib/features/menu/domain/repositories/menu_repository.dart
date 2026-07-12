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
}
