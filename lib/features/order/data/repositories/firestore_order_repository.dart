// Import cloud_firestore but hide its `Order` enum, which would clash with our
// domain `Order` entity.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/order_transition.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/order_model.dart';

/// Firestore-backed [OrderRepository].
///
/// [_firestore] is nullable and resolved defensively so the repository can be
/// constructed before Firebase is initialized (or when it's unavailable)
/// without throwing — calls then return a graceful [Failure].
class FirestoreOrderRepository implements OrderRepository {
  final FirebaseFirestore? _firestore;

  FirestoreOrderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _tryFirestore();

  static FirebaseFirestore? _tryFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _orders =>
      _firestore?.collection(AppConstants.ordersCollection);

  @override
  Future<Result<Order>> placeOrder(Order order) async {
    final orders = _orders;
    if (orders == null) {
      return const Failure(NetworkFailure('Ordering is unavailable right now.'));
    }
    try {
      final ref = orders.doc(); // auto-generated id
      final model = OrderModel(
        id: ref.id,
        userId: order.userId,
        items: order.items,
        subtotal: order.subtotal,
        deliveryFee: order.deliveryFee,
        tax: order.tax,
        total: order.total,
        status: order.status,
        payment: order.payment,
        deliveryAddress: order.deliveryAddress,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );
      await ref.set(model.toFirestore()).timeout(AppConstants.firestoreTimeout);
      return Success(model);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  @override
  Stream<Result<Order>> watchOrder(String orderId) async* {
    final orders = _orders;
    if (orders == null) {
      yield const Failure(NetworkFailure('Ordering is unavailable right now.'));
      return;
    }
    try {
      await for (final snap in orders.doc(orderId).snapshots()) {
        final data = snap.data();
        if (!snap.exists || data == null) {
          yield const Failure(NotFoundFailure('Order not found.'));
        } else {
          yield Success(OrderModel.fromMap(snap.id, data));
        }
      }
    } on FirebaseException catch (e) {
      yield Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      yield Failure(_mapGeneric(e));
    }
  }

  @override
  Stream<Result<List<Order>>> watchUserOrders(String userId) async* {
    final orders = _orders;
    if (orders == null) {
      yield const Failure(NetworkFailure('Ordering is unavailable right now.'));
      return;
    }
    try {
      // Keep the userId equality filter — Firestore rules only allow a customer
      // to read their OWN orders, so the query MUST be constrained to them (an
      // unconstrained read would be denied). Deliberately NO orderBy: that would
      // need a composite index (userId + createdAt); instead we sort newest-first
      // client-side. A lone equality filter uses only the auto single-field index.
      final query = orders.where(AppConstants.fieldUserId, isEqualTo: userId);
      await for (final snap in query.snapshots()) {
        final items = snap.docs
            .map((d) => OrderModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield Success(items);
      }
    } on FirebaseException catch (e) {
      yield Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      yield Failure(_mapGeneric(e));
    }
  }

  @override
  Stream<Result<List<Order>>> watchAllOrders() async* {
    final orders = _orders;
    if (orders == null) {
      yield const Failure(NetworkFailure('Ordering is unavailable right now.'));
      return;
    }
    try {
      // Single-field orderBy → no composite index required (Firestore auto-
      // indexes single fields).
      final query =
          orders.orderBy(AppConstants.fieldCreatedAt, descending: true);
      await for (final snap in query.snapshots()) {
        yield Success(
          snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList(),
        );
      }
    } on FirebaseException catch (e) {
      yield Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      yield Failure(_mapGeneric(e));
    }
  }

  @override
  Future<Result<void>> updateOrderStatus(
    String orderId,
    OrderStatus newStatus,
  ) =>
      _writeStatus(orderId, newStatus);

  @override
  Future<Result<void>> cancelOrder(String orderId) =>
      // Same guarded write path as updateOrderStatus — the legality of
      // `current → cancelled` is decided solely by OrderStatus.allowedNextStatuses
      // (today: only from `pending`), so there is no second, drifting rule here.
      _writeStatus(orderId, OrderStatus.cancelled);

  /// Read current status → validate the transition → write. Shared by
  /// [updateOrderStatus] and [cancelOrder] so both enforce the identical guard.
  ///
  /// Not transactional (fine for a single-admin panel plus an owner-initiated
  /// cancel); the client only surfaces legal actions, and this rejects a
  /// stale/illegal one server-read-side. Firestore rules are the real backstop.
  Future<Result<void>> _writeStatus(
    String orderId,
    OrderStatus newStatus,
  ) async {
    final orders = _orders;
    if (orders == null) {
      return const Failure(NetworkFailure('Ordering is unavailable right now.'));
    }
    try {
      final ref = orders.doc(orderId);
      final snap = await ref.get().timeout(AppConstants.firestoreTimeout);
      final data = snap.data();
      if (!snap.exists || data == null) {
        return const Failure(NotFoundFailure('Order not found.'));
      }
      final current =
          OrderStatus.fromStorage(data[AppConstants.fieldStatus] as String?);
      final invalid = validateTransition(current, newStatus);
      if (invalid != null) return Failure(invalid);

      await ref.update({
        AppConstants.fieldStatus: newStatus.storageKey,
        AppConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      }).timeout(AppConstants.firestoreTimeout);
      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(_mapFirestore(e.code, e.message));
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  AppFailure _mapFirestore(String code, String? message) {
    final msg = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : _defaultMessage(code);
    switch (code) {
      case 'permission-denied':
        return UnauthorizedFailure(msg);
      case 'not-found':
        return NotFoundFailure(msg);
      case 'unavailable':
      case 'deadline-exceeded':
        return NetworkFailure(msg);
      case 'failed-precondition': // typically a missing composite index
      case 'resource-exhausted':
        return ServerFailure(msg);
      default:
        return UnknownFailure(msg);
    }
  }

  String _defaultMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network error. Check your connection and try again.';
      case 'failed-precondition':
        return 'The order service is misconfigured. Please try again later.';
      default:
        return 'Could not complete the request. Please try again.';
    }
  }

  AppFailure _mapGeneric(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout') ||
        s.contains('network') ||
        s.contains('unavailable')) {
      return const NetworkFailure(
          'Network error. Check your connection and try again.');
    }
    // Neutral wording: this mapper is shared by placeOrder, status updates and
    // cancellation, so it must not claim the failure was a failed *placement*.
    return const UnknownFailure(
        'Could not complete the request. Please try again.');
  }
}
