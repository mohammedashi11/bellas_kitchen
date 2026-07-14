import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/menu_item_write_validator.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../models/menu_item_model.dart';

/// Firestore-backed implementation of [MenuRepository].
///
/// The `menu_items` collection is the single source of truth: an empty
/// collection returns an empty list and a failed read returns a typed
/// [Failure] — there is NO mock substitution anywhere in this read path (the
/// dev-only fallback was removed once real menu data existed; the UI owns the
/// loading/empty/error states).
class FirestoreMenuRepository implements MenuRepository {
  final FirebaseFirestore? _firestore;

  /// [firestore] is nullable so construction never throws before Firebase is
  /// initialized; calls then return a graceful [Failure].
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

  static const _unavailable = Failure<Never>(
      NetworkFailure('The menu is unavailable right now. Please try again.'));

  @override
  Future<Result<List<MenuItem>>> getMenuItems({String? category}) async {
    final collection = _collection;
    if (collection == null) return _unavailable;

    try {
      // Single-field orderBy only (auto-indexed). Combining
      // where(isAvailable)/where(category) with orderBy(createdAt) requires
      // composite indexes and previously failed with failed-precondition —
      // which the old mock fallback silently swallowed. Availability and
      // category are filtered client-side instead: the menu is small, and
      // this needs zero composite indexes.
      final snapshot = await collection
          .orderBy(AppConstants.fieldCreatedAt, descending: false)
          .get()
          .timeout(AppConstants.firestoreTimeout);

      final isFiltered =
          category != null && category != AppConstants.categoryAll;
      final items = snapshot.docs
          .map((doc) => MenuItemModel.fromMap(doc.id, doc.data()))
          .where((item) => item.isAvailable)
          .where((item) => !isFiltered || item.category == category)
          .toList();

      // Empty is empty — the UI renders its own empty state.
      return Success(items);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapReadGeneric(e));
    }
  }

  @override
  Future<Result<MenuItem?>> getMenuItemById(String id) async {
    final collection = _collection;
    if (collection == null) return _unavailable;

    try {
      final doc =
          await collection.doc(id).get().timeout(AppConstants.firestoreTimeout);
      if (!doc.exists) return const Success(null); // genuinely not found
      return Success(MenuItemModel.fromMap(doc.id, doc.data()!));
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapReadGeneric(e));
    }
  }

  AppFailure _mapReadGeneric(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout') ||
        s.contains('network') ||
        s.contains('unavailable')) {
      return const NetworkFailure(
          'Could not load the menu. Check your connection and try again.');
    }
    return const UnknownFailure('Could not load the menu. Please try again.');
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
