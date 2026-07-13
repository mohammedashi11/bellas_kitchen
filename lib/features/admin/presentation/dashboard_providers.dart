import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../order/domain/entities/order.dart';
import '../../order/presentation/providers/order_providers.dart';
import 'dashboard_stats.dart';

const int _recentOrdersLimit = 5;

/// Today's stats, derived from the existing admin orders stream via the pure
/// [computeDashboardStats]. No extra Firestore reads (reuses adminOrdersProvider);
/// while loading/errored, the underlying list is empty → zeroed stats.
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(adminOrdersProvider).asData?.value;
  if (orders == null || orders.isEmpty) return DashboardStats.empty;
  return computeDashboardStats(orders);
});

/// The most recent N orders (the admin stream is already `createdAt` desc).
final recentOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(adminOrdersProvider).asData?.value ?? const <Order>[];
  return orders.take(_recentOrdersLimit).toList(growable: false);
});
