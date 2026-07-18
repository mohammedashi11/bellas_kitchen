import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item.dart';
import '../../../menu/domain/entities/add_on.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../order/domain/entities/payment_method.dart';
import '../../../../core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Cart state — in-memory, keyed by CartItem.lineKey.
//
// The key is the LINE identity, not the menu item id: the same item with a
// different add-on selection is a separate line, while an identical selection
// merges into one. For a line with no add-ons the key IS the menu item id, so
// callers that remove/decrement by item id behave exactly as before.
// ---------------------------------------------------------------------------
class CartNotifier extends Notifier<Map<String, CartItem>> {
  @override
  Map<String, CartItem> build() => {};

  /// Adds one unit of [item] with [selectedAddOns]. Merges into the existing
  /// line when that same item+selection is already in the cart.
  void addItem(MenuItem item, {List<AddOn> selectedAddOns = const []}) {
    final key = CartItem.keyFor(item.id, selectedAddOns);
    final existing = state[key];
    if (existing != null) {
      state = {
        ...state,
        key: existing.copyWith(quantity: existing.quantity + 1),
      };
    } else {
      state = {
        ...state,
        key: CartItem(
          item: item,
          quantity: 1,
          selectedAddOns: selectedAddOns,
        ),
      };
    }
  }

  /// Removes a whole line. [lineKey] is [CartItem.lineKey] — for an add-on-free
  /// line that is simply the menu item id.
  void removeItem(String lineKey) {
    final newState = Map<String, CartItem>.from(state);
    newState.remove(lineKey);
    state = newState;
  }

  void decrementItem(String lineKey) {
    final existing = state[lineKey];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      removeItem(lineKey);
    } else {
      state = {
        ...state,
        lineKey: existing.copyWith(quantity: existing.quantity - 1),
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

final cartTaxProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) * AppConstants.taxRate;
});

/// Pickup-only: no delivery fee, so the total is just subtotal + tax.
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) + ref.watch(cartTaxProvider);
});

// ---------------------------------------------------------------------------
// Payment method selection (local UI state).
// PaymentMethod itself lives in the order domain (it belongs on an Order).
// ---------------------------------------------------------------------------
final selectedPaymentMethodProvider =
    StateProvider<PaymentMethod>((ref) => PaymentMethod.card);
