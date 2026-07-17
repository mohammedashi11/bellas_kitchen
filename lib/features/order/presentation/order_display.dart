// Shared, pure display helpers for orders — used by both the admin order
// screens and the customer order-history/profile screens. Pure Dart, no
// Flutter, fully unit-testable.

/// Short, human display order number from a Firestore doc id, e.g. "#BK-9025".
String orderNumber(String id) {
  if (id.isEmpty) return '#BK-0000';
  final tail = id.length >= 4 ? id.substring(id.length - 4) : id;
  return '#BK-${tail.toUpperCase()}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Human order date, e.g. "Oct 12, 2023" (local time).
String formatOrderDate(DateTime date) {
  final d = date.toLocal();
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
