import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_providers.dart';

/// Floating bottom strip: "CURRENT ORDER · N item · $X.XX  View Cart →"
/// Visible only when cart has at least one item.
class FloatingCartButton extends ConsumerWidget {
  final VoidCallback? onViewCart;

  const FloatingCartButton({super.key, this.onViewCart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartItemCountProvider);
    // Show the items subtotal here; fees/tax are surfaced on the cart screen.
    final total = ref.watch(cartSubtotalProvider);

    if (itemCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cartBarBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onViewCart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Cart icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Summary text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT ORDER',
                        style: AppTextStyles.cartBarLabel,
                      ),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} · '
                        '\$${total.toStringAsFixed(2)}',
                        style: AppTextStyles.cartBarSummary,
                      ),
                    ],
                  ),
                ),
                // View cart action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Cart', style: AppTextStyles.cartBarAction),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
