import '../domain/entities/order_status.dart';

/// How a single stepper node should render.
enum StageState { complete, current, upcoming }

/// Customer-facing lifecycle stages shown in the tracking stepper.
///
/// Deliberately **4 nodes, not 5**: the [OrderStatus] `pending → accepted` split
/// is an internal/admin distinction ("received" vs "confirmed by the kitchen")
/// that the customer shouldn't see, so both map to a single "Order Placed" node.
/// The [OrderStatus] enum is unchanged — all 5 values remain for admin use; this
/// is purely a display grouping.
enum CustomerStage {
  orderPlaced,
  preparing,
  ready,
  delivered;

  String get label => switch (this) {
        CustomerStage.orderPlaced => 'Order Placed',
        CustomerStage.preparing => 'Preparing',
        CustomerStage.ready => 'Ready',
        // "Picked Up", not "Delivered": pickup-only app. The underlying
        // OrderStatus.delivered enum/storage key is unchanged — this is the
        // customer-facing label only.
        CustomerStage.delivered => 'Picked Up',
      };
}

/// The ordered customer stages (4 nodes).
List<CustomerStage> get customerStages => CustomerStage.values;

/// Maps an [OrderStatus] to the customer stage it belongs to.
///
/// `pending` and `accepted` both group into [CustomerStage.orderPlaced].
/// `cancelled` has no linear stage (it's handled separately via [isCancelled]);
/// it returns [CustomerStage.orderPlaced] only as a harmless default and is
/// never used for a cancelled order.
CustomerStage customerStageOf(OrderStatus status) => switch (status) {
      OrderStatus.pending => CustomerStage.orderPlaced,
      OrderStatus.accepted => CustomerStage.orderPlaced,
      OrderStatus.preparing => CustomerStage.preparing,
      OrderStatus.ready => CustomerStage.ready,
      OrderStatus.delivered => CustomerStage.delivered,
      OrderStatus.cancelled => CustomerStage.orderPlaced,
    };

/// How the customer [stage] renders given the order's [current] status:
/// - `complete`  — already passed (and the whole track once `delivered`),
/// - `current`   — the active stage,
/// - `upcoming`  — not yet reached.
///
/// Not meaningful for a cancelled order — the UI shows a distinct cancelled
/// state instead (see [isCancelled]).
StageState stageStateFor(OrderStatus current, CustomerStage stage) {
  // Delivered is terminal-success: the entire track reads as complete.
  if (current == OrderStatus.delivered) return StageState.complete;
  final currentStage = customerStageOf(current);
  if (currentStage.index > stage.index) return StageState.complete;
  if (currentStage.index == stage.index) return StageState.current;
  return StageState.upcoming;
}

/// Whether the order is cancelled (rendered as a distinct state, not the
/// linear stepper).
bool isCancelled(OrderStatus status) => status == OrderStatus.cancelled;

/// Progress line shown under the stepper, derived ENTIRELY from the real order
/// status.
///
/// This replaced a hardcoded "Courier is at the restaurant" caption sitting on
/// a decorative map box. There is no courier and no delivery tracking, so that
/// line asserted a fact the system could not know — it read as live tracking
/// while being a constant. Every string here is a direct function of a status
/// the backend actually sets.
String trackingStatusMessage(OrderStatus status) => switch (status) {
      OrderStatus.pending => "We've received your order.",
      OrderStatus.accepted => 'The kitchen has confirmed your order.',
      OrderStatus.preparing => 'Your order is being prepared.',
      OrderStatus.ready => 'Your order is ready for pickup.',
      OrderStatus.delivered => 'Picked up — enjoy your meal!',
      OrderStatus.cancelled => 'This order was cancelled.',
    };

/// Whether the tracking screen offers cancellation — ONLY while pending.
///
/// This mirrors the domain rule rather than narrowing it: `cancelled` is
/// reachable only from `pending` per [OrderStatus.allowedNextStatuses], so the
/// link is enabled exactly when the write would actually be legal. The
/// repository guard and the Firestore rules enforce the same constraint; this
/// is the UI affordance, not the enforcement.
bool canCancelOrder(OrderStatus status) =>
    status.canTransitionTo(OrderStatus.cancelled);
