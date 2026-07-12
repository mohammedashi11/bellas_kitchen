import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/result.dart';
import '../datasources/mock_menu_data.dart';
import '../models/menu_item_model.dart';

/// Firestore-backed implementation of [MenuRepository].
///
/// Owns all data-fetching concerns, including the mock-data fallback. The
/// fallback kicks in whenever real menu data is unavailable — Firebase not
/// initialized, Firestore unreachable, or the collection empty ("no data
/// yet") — so the app renders identically to its pre-Firebase behavior until
/// the menu is populated. Errors are caught here and turned into a clean
/// [Result] so the presentation layer stays fallback-free.
class FirestoreMenuRepository implements MenuRepository {
  final FirebaseFirestore? _firestore;

  /// [firestore] is nullable so the repository can be constructed before
  /// Firebase is initialized; in that case it transparently serves mock data.
  FirestoreMenuRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _tryGetInstance();

  static FirebaseFirestore? _tryGetInstance() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      // Firebase.initializeApp() hasn't run yet.
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _collection =>
      _firestore?.collection(AppConstants.menuItemsCollection);

  MenuItem? _mockById(String id) {
    final match = MockMenuData.items.where((i) => i.id == id).toList();
    return match.isEmpty ? null : match.first;
  }

  @override
  Future<Result<List<MenuItem>>> getMenuItems({String? category}) async {
    final collection = _collection;
    if (collection == null) {
      // Firebase unavailable — serve mock data as a successful result.
      return Success(MockMenuData.byCategory(category));
    }

    try {
      Query<Map<String, dynamic>> query = collection
          .where(AppConstants.fieldIsAvailable, isEqualTo: true)
          .orderBy(AppConstants.fieldCreatedAt, descending: false);

      final isFiltered =
          category != null && category != AppConstants.categoryAll;
      if (isFiltered) {
        query = query.where(AppConstants.fieldCategory, isEqualTo: category);
      }

      final snapshot = await query.get().timeout(AppConstants.firestoreTimeout);
      final items = snapshot.docs
          .map((doc) => MenuItemModel.fromMap(doc.id, doc.data()))
          .toList();

      // Firestore reachable but not yet populated — serve mock data so the
      // menu still renders exactly as it did before Firebase was connected.
      //
      // TODO: This empty-collection fallback is for pre-launch development
      // only. Once real menu data is seeded in production, remove it (or gate
      // it behind a debug flag like `kDebugMode`) so an empty menu surfaces as
      // a genuine empty state rather than silently showing mock items.
      if (items.isEmpty) return Success(MockMenuData.byCategory(category));

      return Success(items);
    } catch (e) {
      // Firestore is present but the read failed or timed out (offline,
      // unreachable, misconfigured rules, etc.). Fall back to mock data so the
      // menu still renders instead of hanging on a loading state.
      debugPrint('FirestoreMenuRepository.getMenuItems failed: $e — '
          'falling back to mock data.');
      return Success(MockMenuData.byCategory(category));
    }
  }

  @override
  Future<Result<MenuItem?>> getMenuItemById(String id) async {
    final collection = _collection;
    if (collection == null) {
      return Success(_mockById(id));
    }

    try {
      final doc =
          await collection.doc(id).get().timeout(AppConstants.firestoreTimeout);
      if (!doc.exists) return Success(_mockById(id));
      return Success(MenuItemModel.fromMap(doc.id, doc.data()!));
    } catch (e) {
      debugPrint('FirestoreMenuRepository.getMenuItemById failed: $e — '
          'falling back to mock data.');
      return Success(_mockById(id));
    }
  }
}
