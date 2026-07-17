import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../order_display.dart';
import '../providers/order_providers.dart';

/// Full customer order history — the "Orders" tab (and the destination of
/// Profile's "My Orders" / "View All"). Reads the signed-in user's real orders.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('My Orders', style: AppTextStyles.heading2),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => OrderHistoryError(
            message: e is AppFailure
                ? e.message
                : e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(userOrdersProvider),
          ),
          data: (orders) => orders.isEmpty
              ? const OrderHistoryEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: orders.length,
                  itemBuilder: (context, i) =>
                      OrderHistoryTile(order: orders[i]),
                ),
        ),
      ),
    );
  }
}

/// Reusable order row — used by the full history list AND the Profile preview.
/// Tapping opens the existing Order Tracking route.
class OrderHistoryTile extends StatelessWidget {
  final Order order;
  const OrderHistoryTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('${AppConstants.routeOrder}/${order.id}',
          extra: order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Neutral placeholder (orders don't store item imagery).
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.textSecondary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(orderNumber(order.id),
                          style: AppTextStyles.itemName
                              .copyWith(color: AppColors.accent, fontSize: 14)),
                      const SizedBox(width: 8),
                      _StatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(formatOrderDate(order.createdAt),
                      style: AppTextStyles.itemDescription),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${order.total.toStringAsFixed(2)}',
                    style: AppTextStyles.price),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  Color _color() => switch (status) {
        OrderStatus.delivered => AppColors.openNowGreen,
        OrderStatus.cancelled => AppColors.textHint,
        _ => AppColors.accent,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.displayLabel,
          style: AppTextStyles.openNow.copyWith(color: c)),
    );
  }
}

// ─── Shared empty / error states ──────────────────────────────────────────────

class OrderHistoryEmpty extends StatelessWidget {
  const OrderHistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.textHint, size: 56),
          const SizedBox(height: 12),
          Text('No orders yet',
              style: AppTextStyles.heading2, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Your past orders will show up here.',
              style: AppTextStyles.itemDescription, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class OrderHistoryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const OrderHistoryError(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accent, size: 48),
            const SizedBox(height: 12),
            Text('Could not load your orders',
                style: AppTextStyles.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.itemDescription,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.accent, size: 18),
              label: Text('Retry', style: AppTextStyles.cartBarAction),
            ),
          ],
        ),
      ),
    );
  }
}
