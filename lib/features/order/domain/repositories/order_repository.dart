import '../../../../core/utils/result.dart';
import '../entities/order.dart';
import '../entities/order_status.dart';

/// Abstract order contract — domain layer. Implementations live in data.
///
/// All results are wrapped in [Result] carrying an `AppFailure` on failure.
/// The watch* methods emit a [Result] per update so stream errors surface as a
/// typed failure rather than an uncaught stream error.
abstract class OrderRepository {
  /// Writes [order] to the `orders` collection and returns it with its new id.
  Future<Result<Order>> placeOrder(Order order);

  /// Live updates for a single order (used by Order Tracking).
  Stream<Result<Order>> watchOrder(String orderId);

  /// Live list of a user's orders, newest first (used by Profile).
  Stream<Result<List<Order>>> watchUserOrders(String userId);

  /// Live list of ALL orders, newest first (admin Live Orders).
  Stream<Result<List<Order>>> watchAllOrders();

  /// Advances an order's status (admin action). Rejects an illegal transition
  /// with a `ValidationFailure` (per [OrderStatus.canTransitionTo]) and stamps
  /// `updatedAt`.
  Future<Result<void>> updateOrderStatus(String orderId, OrderStatus newStatus);
}
