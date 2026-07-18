import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/admin/presentation/admin_order_view.dart';
import 'package:bellas_kitchen/features/admin/presentation/dashboard_stats.dart';
import 'package:bellas_kitchen/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_item.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';
import 'package:bellas_kitchen/features/order/domain/repositories/order_repository.dart';
import 'package:bellas_kitchen/features/order/presentation/providers/order_providers.dart';

// Fixed local "now" for deterministic today-filtering.
final _now = DateTime(2024, 6, 15, 12, 0);
final _today = DateTime(2024, 6, 15, 9, 30);
final _alsoToday = DateTime(2024, 6, 15, 8, 0);
final _yesterday = DateTime(2024, 6, 14, 23, 0);

Order _order({
  required String id,
  required DateTime createdAt,
  OrderStatus status = OrderStatus.pending,
  List<OrderItem> items = const [],
  double total = 0,
}) =>
    Order(
      id: id,
      userId: 'u',
      items: items,
      subtotal: total,
      deliveryFee: 0,
      tax: 0,
      total: total,
      status: status,
      payment: PaymentMethod.card,
      deliveryAddress: 'x',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

OrderItem _item(String name, int qty) =>
    OrderItem(menuItemId: name, name: name, price: 1, quantity: qty);

/// Emits one order so the dashboard renders stat cards + a recent-order row.
class _FakeOrderRepo implements OrderRepository {
  @override
  Stream<Result<List<Order>>> watchAllOrders() => Stream.value(Success([
        _order(
            id: 'abcd9021',
            createdAt: DateTime.now(),
            status: OrderStatus.preparing,
            items: [_item('Burger', 2)],
            total: 34.20),
      ]));

  @override
  Future<Result<Order>> placeOrder(Order order) async => Success(order);

  @override
  Stream<Result<Order>> watchOrder(String orderId) =>
      Stream<Result<Order>>.empty();

  @override
  Stream<Result<List<Order>>> watchUserOrders(String userId) =>
      Stream<Result<List<Order>>>.empty();

  @override
  Future<Result<void>> updateOrderStatus(
          String orderId, OrderStatus newStatus) async =>
      const Success(null);

  @override
  Future<Result<void>> cancelOrder(String orderId) async => const Success(null);
}

void main() {
  group('computeDashboardStats', () {
    test('empty list → all zeros, no best seller', () {
      final s = computeDashboardStats(const [], now: _now);
      expect(s.todaysOrderCount, 0);
      expect(s.todaysRevenue, 0);
      expect(s.pendingCount, 0);
      expect(s.bestSellerName, isNull);
      expect(s.bestSellerCount, 0);
    });

    test('todaysOrderCount counts only today (local day)', () {
      final s = computeDashboardStats([
        _order(id: 'a', createdAt: _today),
        _order(id: 'b', createdAt: _alsoToday),
        _order(id: 'c', createdAt: _yesterday),
      ], now: _now);
      expect(s.todaysOrderCount, 2);
    });

    test('revenue sums today only and EXCLUDES cancelled', () {
      final s = computeDashboardStats([
        _order(
            id: 'a',
            createdAt: _today,
            status: OrderStatus.delivered,
            total: 10),
        _order(
            id: 'b', createdAt: _today, status: OrderStatus.pending, total: 20),
        _order(
            id: 'c',
            createdAt: _today,
            status: OrderStatus.cancelled,
            total: 30), // excluded
        _order(
            id: 'd',
            createdAt: _yesterday,
            status: OrderStatus.delivered,
            total: 99), // not today
      ], now: _now);
      expect(s.todaysRevenue, closeTo(30, 1e-9)); // 10 + 20
    });

    test('pendingCount counts all pending (any day)', () {
      final s = computeDashboardStats([
        _order(id: 'a', createdAt: _today, status: OrderStatus.pending),
        _order(id: 'b', createdAt: _yesterday, status: OrderStatus.pending),
        _order(id: 'c', createdAt: _today, status: OrderStatus.preparing),
      ], now: _now);
      expect(s.pendingCount, 2);
    });

    test('best seller = highest total quantity today (non-cancelled)', () {
      final s = computeDashboardStats([
        _order(id: 'a', createdAt: _today, items: [
          _item('Burger', 3),
          _item('Fries', 1),
        ]),
        _order(id: 'b', createdAt: _today, items: [_item('Fries', 1)]),
      ], now: _now);
      expect(s.bestSellerName, 'Burger');
      expect(s.bestSellerCount, 3);
    });

    test('best seller tie → first-seen wins deterministically', () {
      final s = computeDashboardStats([
        _order(id: 'a', createdAt: _today, items: [_item('Burger', 2)]),
        _order(id: 'b', createdAt: _today, items: [_item('Shake', 2)]),
      ], now: _now);
      expect(s.bestSellerName, 'Burger');
      expect(s.bestSellerCount, 2);
    });

    test('best seller ignores cancelled orders and other days', () {
      final s = computeDashboardStats([
        _order(
            id: 'a',
            createdAt: _today,
            status: OrderStatus.cancelled,
            items: [_item('Pizza', 10)]), // cancelled → ignored
        _order(
            id: 'b',
            createdAt: _yesterday,
            items: [_item('Salad', 10)]), // yesterday → ignored
        _order(id: 'c', createdAt: _today, items: [_item('Wings', 2)]),
      ], now: _now);
      expect(s.bestSellerName, 'Wings');
      expect(s.bestSellerCount, 2);
    });
  });

  // ── Regression: dashboard layout at narrow and wide viewports ──────────────
  // The 2×2 stat grid previously used bare CrossAxisAlignment.stretch inside a
  // ListView (unbounded height) → "BoxConstraints forces an infinite height"
  // and a blank admin shell. These renders fail if that ever regresses.
  group('AdminDashboardScreen renders without layout exceptions', () {
    Widget harness() => ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(_FakeOrderRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AdminDashboardScreen(onViewAllOrders: () {}),
            ),
          ),
        );

    Future<void> renderAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump(); // stream emission
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('ORDERS'), findsOneWidget);
      expect(find.text('REVENUE'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('BEST SELLER'), findsOneWidget);
      expect(find.text('Recent Orders'), findsOneWidget);
    }

    testWidgets('narrow (380px) admin window', (tester) async {
      await renderAt(tester, const Size(380, 900));
    });

    testWidgets('wide (1280px) admin window', (tester) async {
      await renderAt(tester, const Size(1280, 900));
    });
  });

  // Reuse of the Live Orders display helpers (not duplicated).
  group('display helper reuse', () {
    test('orderNumber derives #BK-xxxx', () {
      expect(orderNumber('abcd9021'), '#BK-9021');
      expect(orderNumber(''), '#BK-0000');
    });
    test('customerLabel falls back cheaply', () {
      expect(customerLabel(''), 'Guest');
      expect(customerLabel('abc123xyz'), 'Customer ABC123');
    });
  });
}
