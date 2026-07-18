import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../user/domain/entities/app_user.dart';
import '../entities/order.dart';
import '../entities/order_add_on.dart';
import '../entities/order_item.dart';
import '../entities/order_status.dart';
import '../entities/payment_method.dart';
import '../repositories/order_repository.dart';

/// Turns the current cart into a placed [Order].
///
/// Pure domain logic (no Riverpod/Firebase) so it is fully unit-testable.
class PlaceOrderUseCase {
  final OrderRepository _repository;
  final AuthRepository _authRepository;
  const PlaceOrderUseCase(this._repository, this._authRepository);

  Future<Result<Order>> call({
    required List<CartItem> cartItems,
    required String deliveryAddress,
    required PaymentMethod payment,
    required AppUser? currentUser,
  }) async {
    if (cartItems.isEmpty) {
      return const Failure(ValidationFailure('Your cart is empty.'));
    }

    // Owner resolution: a signed-in (phone) user contributes their real uid.
    // An unauthenticated checkout signs in ANONYMOUSLY so the order still has a
    // real Firebase uid (request.auth.uid) — this keeps demo mode frictionless
    // (no phone-login wall) while letting Firestore rules be auth-gated with no
    // 'guest' string. If anonymous sign-in fails, the order is not placed.
    final String userId;
    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      final anon = await _authRepository.signInAnonymously();
      if (anon is Failure<AppUser>) return Failure(anon.failure);
      userId = (anon as Success<AppUser>).data.uid;
    }

    // FROZEN SNAPSHOTS: capture name/price/quantity — and every selected
    // add-on's name/price — at checkout time. The order must preserve exactly
    // what was charged even if the menu item or its add-ons later change
    // (Master Spec) — hence copies, not live MenuItem/AddOn references.
    final items = cartItems
        .map((ci) => OrderItem(
              menuItemId: ci.item.id,
              name: ci.item.name,
              price: ci.item.price,
              quantity: ci.quantity,
              addOns: ci.selectedAddOns
                  .map((a) => OrderAddOn(name: a.name, price: a.price))
                  .toList(),
            ))
        .toList();

    final subtotal = items.fold<double>(0.0, (sum, i) => sum + i.lineTotal);
    final tax = subtotal * AppConstants.taxRate;
    // Pickup-only: no delivery fee in the total.
    final total = subtotal + tax;

    final now = DateTime.now();
    final order = Order(
      id: '', // assigned by Firestore on write
      userId: userId,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      status: OrderStatus.pending,
      payment: payment,
      deliveryAddress: deliveryAddress,
      createdAt: now,
      updatedAt: now,
    );

    return _repository.placeOrder(order);
  }
}
