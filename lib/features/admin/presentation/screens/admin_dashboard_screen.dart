import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../order/domain/entities/order.dart';
import '../../../order/domain/entities/order_status.dart';
import '../../../order/presentation/providers/order_providers.dart';
import '../admin_order_view.dart';
import '../dashboard_providers.dart';
import '../dashboard_stats.dart';
import '../theme/admin_colors.dart';

/// Admin Home tab — today's stats + recent orders. Content only; the shared
/// admin shell provides the bottom nav. [onViewAllOrders] switches the shell to
/// the Orders (Live Orders) tab.
class AdminDashboardScreen extends ConsumerWidget {
  final VoidCallback onViewAllOrders;
  const AdminDashboardScreen({super.key, required this.onViewAllOrders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final recent = ref.watch(recentOrdersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(),
        const SizedBox(height: 20),
        _StatGrid(stats: stats),
        const SizedBox(height: 28),
        _RecentHeader(onViewAll: onViewAllOrders),
        const SizedBox(height: 12),
        ordersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: CircularProgressIndicator(color: AdminColors.accent)),
          ),
          error: (e, _) => _RecentMessage(
              text: e.toString().replaceFirst('Exception: ', '')),
          data: (_) => recent.isEmpty
              ? const _RecentMessage(text: 'No orders yet.')
              : Column(
                  children: [for (final o in recent) _RecentOrderRow(order: o)],
                ),
        ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_circle_rounded,
              color: AdminColors.accentBright, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Welcome back, Admin',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        // Inert notification bell (no notifications backend yet).
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: AdminColors.textSecondary, size: 26),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AdminColors.accent, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Stat cards (2×2) ─────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final best = stats.bestSellerName;
    // Each row is wrapped in IntrinsicHeight so CrossAxisAlignment.stretch has
    // a BOUNDED cross axis to fill (the tallest card's intrinsic height).
    // Bare `stretch` here previously crashed with "BoxConstraints forces an
    // infinite height": this Column lives in a ListView, which lays children
    // out with unbounded max-height, so stretch made the tight child height
    // infinite. IntrinsicHeight keeps the cards equal-height per row with no
    // hardcoded dimensions, so the grid stays responsive at any window width.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.shopping_cart_outlined,
                  iconColor: AdminColors.accentBright,
                  label: 'ORDERS',
                  value: '${stats.todaysOrderCount}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  icon: Icons.payments_outlined,
                  iconColor: AdminColors.accentBright,
                  label: 'REVENUE',
                  value: '\$${stats.todaysRevenue.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'PENDING',
                  value: '${stats.pendingCount}',
                  subtitle: 'Action required',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  icon: Icons.star_border_rounded,
                  iconColor: AdminColors.accentBright,
                  label: 'BEST SELLER',
                  value: best ?? '—',
                  valueFontSize: best == null ? 26 : 19,
                  subtitle: best == null
                      ? 'No sales today'
                      : '${stats.bestSellerCount} sold today',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final double valueFontSize;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueFontSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              // Flexible + ellipsis so long labels (BEST SELLER) can't
              // overflow a narrow card.
              Expanded(
                child: Text(label,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AdminColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AdminColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          // Trend deltas ("+12%") are intentionally omitted — there is no
          // historical baseline, so we never show an invented percentage.
        ],
      ),
    );
  }
}

// ─── Recent orders ────────────────────────────────────────────────────────────

class _RecentHeader extends StatelessWidget {
  final VoidCallback onViewAll;
  const _RecentHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Expanded + ellipsis so the title can't push VIEW ALL off-screen at
        // narrow window widths.
        Expanded(
          child: Text('Recent Orders',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onViewAll,
          child: Row(
            children: [
              Text('VIEW ALL',
                  style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.accent)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AdminColors.accent, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  final Order order;
  const _RecentOrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderNumber(order.id),
                        style: GoogleFonts.robotoMono(
                            fontSize: 13, color: AdminColors.accentBright)),
                    const SizedBox(height: 4),
                    Text(customerLabel(order.userId),
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AdminColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Text('\$${order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  static Color _color(OrderStatus s) => switch (s) {
        OrderStatus.pending => const Color(0xFFF59E0B),
        OrderStatus.accepted => AdminColors.accent,
        OrderStatus.preparing => const Color(0xFFF97316),
        OrderStatus.ready => const Color(0xFF38BDF8),
        OrderStatus.completed => AdminColors.success,
        OrderStatus.cancelled => AdminColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.displayLabel.toUpperCase(),
          style: GoogleFonts.robotoMono(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: c)),
    );
  }
}

class _RecentMessage extends StatelessWidget {
  final String text;
  const _RecentMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AdminColors.textSecondary)),
      ),
    );
  }
}
