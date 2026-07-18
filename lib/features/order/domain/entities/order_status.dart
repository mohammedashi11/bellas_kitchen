/// Lifecycle state of an [Order]. Pure Dart.
///
/// Happy path: pending → accepted → preparing → ready → completed.
/// Cancellation is allowed ONLY from [pending] — once the kitchen has accepted
/// an order, food is committed and neither the customer nor an admin may cancel
/// it from the app. `completed` and `cancelled` are terminal (no further
/// transitions).
enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  completed,
  cancelled;

  /// Storage keys this app once wrote that no longer match an enum name.
  ///
  /// `completed` was called `delivered` while the app modelled delivery. Old
  /// documents still hold that string, and [fromStorage] falls back to
  /// [pending] for anything it doesn't recognise — so WITHOUT this map a
  /// finished order would read back as pending: it would reappear in the admin
  /// "New" tab offering Accept/Reject, and become customer-cancellable again.
  /// Mapping it explicitly keeps such orders terminal and correct.
  static const Map<String, OrderStatus> _legacyStorageKeys = {
    'delivered': OrderStatus.completed,
  };

  /// Human-readable label for UI.
  String get displayLabel => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready for Pickup',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Stable string used for Firestore storage (the enum name).
  String get storageKey => name;

  /// The set of statuses this status is allowed to transition to.
  /// Terminal statuses ([completed], [cancelled]) return an empty set.
  ///
  /// [cancelled] is reachable ONLY from [pending]: an accepted order is already
  /// being made, so it can only move forward. This is the single source of truth
  /// for the rule — the customer cancel flow, the admin REJECT action and the
  /// Firestore rules all enforce the same constraint.
  Set<OrderStatus> get allowedNextStatuses => switch (this) {
        OrderStatus.pending => {OrderStatus.accepted, OrderStatus.cancelled},
        OrderStatus.accepted => {OrderStatus.preparing},
        OrderStatus.preparing => {OrderStatus.ready},
        OrderStatus.ready => {OrderStatus.completed},
        OrderStatus.completed => <OrderStatus>{},
        OrderStatus.cancelled => <OrderStatus>{},
      };

  /// Whether a move from this status to [next] is permitted.
  bool canTransitionTo(OrderStatus next) => allowedNextStatuses.contains(next);

  /// Whether this is a terminal status (no further transitions).
  bool get isTerminal => allowedNextStatuses.isEmpty;

  /// Parse a stored [storageKey] back into an [OrderStatus].
  ///
  /// Recognises current enum names first, then [_legacyStorageKeys] for values
  /// this app wrote under older names. Anything still unmatched (or missing)
  /// falls back to [pending].
  static OrderStatus fromStorage(String? key) {
    for (final status in OrderStatus.values) {
      if (status.name == key) return status;
    }
    return _legacyStorageKeys[key] ?? OrderStatus.pending;
  }
}
