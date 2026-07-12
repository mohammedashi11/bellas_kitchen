import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../domain/usecases/get_menu_items.dart';
import '../../data/repositories/firestore_menu_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/result.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return FirestoreMenuRepository();
});

// ---------------------------------------------------------------------------
// Selected category state
// ---------------------------------------------------------------------------
final selectedCategoryProvider = StateProvider<String>((ref) {
  return AppConstants.categoryAll;
});

// ---------------------------------------------------------------------------
// Menu items provider.
//
// The repository returns a clean Result and owns any mock-data fallback, so
// this layer just unwraps it: Success -> data, Failure -> throw so the UI's
// AsyncValue.when(error:) branch renders.
// ---------------------------------------------------------------------------
final menuItemsProvider =
    FutureProvider.family<List<MenuItem>, String?>((ref, category) async {
  final useCase = GetMenuItems(ref.watch(menuRepositoryProvider));
  final result = await useCase(category: category);
  return result.fold(
    onSuccess: (items) => items,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

// ---------------------------------------------------------------------------
// Filtered items based on selected category
// ---------------------------------------------------------------------------
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  return ref.watch(menuItemsProvider(category));
});

// ---------------------------------------------------------------------------
// Single item by id — used by the detail screen when it isn't handed a
// MenuItem via go_router `extra` (deep link / hot restart / web refresh).
// Reuses the existing repository method; no new repository.
// ---------------------------------------------------------------------------
final menuItemByIdProvider =
    FutureProvider.family<MenuItem?, String>((ref, id) async {
  final repo = ref.watch(menuRepositoryProvider);
  final result = await repo.getMenuItemById(id);
  return result.fold(
    onSuccess: (item) => item,
    onFailure: (failure) => throw Exception(failure.message),
  );
});
