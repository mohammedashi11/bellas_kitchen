import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  @override
  Future<Result<Order>> placeOrder(Order order) async => Success(order);

  @override
  Stream<Result<Order>> watchOrder(String orderId) =>
      Stream<Result<Order>>.empty();

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
}

Order _order(OrderStatus status) => Order(
      id: 'abc123def',
      userId: 'u1',
      items: [
        const OrderItem(
            menuItemId: '1', name: 'Burger', price: 12.99, quantity: 2),
      ],
      subtotal: 25.98,
      deliveryFee: 2.50,
      tax: 2.34,
      total: 30.82,
      status: status,
      payment: PaymentMethod.card,
      deliveryAddress: '123 St',
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
      CustomerStage.delivered,
    ]);
  });

  test('customerStageOf groups pending AND accepted into Order Placed', () {
    expect(customerStageOf(OrderStatus.pending), CustomerStage.orderPlaced);
    expect(customerStageOf(OrderStatus.accepted), CustomerStage.orderPlaced);
    expect(customerStageOf(OrderStatus.preparing), CustomerStage.preparing);
    expect(customerStageOf(OrderStatus.ready), CustomerStage.ready);
    expect(customerStageOf(OrderStatus.delivered), CustomerStage.delivered);
  });

  group('stageStateFor (customer grouping)', () {
    test('pending → Order Placed active, rest upcoming', () {
      expect(stageStateFor(OrderStatus.pending, CustomerStage.orderPlaced),
          StageState.current);
      expect(stageStateFor(OrderStatus.pending, CustomerStage.preparing),
          StageState.upcoming);
      expect(stageStateFor(OrderStatus.pending, CustomerStage.delivered),
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
      expect(stageStateFor(OrderStatus.preparing, CustomerStage.delivered),
          StageState.upcoming);
    });

    test('ready → up to Ready complete/current, Delivered upcoming', () {
      expect(stageStateFor(OrderStatus.ready, CustomerStage.orderPlaced),
          StageState.complete);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.preparing),
          StageState.complete);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.ready),
          StageState.current);
      expect(stageStateFor(OrderStatus.ready, CustomerStage.delivered),
          StageState.upcoming);
    });

    test('delivered → all four nodes complete', () {
      for (final stage in customerStages) {
        expect(stageStateFor(OrderStatus.delivered, stage), StageState.complete);
      }
    });
  });

  test('isCancelled detects the cancelled status only', () {
    expect(isCancelled(OrderStatus.cancelled), isTrue);
    expect(isCancelled(OrderStatus.pending), isFalse);
    expect(isCancelled(OrderStatus.delivered), isFalse);
  });

  group('canCancelOrder', () {
    test('enabled only while pending', () {
      expect(canCancelOrder(OrderStatus.pending), isTrue);
      for (final s in const [
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        expect(canCancelOrder(s), isFalse);
      }
    });
  });

  // ── Screen rendering ───────────────────────────────────────────────────────
  Widget harness(Order order) => ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(_FakeOrderRepo())],
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

    expect(find.textContaining('Estimated Delivery'), findsOneWidget);
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
}
