import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/domain/entities/order_status.dart';
import '../../../order/domain/order_transition.dart';
import '../../../order/presentation/providers/order_providers.dart';
import '../admin_order_view.dart';
import '../theme/admin_colors.dart';

/// Admin home ("Order Manager"). The Orders tab is the live-orders feature; the
/// other bottom-nav tabs are placeholders (History / Inventory / Settings are
/// separate roadmap items).
class AdminOrderManagerScreen extends ConsumerStatefulWidget {
  const AdminOrderManagerScreen({super.key});

  @override
  ConsumerState<AdminOrderManagerScreen> createState() =>
      _AdminOrderManagerScreenState();
}

class _AdminOrderManagerScreenState
    extends ConsumerState<AdminOrderManagerScreen> {
  int _navIndex = 0;
  AdminOrderTab _tab = AdminOrderTab.incoming;
  final Set<String> _busy = {};
  final Map<String, String> _errors = {};

  Future<void> _act(String orderId, OrderStatus next) async {
    setState(() {
      _busy.add(orderId);
      _errors.remove(orderId);
    });
    final result =
        await ref.read(orderRepositoryProvider).updateOrderStatus(orderId, next);
    if (!mounted) return;
    final err = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.message,
    );
    setState(() {
      _busy.remove(orderId);
      if (err != null) {
        _errors[orderId] = err;
      } else {
        _errors.remove(orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _navIndex,
          children: [
            _liveOrders(),
            const _AdminPlaceholder(
                title: 'History', icon: Icons.history_rounded),
            const _AdminPlaceholder(
                title: 'Inventory', icon: Icons.inventory_2_outlined),
            _SettingsPlaceholder(
              onSignOut: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(
        index: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  Widget _liveOrders() {
    final async = ref.watch(adminOrdersProvider);
    final orders = async.asData?.value ?? const <Order>[];
    final activeCount = orders.where((o) => !o.status.isTerminal).length;
    final filtered =
        orders.where((o) => orderInTab(o.status, _tab)).toList(growable: false);

    return Column(
      children: [
        _TopBar(),
        _FilterTabs(
          selected: _tab,
          onSelect: (t) => setState(() => _tab = t),
        ),
        _LiveFeedHeader(activeCount: activeCount),
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.accent)),
            error: (e, _) => _ErrorBody(message: _errorMessage(e)),
            data: (_) => filtered.isEmpty
                ? const _EmptyBody()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final order = filtered[i];
                      return _OrderCard(
                        order: order,
                        busy: _busy.contains(order.id),
                        error: _errors[order.id],
                        onAdvance: (next) => _act(order.id, next),
                        onReject: () => _act(order.id, OrderStatus.cancelled),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _errorMessage(Object e) {
    final s = e.toString();
    return s.isEmpty ? 'Could not load orders.' : s.replaceFirst('Exception: ', '');
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: AdminColors.textSecondary),
          const SizedBox(width: 12),
          Text('Order Manager',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.accentBright)),
          const Spacer(),
          const Icon(Icons.notifications_none_rounded,
              color: AdminColors.textSecondary),
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AdminColors.accent, width: 1),
            ),
            child: const Icon(Icons.person_rounded,
                color: AdminColors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─── Filter tabs ──────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final AdminOrderTab selected;
  final ValueChanged<AdminOrderTab> onSelect;
  const _FilterTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final tab in AdminOrderTab.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(tab),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: tab == selected
                        ? AdminColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab.label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tab == selected
                          ? const Color(0xFF0A0E1A)
                          : AdminColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Live feed header ─────────────────────────────────────────────────────────

class _LiveFeedHeader extends StatelessWidget {
  final int activeCount;
  const _LiveFeedHeader({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text('Live Feed',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary)),
          const SizedBox(width: 8),
          Text('($activeCount ACTIVE)',
              style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AdminColors.textSecondary)),
          const Spacer(),
          const Icon(Icons.sync_rounded,
              color: AdminColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

// ─── Order card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final String? error;
  final ValueChanged<OrderStatus> onAdvance;
  final VoidCallback onReject;

  const _OrderCard({
    required this.order,
    required this.busy,
    required this.error,
    required this.onAdvance,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final next = forwardStatus(order.status);
    final items = order.items
        .map((i) => '${i.quantity}x ${i.name}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Text(orderNumber(order.id),
                  style: GoogleFonts.robotoMono(
                      fontSize: 13, color: AdminColors.textSecondary)),
              const Spacer(),
              _TimeChip(label: relativeTime(order.createdAt).toUpperCase()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(customerLabel(order.userId),
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Text('\$${order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ITEMS',
                    style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AdminColors.textHint)),
                const SizedBox(height: 4),
                Text(items,
                    style: GoogleFonts.poppins(
                        fontSize: 15, color: AdminColors.textPrimary)),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AdminColors.danger, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(error!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AdminColors.danger)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _actions(next),
        ],
      ),
    );
  }

  Widget _actions(OrderStatus? next) {
    if (busy) {
      return const SizedBox(
        height: 46,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AdminColors.accent),
          ),
        ),
      );
    }

    // Terminal (delivered/cancelled): no actions, just a status chip.
    if (next == null && order.status.isTerminal) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(order.status.displayLabel,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary)),
      );
    }

    // Pending: Accept + Reject.
    if (order.status == OrderStatus.pending && next != null) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'ACCEPT',
              color: AdminColors.success,
              onTap: () => onAdvance(next),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: 'REJECT',
              color: AdminColors.danger,
              onTap: onReject,
            ),
          ),
        ],
      );
    }

    // Accepted / preparing / ready: single forward button.
    if (next != null) {
      return _ActionButton(
        label: markAsLabel(next).toUpperCase(),
        color: AdminColors.accent,
        filled: true,
        onTap: () => onAdvance(next),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  const _TimeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.inputFill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.robotoMono(
              fontSize: 11,
              letterSpacing: 0.5,
              color: AdminColors.textSecondary)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: filled ? 0 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: filled ? const Color(0xFF0A0E1A) : color)),
      ),
    );
  }
}

// ─── Empty / error bodies ─────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('No orders here.',
          style: GoogleFonts.poppins(
              fontSize: 15, color: AdminColors.textSecondary)),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AdminColors.textHint, size: 44),
            const SizedBox(height: 12),
            Text('Live orders unavailable',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AdminColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholders for the other admin tabs ────────────────────────────────────

class _AdminPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  const _AdminPlaceholder({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AdminColors.textHint, size: 52),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Coming soon',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AdminColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  final VoidCallback onSignOut;
  const _SettingsPlaceholder({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.settings_outlined,
              color: AdminColors.textHint, size: 52),
          const SizedBox(height: 14),
          Text('Settings',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Coming soon',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AdminColors.textSecondary)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded,
                color: AdminColors.accent, size: 18),
            label: Text('Sign out',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.accent)),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _AdminBottomNav({required this.index, required this.onTap});

  static const _items = [
    (Icons.receipt_long_rounded, 'Orders'),
    (Icons.history_rounded, 'History'),
    (Icons.inventory_2_outlined, 'Inventory'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_items[i].$1,
                            size: 22,
                            color: i == index
                                ? AdminColors.accentBright
                                : AdminColors.textHint),
                        const SizedBox(height: 4),
                        Text(_items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: i == index
                                    ? AdminColors.accentBright
                                    : AdminColors.textHint)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
