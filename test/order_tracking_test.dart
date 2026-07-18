import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_item.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';
import 'package:bellas_kitchen/features/order/domain/repositories/order_repository.dart';
import 'package:bellas_kitchen/features/order/presentation/order_stage.dart';
import 'package:bellas_kitchen/features/order/presentation/providers/order_providers.dart';
import 'package:bellas_kitchen/features/order/presentation/screens/order_tracking_screen.dart';

class _FakeOrderRepo implements OrderRepository {
  /// When set, `watchOrder` emits from this controller so a test can push the
  /// post-cancel order and assert the screen reacts to the STREAM (not to any
  /// local widget state).
  final StreamController<Result<Order>>? orderStream;

  /// What `cancelOrder` returns, and the ids it was called with.
  final Result<void> cancelResult;
  final List<String> cancelledIds = [];

  _FakeOrderRepo({this.orderStream, this.cancelResult = const Success(null)});

  @override
  Future<Result<Order>> placeOrder(Order order) async => Success(order);

  @override
  Stream<Result<Order>> watchOrder(String orderId) =>
      orderStream?.stream ?? Stream<Result<Order>>.empty();

  @override
  Stream<Result<List<Order>>> watchUserOrders(String userId) =>
      Stream<Result<List<Order>>>.empty();

  @override
  Stream<Result<List<Order>>> watchAllOrders() =>
      Stream<Result<List<Order>>>.empty();

  @override
  Future<Result<void>> updateOrderStatus(
          String orderId, OrderStatus newStatus) async =>
      const Success(null);

  @override
  Future<Result<void>> cancelOrder(String orderId) async {
    cancelledIds.add(orderId);
    return cancelResult;
  }
}

Order _order(OrderStatus status) => Order(
      id: 'abc123def',
      userId: 'u1',
      items: [
        const OrderItem(
            menuItemId: '1', name: 'Burger', price: 12.99, quantity: 2),
      ],
      subtotal: 25.98,
      tax: 2.34,
      total: 30.82,
      status: status,
      payment: PaymentMethod.card,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  // ── Stage derivation (4-node customer grouping) ────────────────────────────
  test('customerStages is the 4 customer nodes in order', () {
    expect(customerStages, const [
      CustomerStage.orderPlaced,
      CustomerStage.preparing,
      CustomerStage.ready,
      CustomerStage.completed,
    ]);
  });

  test('customerStageOf groups pending AND accepted into Order Placed', () {
    expect(customerStageOf(OrderStatus.pending), CustomerStage.orderPlaced);
    expect(customerStageOf(OrderStatus.accepted), CustomerStage.orderPlaced);
    expect(customerStageOf(OrderStatus.preparing), CustomerStage.preparing);
    expect(customerStageOf(OrderStatus.ready), CustomerStage.ready);
    expect(customerStageOf(OrderStatus.completed), CustomerStage.completed);
  });

  group('stageStateFor (customer grouping)', () {
    test('pending → Order Placed active, rest upcoming', () {
      expect(stageStateFor(OrderStatus.pending, CustomerStage.orderPlaced),
          StageState.current);
      expect(stageStateFor(OrderStatus.pending, CustomerStage.preparing),
          StageState.upcoming);
      expect(stageStateFor(OrderStatus.pending, CustomerStage.completed),
          StageState.upcoming);
    });

    test('accepted → STILL Order Placed active (pending/accepted grouped)', () {
      expect(stageStateFor(OrderStatus.accepted, CustomerStage.orderPlaced),
          StageState.current);
      expect(stageStateFor(OrderStatus.accepted, CustomerStage.preparing),
          StageState.upcoming);
    });

    test('preparing → Order Placed complete, Preparing current, later upcoming',
        () {
      expect(stageStateFor(OrderStatus.preparing, CustomerStage.orderPlaced),
          StageState.complete);
      expect(stageStateFor(OrderStatus.preparing, CustomerStage.preparing),
          StageState.current);
      expect(stageStateFor(OrderStatus.preparing, CustomerStage.ready),
          StageState.upcoming);
      expect(stageStateFor(OrderStatus.preparing, CustomerStage.completed),
          StageState.upcoming);
    });

    test('ready → up to Ready complete/current, Delivered upcoming', () {
      expect(stageStateFor(OrderStatus.ready, CustomerStage.orderPlaced),
          StageState.complete);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.preparing),
          StageState.complete);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.ready),
          StageState.current);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.completed),
          StageState.upcoming);
    });

    test('delivered → all four nodes complete', () {
      for (final stage in customerStages) {
        expect(stageStateFor(OrderStatus.completed, stage), StageState.complete);
      }
    });
  });

  // ── Status message (replaced the fake courier map) ─────────────────────────
  group('trackingStatusMessage', () {
    test('every status maps to a distinct, non-empty message', () {
      final messages =
          OrderStatus.values.map(trackingStatusMessage).toList();
      expect(messages.every((m) => m.trim().isNotEmpty), isTrue);
      expect(messages.toSet().length, OrderStatus.values.length,
          reason: 'each status should read differently');
    });

    test('messages reflect the real stage', () {
      expect(trackingStatusMessage(OrderStatus.preparing),
          contains('being prepared'));
      expect(trackingStatusMessage(OrderStatus.ready),
          contains('ready for pickup'));
    });

    test('no message invents courier or delivery state', () {
      // The old UI hardcoded "Courier is at the restaurant" — a fact this
      // system cannot know. Nothing here may re-introduce that.
      for (final status in OrderStatus.values) {
        final m = trackingStatusMessage(status).toLowerCase();
        expect(m, isNot(contains('courier')));
        expect(m, isNot(contains('driver')));
        expect(m, isNot(contains('on its way')));
      }
    });
  });

  test('isCancelled detects the cancelled status only', () {
    expect(isCancelled(OrderStatus.cancelled), isTrue);
    expect(isCancelled(OrderStatus.pending), isFalse);
    expect(isCancelled(OrderStatus.completed), isFalse);
  });

  group('canCancelOrder', () {
    test('enabled only while pending', () {
      expect(canCancelOrder(OrderStatus.pending), isTrue);
      for (final s in const [
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.completed,
        OrderStatus.cancelled,
      ]) {
        expect(canCancelOrder(s), isFalse);
      }
    });
  });

  // ── Screen rendering ───────────────────────────────────────────────────────
  Widget harness(Order order, {_FakeOrderRepo? repo}) => ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repo ?? _FakeOrderRepo()),
        ],
        child: MaterialApp(
          home: OrderTrackingScreen(orderId: order.id, initialOrder: order),
        ),
      );

  // Tall/wide viewport so the whole (lazy) ListView renders and GoogleFonts'
  // wider test-fallback font doesn't overflow narrow rows.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('active order renders stepper + estimated delivery', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(harness(_order(OrderStatus.preparing)));
    await tester.pump();

    expect(find.textContaining('Ready for Pickup'), findsOneWidget);
    expect(find.text('Order Placed'), findsOneWidget); // grouped node
    expect(find.text('Preparing'), findsOneWidget); // current stepper node
    expect(find.text('Cancel Order'), findsOneWidget);
    expect(find.text('Contact Restaurant'), findsOneWidget);
  });

  testWidgets('cancelled order shows the cancelled state, not the stepper',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(harness(_order(OrderStatus.cancelled)));
    await tester.pump();

    expect(find.text('Order Cancelled'), findsOneWidget);
    expect(find.text('This order was cancelled'), findsOneWidget);
    // Linear stepper is absent → its stage labels don't render.
    expect(find.text('Preparing'), findsNothing);
  });

  testWidgets('status message renders from the real status; no fake courier',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(harness(_order(OrderStatus.preparing)));
    await tester.pump();

    expect(find.text('Your order is being prepared.'), findsOneWidget);
    // The decorative map box and its hardcoded caption are gone for good.
    expect(find.text('Courier is at the restaurant'), findsNothing);
    expect(find.byIcon(Icons.map_rounded), findsNothing);
  });

  // ── Cancel flow ────────────────────────────────────────────────────────────
  group('cancel order flow', () {
    /// Taps the "Cancel Order" link (the tracking-screen one, not a dialog
    /// button) and settles the confirm dialog into view.
    Future<void> tapCancelLink(WidgetTester tester) async {
      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirming calls cancelOrder with the route order id',
        (tester) async {
      useTallViewport(tester);
      final repo = _FakeOrderRepo();
      await tester.pumpWidget(harness(_order(OrderStatus.pending), repo: repo));
      await tester.pump();

      await tapCancelLink(tester);
      expect(find.text('Cancel this order?'), findsOneWidget);
      // Nothing is written until the user confirms.
      expect(repo.cancelledIds, isEmpty);

      // The dialog's confirm button is the SECOND "Cancel Order" text.
      await tester.tap(find.text('Cancel Order').last);
      await tester.pumpAndSettle();

      expect(repo.cancelledIds, ['abc123def']);
    });

    testWidgets('dismissing with "Keep Order" writes nothing', (tester) async {
      useTallViewport(tester);
      final repo = _FakeOrderRepo();
      await tester.pumpWidget(harness(_order(OrderStatus.pending), repo: repo));
      await tester.pump();

      await tapCancelLink(tester);
      await tester.tap(find.text('Keep Order'));
      await tester.pumpAndSettle();

      expect(repo.cancelledIds, isEmpty);
      expect(find.text('Cancel this order?'), findsNothing);
    });

    testWidgets('cancelled state arrives via the watchOrder stream',
        (tester) async {
      useTallViewport(tester);
      final controller = StreamController<Result<Order>>();
      addTearDown(controller.close);
      final repo = _FakeOrderRepo(orderStream: controller);

      await tester.pumpWidget(harness(_order(OrderStatus.pending), repo: repo));
      controller.add(Success(_order(OrderStatus.pending)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ready for Pickup'), findsOneWidget);

      await tapCancelLink(tester);
      await tester.tap(find.text('Cancel Order').last);
      await tester.pumpAndSettle();

      // The screen still shows the ACTIVE order — it holds no local cancelled
      // state; only the stream can flip it.
      expect(find.textContaining('Ready for Pickup'), findsOneWidget);

      controller.add(Success(_order(OrderStatus.cancelled)));
      await tester.pumpAndSettle();

      expect(find.text('Order Cancelled'), findsOneWidget);
      expect(find.text('This order was cancelled'), findsOneWidget);
    });

    testWidgets('HAPPY PATH: a pending order cancels end to end',
        (tester) async {
      // One readable pass over the whole enabled-cancel path: the affordance
      // is actually live on a pending order, the dialog offers both choices,
      // confirming writes exactly once, and the cancelled state arrives from
      // the stream rather than from local widget state.
      useTallViewport(tester);
      final controller = StreamController<Result<Order>>();
      addTearDown(controller.close);
      final repo = _FakeOrderRepo(orderStream: controller);

      await tester.pumpWidget(harness(_order(OrderStatus.pending), repo: repo));
      controller.add(Success(_order(OrderStatus.pending)));
      await tester.pumpAndSettle();

      // 1. The link is ENABLED — full opacity, not the 0.5 inert styling.
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Cancel Order'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1.0,
          reason: 'cancel must be live while the order is pending');

      // 2. Tapping opens the confirmation with both choices, and writes nothing.
      await tapCancelLink(tester);
      expect(find.text('Cancel this order?'), findsOneWidget);
      expect(find.text('Keep Order'), findsOneWidget);
      expect(repo.cancelledIds, isEmpty);

      // 3. Confirming fires cancelOrder exactly once, with the route order id.
      await tester.tap(find.text('Cancel Order').last);
      await tester.pumpAndSettle();
      expect(repo.cancelledIds, ['abc123def']);
      expect(find.text('Cancel this order?'), findsNothing);

      // 4. The cancelled view arrives only once the stream says so.
      controller.add(Success(_order(OrderStatus.cancelled)));
      await tester.pumpAndSettle();
      expect(find.text('Order Cancelled'), findsOneWidget);
      expect(find.text('This order was cancelled'), findsOneWidget);

      // 5. And cancelling again is no longer offered.
      expect(canCancelOrder(OrderStatus.cancelled), isFalse);
    });

    testWidgets('a typed failure surfaces its message', (tester) async {
      useTallViewport(tester);
      final repo = _FakeOrderRepo(
        cancelResult: const Failure<void>(
            UnauthorizedFailure("You don't have permission to do that.")),
      );
      await tester.pumpWidget(harness(_order(OrderStatus.pending), repo: repo));
      await tester.pump();

      await tapCancelLink(tester);
      await tester.tap(find.text('Cancel Order').last);
      await tester.pumpAndSettle();

      expect(find.text("You don't have permission to do that."),
          findsOneWidget);
    });

    testWidgets('link is inert once the order is past pending', (tester) async {
      useTallViewport(tester);
      final repo = _FakeOrderRepo();
      await tester
          .pumpWidget(harness(_order(OrderStatus.preparing), repo: repo));
      await tester.pump();

      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();

      // No confirm dialog, no write.
      expect(find.text('Cancel this order?'), findsNothing);
      expect(repo.cancelledIds, isEmpty);
    });
  });
}
