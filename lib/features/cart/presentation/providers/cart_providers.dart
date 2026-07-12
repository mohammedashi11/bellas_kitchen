import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../order/domain/entities/payment_method.dart';
import '../../../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Cart state — in-memory, keyed by menu item id.
// ---------------------------------------------------------------------------
class CartNotifier extends Notifier<Map<String, CartItem>> {
  @override
  Map<String, CartItem> build() => {};

  void addItem(MenuItem item) {
    final existing = state[item.id];
    if (existing != null) {
      state = {
        ...state,
        item.id: existing.copyWith(quantity: existing.quantity + 1),
      };
    } else {
      state = {...state, item.id: CartItem(item: item, quantity: 1)};
    }
  }

  void removeItem(String itemId) {
    final newState = Map<String, CartItem>.from(state);
    newState.remove(itemId);
    state = newState;
  }

  void decrementItem(String itemId) {
    final existing = state[itemId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      removeItem(itemId);
    } else {
      state = {
        ...state,
        itemId: existing.copyWith(quantity: existing.quantity - 1),
      };
    }
  }

  void clear() => state = {};
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, CartItem>>(
  CartNotifier.new,
);

/// Cart items as an ordered list (insertion order preserved).
final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).values.toList();
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).values.fold(0, (sum, ci) => sum + ci.quantity);
});

// ---------------------------------------------------------------------------
// Order pricing breakdown.
// ---------------------------------------------------------------------------
final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).values.fold(0.0, (sum, ci) => sum + ci.lineTotal);
});

/// Delivery fee — only applied when the cart is non-empty.
final cartDeliveryFeeProvider = Provider<double>((ref) {
  final hasItems = ref.watch(cartItemCountProvider) > 0;
  return hasItems ? AppConstants.deliveryFee : 0.0;
});

final cartTaxProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) * AppConstants.taxRate;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) +
      ref.watch(cartDeliveryFeeProvider) +
      ref.watch(cartTaxProvider);
});

// ---------------------------------------------------------------------------
// Payment method selection (local UI state).
// PaymentMethod itself lives in the order domain (it belongs on an Order).
// ---------------------------------------------------------------------------
final selectedPaymentMethodProvider =
    StateProvider<PaymentMethod>((ref) => PaymentMethod.card);
