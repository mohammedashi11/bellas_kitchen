import '../../../core/error/app_failure.dart';
import 'entities/order_status.dart';

/// Returns null when [from] → [to] is a legal transition, otherwise a
/// [ValidationFailure]. Derived from [OrderStatus.canTransitionTo] — no
/// hardcoded chain, so it stays in sync with the enum's transition rules.
AppFailure? validateTransition(OrderStatus from, OrderStatus to) {
  if (from.canTransitionTo(to)) return null;
  return ValidationFailure(
    'Cannot move an order from "${from.displayLabel}" to "${to.displayLabel}".',
  );
}

/// The single FORWARD next status — the allowed-next that isn't `cancelled` —
/// or null for a terminal status. Derived from [OrderStatus.allowedNextStatuses].
OrderStatus? forwardStatus(OrderStatus status) {
  final forward =
      status.allowedNextStatuses.where((s) => s != OrderStatus.cancelled);
  return forward.isEmpty ? null : forward.first;
}

/// Advance-button label for [next], e.g. "Mark as Preparing". Title-cases the
/// enum name so it tracks the enum instead of a hardcoded string list.
String markAsLabel(OrderStatus next) {
  final n = next.name;
  return 'Mark as ${n[0].toUpperCase()}${n.substring(1)}';
}
