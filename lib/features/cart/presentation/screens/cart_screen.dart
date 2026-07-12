import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../order/domain/entities/payment_method.dart';
import '../../../order/presentation/providers/checkout_providers.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/cart_providers.dart';

/// The "Your Order" / checkout screen. Drives item edits through [cartProvider]
/// and places a real order via the checkout controller.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _addressController = TextEditingController();
  String? _addressError;
  String? _placeError;

  @override
  void initState() {
    super.initState();
    // Clear any stale success/error from a previous visit so it doesn't
    // re-trigger navigation on this one.
    Future.microtask(
      () => ref.read(checkoutControllerProvider.notifier).reset(),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _addressError = 'Please enter a delivery address.');
      return;
    }
    setState(() {
      _addressError = null;
      _placeError = null;
    });
    FocusScope.of(context).unfocus();
    ref
        .read(checkoutControllerProvider.notifier)
        .placeOrder(deliveryAddress: address);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final isPlacing = checkout is CheckoutPlacing;

    ref.listen<CheckoutState>(checkoutControllerProvider, (prev, next) {
      if (next is CheckoutSuccess) {
        context.go('${AppConstants.routeOrder}/${next.order.id}',
            extra: next.order);
      } else if (next is CheckoutError) {
        setState(() => _placeError = next.failure.message);
      } else if (next is CheckoutPlacing) {
        setState(() => _placeError = null);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _CartAppBar(),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyCart()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _SectionHeader('ORDER SUMMARY'),
                        const SizedBox(height: 12),
                        ...items.map((ci) => _CartItemCard(cartItem: ci)),
                        const SizedBox(height: 20),
                        _SectionHeader('DELIVERY DETAILS'),
                        const SizedBox(height: 12),
                        _AddressField(
                          controller: _addressController,
                          errorText: _addressError,
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader('PAYMENT METHOD'),
                        const SizedBox(height: 12),
                        const _PaymentSelector(),
                      ],
                    ),
            ),
            if (items.isNotEmpty)
              _OrderSummaryBar(
                isPlacing: isPlacing,
                errorText: _placeError,
                onPlaceOrder: _placeOrder,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── App bar ────────────────────────────────────────────────────────────────

class _CartAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          Expanded(
            child: Center(
              child: Text('Your Order', style: AppTextStyles.heading2),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.cartBarLabel.copyWith(letterSpacing: 1.2),
    );
  }
}

// ─── Cart item card ───────────────────────────────────────────────────────────

class _CartItemCard extends ConsumerWidget {
  final CartItem cartItem;
  const _CartItemCard({required this.cartItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = cartItem.item;
    final cart = ref.read(cartProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(width: 72, height: 72, color: AppColors.surface),
              errorWidget: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: AppColors.surface,
                child: const Icon(Icons.restaurant,
                    color: AppColors.textSecondary, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => cart.removeItem(item.id),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: AppTextStyles.itemDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('\$${item.price.toStringAsFixed(2)}',
                        style: AppTextStyles.price),
                    _QuantityStepper(
                      quantity: cartItem.quantity,
                      onDecrement: () => cart.decrementItem(item.id),
                      onIncrement: () => cart.addItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quantity stepper ─────────────────────────────────────────────────────────

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove_rounded, onTap: onDecrement),
          SizedBox(
            width: 32,
            child: Text('$quantity',
                textAlign: TextAlign.center,
                style: AppTextStyles.cartBarSummary),
          ),
          _StepperButton(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}

// ─── Editable delivery address ────────────────────────────────────────────────

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  const _AddressField({required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null ? AppColors.accent : AppColors.borderColor,
              width: errorText != null ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 2,
                  style: AppTextStyles.itemName,
                  cursorColor: AppColors.accent,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Enter your delivery address',
                    hintStyle: AppTextStyles.searchHint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined,
                  color: AppColors.accent, size: 20),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(errorText!,
                style: AppTextStyles.itemDescription
                    .copyWith(color: AppColors.accent, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

// ─── Payment selector ─────────────────────────────────────────────────────────

class _PaymentSelector extends ConsumerWidget {
  const _PaymentSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPaymentMethodProvider);
    return Row(
      children: [
        Expanded(
          child: _PaymentOption(
            icon: Icons.credit_card_rounded,
            label: 'Card',
            selected: selected == PaymentMethod.card,
            onTap: () => ref.read(selectedPaymentMethodProvider.notifier).state =
                PaymentMethod.card,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PaymentOption(
            icon: Icons.payments_outlined,
            label: 'Cash',
            selected: selected == PaymentMethod.cash,
            onTap: () => ref.read(selectedPaymentMethodProvider.notifier).state =
                PaymentMethod.cash,
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 84,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderColor,
            width: selected ? 1.4 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.cartBarSummary.copyWith(
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order summary bar ────────────────────────────────────────────────────────

class _OrderSummaryBar extends ConsumerWidget {
  final bool isPlacing;
  final String? errorText;
  final VoidCallback onPlaceOrder;

  const _OrderSummaryBar({
    required this.isPlacing,
    required this.errorText,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = ref.watch(cartSubtotalProvider);
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);
    final tax = ref.watch(cartTaxProvider);
    final total = ref.watch(cartTotalProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Subtotal', value: subtotal),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Tax', value: tax),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            _SummaryRow(label: 'Total', value: total, emphasize: true),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(errorText!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.itemDescription
                            .copyWith(color: AppColors.accent, fontSize: 13)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _PlaceOrderButton(isLoading: isPlacing, onPressed: onPlaceOrder),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize
        ? AppTextStyles.heading2
        : AppTextStyles.itemDescription.copyWith(color: AppColors.textPrimary);
    final valueStyle = emphasize
        ? AppTextStyles.heading2.copyWith(color: AppColors.accent)
        : AppTextStyles.cartBarSummary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text('\$${value.toStringAsFixed(2)}', style: valueStyle),
      ],
    );
  }
}

class _PlaceOrderButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _PlaceOrderButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Place Order',
                      style:
                          AppTextStyles.heading2.copyWith(color: Colors.white)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 24),
                ],
              ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined,
              color: AppColors.textHint, size: 56),
          const SizedBox(height: 12),
          Text('Your cart is empty', style: AppTextStyles.itemDescription),
        ],
      ),
    );
  }
}
