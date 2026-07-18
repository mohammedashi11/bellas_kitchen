import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../domain/entities/order.dart';
import 'order_providers.dart';

/// State of the place-order action.
sealed class CheckoutState {
  const CheckoutState();
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

class CheckoutPlacing extends CheckoutState {
  const CheckoutPlacing();
}

class CheckoutSuccess extends CheckoutState {
  final Order order;
  const CheckoutSuccess(this.order);
}

class CheckoutError extends CheckoutState {
  final AppFailure failure;
  const CheckoutError(this.failure);
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

/// Orchestrates placing an order: gathers cart/payment/user, runs the use case,
/// and clears the cart on success. Keeps the UI thin.
class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutIdle();

  Future<void> placeOrder() async {
    state = const CheckoutPlacing();

    final items = ref.read(cartItemsProvider);
    final payment = ref.read(selectedPaymentMethodProvider);
    final currentUser = ref.read(currentUserProvider);
    final useCase = ref.read(placeOrderUseCaseProvider);

    final result = await useCase(
      cartItems: items,
      payment: payment,
      currentUser: currentUser,
    );

    state = result.fold(
      onSuccess: (order) {
        ref.read(cartProvider.notifier).clear();
        return CheckoutSuccess(order);
      },
      onFailure: (failure) => CheckoutError(failure),
    );
  }

  /// Reset to idle (e.g. when re-entering the cart) so a stale success/error
  /// doesn't re-trigger navigation.
  void reset() => state = const CheckoutIdle();
}
