/// Lifecycle state of an [Order]. Pure Dart.
///
/// Happy path: pending → accepted → preparing → ready → delivered.
/// An order may be cancelled from any non-terminal state. `delivered` and
/// `cancelled` are terminal (no further transitions).
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
  Set<OrderStatus> get allowedNextStatuses => switch (this) {
        OrderStatus.pending => {OrderStatus.accepted, OrderStatus.cancelled},
        OrderStatus.accepted => {OrderStatus.preparing, OrderStatus.cancelled},
        OrderStatus.preparing => {OrderStatus.ready, OrderStatus.cancelled},
        OrderStatus.ready => {OrderStatus.delivered, OrderStatus.cancelled},
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
