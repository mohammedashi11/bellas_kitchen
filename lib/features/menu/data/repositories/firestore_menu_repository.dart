import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/menu_item_write_validator.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
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

  // ── Admin (write) surface ────────────────────────────────────────────────

  static const _writeUnavailable =
      Failure<Never>(NetworkFailure('Menu editing is unavailable right now.'));

  @override
  Stream<Result<List<MenuItem>>> watchAllMenuItems() async* {
    final collection = _collection;
    if (collection == null) {
      yield const Failure(
          NetworkFailure('Menu editing is unavailable right now.'));
      return;
    }
    try {
      // No isAvailable filter (admin sees everything) and NO mock fallback —
      // the admin must see the true collection state. Single-field orderBy →
      // no composite index needed.
      final query =
          collection.orderBy(AppConstants.fieldCreatedAt, descending: false);
      await for (final snap in query.snapshots()) {
        yield Success(
          snap.docs.map((d) => MenuItemModel.fromMap(d.id, d.data())).toList(),
        );
      }
    } on FirebaseException catch (e) {
      yield Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      yield Failure(_mapWriteGeneric(e));
    }
  }

  @override
  Future<Result<MenuItem>> addMenuItem(MenuItem item) async {
    // Write-side guard: never write an invalid item or a non-storable
    // category ('Other'/'All'/unknown) — see menu_item_write_validator.dart.
    final invalid = validateMenuItemWrite(item);
    if (invalid != null) return Failure(invalid);

    final collection = _collection;
    if (collection == null) return _writeUnavailable;
    try {
      final ref = collection.doc(); // auto-generated id
      final model = MenuItemModel(
        id: ref.id,
        name: item.name.trim(),
        description: item.description,
        price: item.price,
        imageUrl: item.imageUrl,
        category: item.category,
        isBestSeller: item.isBestSeller,
        isAvailable: item.isAvailable,
        createdAt: item.createdAt,
      );
      // toFirestore stamps createdAt with serverTimestamp — correct on create.
      await ref.set(model.toFirestore()).timeout(AppConstants.firestoreTimeout);
      return Success(model);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapWriteGeneric(e));
    }
  }

  @override
  Future<Result<void>> updateMenuItem(MenuItem item) async {
    final invalid = validateMenuItemWrite(item);
    if (invalid != null) return Failure(invalid);

    final collection = _collection;
    if (collection == null) return _writeUnavailable;
    try {
      // Explicit field map WITHOUT createdAt: an update must never overwrite
      // the original creation timestamp (toFirestore would re-stamp it).
      await collection.doc(item.id).update({
        AppConstants.fieldName: item.name.trim(),
        AppConstants.fieldDescription: item.description,
        AppConstants.fieldPrice: item.price,
        AppConstants.fieldImageUrl: item.imageUrl,
        AppConstants.fieldCategory: item.category,
        AppConstants.fieldIsBestSeller: item.isBestSeller,
        AppConstants.fieldIsAvailable: item.isAvailable,
      }).timeout(AppConstants.firestoreTimeout);
      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapWriteGeneric(e));
    }
  }

  @override
  Future<Result<void>> deleteMenuItem(String id) async {
    final collection = _collection;
    if (collection == null) return _writeUnavailable;
    try {
      await collection.doc(id).delete().timeout(AppConstants.firestoreTimeout);
      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapWriteGeneric(e));
    }
  }

  @override
  Future<Result<void>> setAvailability(String id, bool isAvailable) async {
    final collection = _collection;
    if (collection == null) return _writeUnavailable;
    try {
      await collection.doc(id).update({
        AppConstants.fieldIsAvailable: isAvailable,
      }).timeout(AppConstants.firestoreTimeout);
      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapWriteGeneric(e));
    }
  }

  AppFailure _mapFirestore(String code, String? message) {
    final msg = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : 'Could not complete the request. Please try again.';
    switch (code) {
      case 'permission-denied':
        return UnauthorizedFailure(
            "You don't have permission to edit the menu.");
      case 'not-found':
        return const NotFoundFailure('Menu item not found.');
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkFailure(
            'Network error. Check your connection and try again.');
      case 'failed-precondition':
      case 'resource-exhausted':
        return ServerFailure(msg);
      default:
        return UnknownFailure(msg);
    }
  }

  AppFailure _mapWriteGeneric(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout') ||
        s.contains('network') ||
        s.contains('unavailable')) {
      return const NetworkFailure(
          'Network error. Check your connection and try again.');
    }
    return const UnknownFailure('Could not save the menu item. Please try again.');
  }
}
