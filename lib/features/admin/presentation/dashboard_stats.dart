import '../../order/domain/entities/order.dart';
import '../../order/domain/entities/order_status.dart';

/// Today's admin dashboard figures, computed CLIENT-SIDE from the orders stream.
/// Pure Dart — no Flutter/Firebase — so it is fully unit-testable.
class DashboardStats {
  final int todaysOrderCount;
  final double todaysRevenue;
  final int pendingCount;

  /// Best-selling item name today, or null when there are no (non-cancelled)
  /// orders today. [bestSellerCount] is its total quantity sold today.
  final String? bestSellerName;
  final int bestSellerCount;

  const DashboardStats({
    required this.todaysOrderCount,
    required this.todaysRevenue,
    required this.pendingCount,
    required this.bestSellerName,
    required this.bestSellerCount,
  });

  static const empty = DashboardStats(
    todaysOrderCount: 0,
    todaysRevenue: 0,
    pendingCount: 0,
    bestSellerName: null,
    bestSellerCount: 0,
  );
}

/// Aggregates [orders] into [DashboardStats]. Pass [now] in tests for a fixed
/// clock. Empty/no-orders is handled gracefully (zeros, no best seller).
///
/// Decisions (noted): "today" uses the LOCAL calendar day; revenue and the best
/// seller EXCLUDE cancelled orders (a cancelled order wasn't really sold);
/// `pendingCount` is all `pending` orders (action-required regardless of day).
DashboardStats computeDashboardStats(List<Order> orders, {DateTime? now}) {
  final ref = (now ?? DateTime.now()).toLocal();
  bool isToday(DateTime t) {
    final l = t.toLocal();
    return l.year == ref.year && l.month == ref.month && l.day == ref.day;
  }

  final todays = orders.where((o) => isToday(o.createdAt)).toList();

  final todaysRevenue = todays
      .where((o) => o.status != OrderStatus.cancelled)
      .fold<double>(0.0, (sum, o) => sum + o.total);

  final pendingCount =
      orders.where((o) => o.status == OrderStatus.pending).length;

  // Total quantity sold per item name across today's non-cancelled orders.
  // Insertion-ordered map → on a tie, the first-seen item wins deterministically.
  final counts = <String, int>{};
  for (final o in todays) {
    if (o.status == OrderStatus.cancelled) continue;
    for (final item in o.items) {
      counts[item.name] = (counts[item.name] ?? 0) + item.quantity;
    }
  }
  String? bestName;
  var bestCount = 0;
  counts.forEach((name, count) {
    if (count > bestCount) {
      bestCount = count;
      bestName = name;
    }
  });

  return DashboardStats(
    todaysOrderCount: todays.length,
    todaysRevenue: todaysRevenue,
    pendingCount: pendingCount,
    bestSellerName: bestName,
    bestSellerCount: bestCount,
  );
}
