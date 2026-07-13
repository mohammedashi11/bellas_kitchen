import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/features/admin/presentation/admin_order_view.dart';
import 'package:bellas_kitchen/features/admin/presentation/dashboard_stats.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_item.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';

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
