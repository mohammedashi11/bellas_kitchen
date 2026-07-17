import '../../order/domain/entities/order_status.dart';

// `orderNumber` now lives in the shared order display helper; re-exported here
// so existing admin call sites keep importing it from this file unchanged.
export '../../order/presentation/order_display.dart' show orderNumber;

/// Admin filter tabs and the [OrderStatus] group each maps to.
///
/// Grouping (noted): New = `pending`; Preparing = `accepted` + `preparing`;
/// Ready = `ready`; Completed = `delivered` + `cancelled`.
enum AdminOrderTab {
  incoming,
  preparing,
  ready,
  completed;

  String get label => switch (this) {
        AdminOrderTab.incoming => 'New',
        AdminOrderTab.preparing => 'Preparing',
        AdminOrderTab.ready => 'Ready',
        AdminOrderTab.completed => 'Completed',
      };

  Set<OrderStatus> get statuses => switch (this) {
        AdminOrderTab.incoming => {OrderStatus.pending},
        AdminOrderTab.preparing => {
            OrderStatus.accepted,
            OrderStatus.preparing,
          },
        AdminOrderTab.ready => {OrderStatus.ready},
        AdminOrderTab.completed => {
            OrderStatus.delivered,
            OrderStatus.cancelled,
          },
      };
}

/// Whether an order with [status] belongs under [tab].
bool orderInTab(OrderStatus status, AdminOrderTab tab) =>
    tab.statuses.contains(status);

/// Cheap customer label derived from a userId — NO Firestore read (avoids an
/// N+1 per order). Orders only carry `userId`; a real name would be denormalized
/// onto the order at checkout in a future step.
String customerLabel(String userId) {
  if (userId.isEmpty) return 'Guest';
  final head = userId.length >= 6 ? userId.substring(0, 6) : userId;
  return 'Customer ${head.toUpperCase()}';
}

/// Human relative time from [time], e.g. "Just now", "3 min ago", "2 hr ago".
String relativeTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final d = ref.difference(time);
  if (d.isNegative || d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
}
