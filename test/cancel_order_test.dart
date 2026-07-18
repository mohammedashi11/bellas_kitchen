import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/order/data/repositories/firestore_order_repository.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/order_transition.dart';

/// Cancellation: the transition RULE (pure domain) and the repository GUARD
/// that enforces it against Firestore.
void main() {
  const orderId = 'order-1';

  Future<FakeFirebaseFirestore> seedOrder(OrderStatus status) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .set({
      AppConstants.fieldUserId: 'u1',
      AppConstants.fieldItems: const [
        {'menuItemId': '1', 'name': 'Burger', 'price': 12.99, 'quantity': 2},
      ],
      AppConstants.fieldSubtotal: 25.98,
      AppConstants.fieldTax: 2.34,
      AppConstants.fieldTotal: 30.82,
      AppConstants.fieldStatus: status.storageKey,
      AppConstants.fieldPayment: 'card',
      AppConstants.fieldCreatedAt: DateTime.utc(2026, 1, 1),
      AppConstants.fieldUpdatedAt: DateTime.utc(2026, 1, 1),
    });
    return firestore;
  }

  Future<Map<String, dynamic>> readOrder(FakeFirebaseFirestore f) async =>
      (await f.collection(AppConstants.ordersCollection).doc(orderId).get())
          .data()!;

  // ── The rule ───────────────────────────────────────────────────────────────
  group('cancellation transition rule', () {
    test('pending → cancelled is ALLOWED', () {
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.cancelled), isTrue);
      expect(validateTransition(OrderStatus.pending, OrderStatus.cancelled),
          isNull);
    });

    test('preparing → cancelled is REJECTED', () {
      expect(
          OrderStatus.preparing.canTransitionTo(OrderStatus.cancelled), isFalse);
      expect(validateTransition(OrderStatus.preparing, OrderStatus.cancelled),
          isA<ValidationFailure>());
    });

    test('pending is the ONLY status that can reach cancelled', () {
      final canCancel = OrderStatus.values
          .where((s) => s.canTransitionTo(OrderStatus.cancelled))
          .toSet();
      expect(canCancel, {OrderStatus.pending});
    });

    test('the forward happy path is unaffected by the narrowing', () {
      expect(validateTransition(OrderStatus.pending, OrderStatus.accepted),
          isNull);
      expect(validateTransition(OrderStatus.accepted, OrderStatus.preparing),
          isNull);
      expect(
          validateTransition(OrderStatus.preparing, OrderStatus.ready), isNull);
      expect(validateTransition(OrderStatus.ready, OrderStatus.delivered),
          isNull);
    });

    test('cancelled stays terminal', () {
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.cancelled.allowedNextStatuses, isEmpty);
    });
  });

  // ── The guard ──────────────────────────────────────────────────────────────
  group('FirestoreOrderRepository.cancelOrder guard', () {
    test('pending order → cancelled, and updatedAt is stamped', () async {
      final firestore = await seedOrder(OrderStatus.pending);
      final repo = FirestoreOrderRepository(firestore: firestore);

      final result = await repo.cancelOrder(orderId);

      expect(result, isA<Success<void>>());
      final data = await readOrder(firestore);
      expect(data[AppConstants.fieldStatus], OrderStatus.cancelled.storageKey);
      expect(data[AppConstants.fieldUpdatedAt], isNotNull);
    });

    test('preparing order → ValidationFailure, nothing written', () async {
      final firestore = await seedOrder(OrderStatus.preparing);
      final repo = FirestoreOrderRepository(firestore: firestore);

      final result = await repo.cancelOrder(orderId);

      expect(result.errorOrNull, isA<ValidationFailure>());
      // The stored status is untouched — the guard rejects BEFORE writing.
      final data = await readOrder(firestore);
      expect(data[AppConstants.fieldStatus], OrderStatus.preparing.storageKey);
    });

    test('ready and delivered orders are equally rejected', () async {
      for (final status in const [OrderStatus.ready, OrderStatus.delivered]) {
        final firestore = await seedOrder(status);
        final repo = FirestoreOrderRepository(firestore: firestore);

        final result = await repo.cancelOrder(orderId);

        expect(result.errorOrNull, isA<ValidationFailure>(),
            reason: '$status must not be cancellable');
        final data = await readOrder(firestore);
        expect(data[AppConstants.fieldStatus], status.storageKey);
      }
    });

    test('an already-cancelled order cannot be re-cancelled', () async {
      final firestore = await seedOrder(OrderStatus.cancelled);
      final repo = FirestoreOrderRepository(firestore: firestore);

      expect((await repo.cancelOrder(orderId)).errorOrNull,
          isA<ValidationFailure>());
    });

    test('missing order → NotFoundFailure', () async {
      final repo = FirestoreOrderRepository(firestore: FakeFirebaseFirestore());

      final result = await repo.cancelOrder('does-not-exist');

      expect(result.errorOrNull, isA<NotFoundFailure>());
    });

    test('cancelOrder and updateOrderStatus share one guard', () async {
      // Routing the same illegal move through both entry points must produce
      // the same rejection — proving there is no second, drifting rule.
      final viaCancel = FirestoreOrderRepository(
          firestore: await seedOrder(OrderStatus.preparing));
      final viaUpdate = FirestoreOrderRepository(
          firestore: await seedOrder(OrderStatus.preparing));

      final a = await viaCancel.cancelOrder(orderId);
      final b =
          await viaUpdate.updateOrderStatus(orderId, OrderStatus.cancelled);

      expect(a.errorOrNull, isA<ValidationFailure>());
      expect(b.errorOrNull, isA<ValidationFailure>());
      expect(a.errorOrNull!.message, b.errorOrNull!.message);
    });
  });
}
