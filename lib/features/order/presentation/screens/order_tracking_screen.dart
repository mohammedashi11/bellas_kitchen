import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../order_stage.dart';
import '../providers/order_providers.dart';

/// Live order tracking, driven by [orderTrackingProvider].
///
/// [initialOrder] (passed via go_router `extra` right after checkout) is used as
/// an optimistic value so the screen is useful immediately and degrades cleanly
/// when the stream can't reach Firestore (shows the known order + a small
/// "live updates unavailable" note instead of a bare error).
class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  // Estimated delivery window is static (no ETA field on Order yet).
  static const String _eta = '25-35 mins';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderTrackingProvider(orderId));

    // Prefer live data, fall back to the optimistic order passed at checkout.
    final Order? order = async.asData?.value ?? initialOrder;
    final bool isLoading = async.isLoading && order == null;
    final bool degraded = async.hasError && order != null;
    final Object? error = async.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : order == null
                      ? _ErrorState(message: _messageFor(error))
                      : _Content(
                          orderId: orderId,
                          order: order,
                          eta: _eta,
                          degraded: degraded,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Could not load your order. Please try again.';
  }
}

String _shortOrderId(String id) {
  if (id.isEmpty) return 'PENDING';
  final tail = id.length > 6 ? id.substring(id.length - 6) : id;
  return 'BK-${tail.toUpperCase()}';
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, color: AppColors.accent, size: 26),
          const SizedBox(width: 10),
          Text("Bella's Kitchen", style: AppTextStyles.appBarTitle),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.go(AppConstants.routeHome),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  /// The route's order id — used for the cancel write. Preferred over
  /// `order.id`, which is empty on the optimistic pre-write order.
  final String orderId;
  final Order order;
  final String eta;
  final bool degraded;

  const _Content({
    required this.orderId,
    required this.order,
    required this.eta,
    required this.degraded,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled = isCancelled(order.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text('ORDER #${_shortOrderId(order.id)}',
                style: AppTextStyles.cartBarLabel.copyWith(letterSpacing: 1)),
            const Spacer(),
            const _LiveStatusBadge(),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          cancelled ? 'Order Cancelled' : 'Estimated Delivery: $eta',
          style: AppTextStyles.appBarTitle.copyWith(fontSize: 26, height: 1.2),
        ),
        if (degraded) ...[
          const SizedBox(height: 10),
          _DegradedNote(),
        ],
        const SizedBox(height: 28),
        if (cancelled)
          const _CancelledCard()
        else
          _StatusStepper(current: order.status),
        const SizedBox(height: 28),
        const _MapPlaceholder(),
        const SizedBox(height: 20),
        _OrderSummaryCard(order: order),
        const SizedBox(height: 24),
        _ContactButton(),
        const SizedBox(height: 16),
        _CancelLink(orderId: orderId, status: order.status),
      ],
    );
  }
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Live Status',
          style: AppTextStyles.itemName
              .copyWith(color: AppColors.accent, fontSize: 13)),
    );
  }
}

class _DegradedNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded,
            color: AppColors.textHint, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Live updates unavailable — showing your last known order.',
            style: AppTextStyles.itemDescription
                .copyWith(color: AppColors.textHint, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Status stepper (derived from the OrderStatus enum) ───────────────────────

class _StatusStepper extends StatelessWidget {
  final OrderStatus current;
  const _StatusStepper({required this.current});

  IconData _iconFor(CustomerStage s) => switch (s) {
        CustomerStage.orderPlaced => Icons.receipt_long_rounded,
        CustomerStage.preparing => Icons.restaurant_rounded,
        CustomerStage.ready => Icons.delivery_dining_rounded,
        CustomerStage.delivered => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final stages = customerStages;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          Expanded(
            child: _StageNode(
              icon: _iconFor(stages[i]),
              label: stages[i].label,
              state: stageStateFor(current, stages[i]),
              // A connector segment is "on" once its adjacent node is reached.
              leftOn: i > 0 &&
                  stageStateFor(current, stages[i]) != StageState.upcoming,
              rightOn: i < stages.length - 1 &&
                  stageStateFor(current, stages[i + 1]) != StageState.upcoming,
              isFirst: i == 0,
              isLast: i == stages.length - 1,
            ),
          ),
      ],
    );
  }
}

class _StageNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final StageState state;
  final bool leftOn;
  final bool rightOn;
  final bool isFirst;
  final bool isLast;

  const _StageNode({
    required this.icon,
    required this.label,
    required this.state,
    required this.leftOn,
    required this.rightOn,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final reached = state != StageState.upcoming;
    final isCurrent = state == StageState.current;
    final circleColor = reached ? AppColors.accent : AppColors.surface;
    final iconColor = reached ? Colors.white : AppColors.bottomNavInactive;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: isFirst
                    ? const SizedBox.shrink()
                    : _Line(on: leftOn),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.55),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Expanded(
                child: isLast ? const SizedBox.shrink() : _Line(on: rightOn),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemDescription.copyWith(
              fontSize: 11,
              height: 1.15,
              color: isCurrent
                  ? AppColors.accent
                  : (reached ? AppColors.textPrimary : AppColors.textHint),
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final bool on;
  const _Line({required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      color: on ? AppColors.accent : AppColors.borderColor,
    );
  }
}

// ─── Cancelled card ───────────────────────────────────────────────────────────

class _CancelledCard extends StatelessWidget {
  const _CancelledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.accent, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This order was cancelled',
                    style: AppTextStyles.itemName),
                const SizedBox(height: 4),
                Text('No further updates will follow.',
                    style: AppTextStyles.itemDescription),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map placeholder ──────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.map_rounded, color: AppColors.surface, size: 96),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.openNowGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Courier is at the restaurant',
                      style: AppTextStyles.itemName.copyWith(fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order summary (collapsible) ──────────────────────────────────────────────

class _OrderSummaryCard extends StatefulWidget {
  final Order order;
  const _OrderSummaryCard({required this.order});

  @override
  State<_OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<_OrderSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Summary', style: AppTextStyles.heading2),
                      const SizedBox(height: 4),
                      Text(
                        '${order.itemCount} '
                        'Item${order.itemCount == 1 ? '' : 's'} - '
                        '\$${order.total.toStringAsFixed(2)}',
                        style: AppTextStyles.itemDescription,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.accent, size: 26),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text('${item.quantity}×',
                        style: AppTextStyles.itemName
                            .copyWith(color: AppColors.accent)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.name,
                          style: AppTextStyles.itemDescription
                              .copyWith(color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('\$${item.lineTotal.toStringAsFixed(2)}',
                        style: AppTextStyles.cartBarSummary),
                  ],
                ),
              ),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTextStyles.heading2),
                Text('\$${order.total.toStringAsFixed(2)}',
                    style: AppTextStyles.heading2
                        .copyWith(color: AppColors.accent)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Contact + cancel ─────────────────────────────────────────────────────────

class _ContactButton extends StatelessWidget {
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
        // Inert for now (no restaurant contact backend).
        onPressed: () => _snack(context, 'Contacting the restaurant is coming '
            'soon.'),
        child: Text('Contact Restaurant',
            style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
    );
  }
}

/// "Cancel Order" action. Visible always, actionable only while the order is
/// still cancellable ([canCancelOrder]).
///
/// Deliberately holds NO cancelled-state of its own: on success the screen
/// flips to the cancelled view purely because [orderTrackingProvider]'s
/// `watchOrder` stream re-emits the updated order. Only the in-flight `_busy`
/// flag is local, to block a double tap.
class _CancelLink extends ConsumerStatefulWidget {
  final String orderId;
  final OrderStatus status;
  const _CancelLink({required this.orderId, required this.status});

  @override
  ConsumerState<_CancelLink> createState() => _CancelLinkState();
}

class _CancelLinkState extends ConsumerState<_CancelLink> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Cancel this order?', style: AppTextStyles.heading2),
        content: Text(
          "This can't be undone. You'll need to place a new order if you "
          'change your mind.',
          style: AppTextStyles.itemDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep Order',
                style: AppTextStyles.itemName
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Cancel Order',
                style:
                    AppTextStyles.itemName.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result =
        await ref.read(orderRepositoryProvider).cancelOrder(widget.orderId);
    if (!mounted) return;
    setState(() => _busy = false);

    // Success needs no UI work here — the watchOrder stream drives the change.
    // Surface the TYPED failure message so the user sees the real reason
    // (permission, network, or an illegal transition) rather than a generic one.
    final failure = result.errorOrNull;
    if (failure != null) _snack(context, failure.message);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = canCancelOrder(widget.status) && !_busy;
    final color = enabled ? AppColors.textSecondary : AppColors.textHint;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textHint),
                )
              else
                Icon(Icons.cancel_outlined, color: color, size: 18),
              const SizedBox(width: 6),
              Text(_busy ? 'Cancelling…' : 'Cancel Order',
                  style: AppTextStyles.itemName
                      .copyWith(color: color, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message,
          style: AppTextStyles.itemDescription
              .copyWith(color: AppColors.textPrimary)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.accent, size: 48),
            const SizedBox(height: 12),
            Text('Could not load your order',
                style: AppTextStyles.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.itemDescription,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go(AppConstants.routeHome),
              child: Text('Back to Menu',
                  style: AppTextStyles.cartBarAction),
            ),
          ],
        ),
      ),
    );
  }
}
