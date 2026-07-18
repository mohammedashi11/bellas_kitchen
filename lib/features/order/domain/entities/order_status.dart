/// Lifecycle state of an [Order]. Pure Dart.
///
/// Happy path: pending → accepted → preparing → ready → delivered.
/// Cancellation is allowed ONLY from [pending] — once the kitchen has accepted
/// an order, food is committed and neither the customer nor an admin may cancel
/// it from the app. `delivered` and `cancelled` are terminal (no further
/// transitions).
enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  delivered,
  cancelled;

  /// Human-readable label for UI.
  String get displayLabel => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready for Pickup',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Stable string used for Firestore storage (the enum name).
  String get storageKey => name;

  /// The set of statuses this status is allowed to transition to.
  /// Terminal statuses ([delivered], [cancelled]) return an empty set.
  ///
  /// [cancelled] is reachable ONLY from [pending]: an accepted order is already
  /// being made, so it can only move forward. This is the single source of truth
  /// for the rule — the customer cancel flow, the admin REJECT action and the
  /// Firestore rules all enforce the same constraint.
  Set<OrderStatus> get allowedNextStatuses => switch (this) {
        OrderStatus.pending => {OrderStatus.accepted, OrderStatus.cancelled},
        OrderStatus.accepted => {OrderStatus.preparing},
        OrderStatus.preparing => {OrderStatus.ready},
        OrderStatus.ready => {OrderStatus.delivered},
        OrderStatus.delivered => <OrderStatus>{},
        OrderStatus.cancelled => <OrderStatus>{},
      };

  /// Whether a move from this status to [next] is permitted.
  bool canTransitionTo(OrderStatus next) => allowedNextStatuses.contains(next);

  /// Whether this is a terminal status (no further transitions).
  bool get isTerminal => allowedNextStatuses.isEmpty;

  /// Parse a stored [storageKey] back into an [OrderStatus], defaulting to
  /// [OrderStatus.pending] for unknown/missing values.
  static OrderStatus fromStorage(String? key) => OrderStatus.values
      .firstWhere((s) => s.name == key, orElse: () => OrderStatus.pending);
}
