import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../order/presentation/screens/order_history_screen.dart';
import '../../../order/presentation/providers/order_providers.dart';
import '../../../user/domain/entities/app_user.dart';

/// Customer Profile tab: header, account menu, and a recent-orders preview.
/// Order history itself lives in the Orders tab (/orders); this links to it.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const int _recentPreviewCount = 3;

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is coming soon.',
            style: AppTextStyles.itemDescription
                .copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go(AppConstants.routeHome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(userOrdersProvider);

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
        title: Text("Bella's Kitchen", style: AppTextStyles.appBarTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProfileHeader(
              name: _displayName(user),
              subtitle: _subtitle(user),
              onEditAvatar: () => _comingSoon(context, 'Photo upload'),
            ),
            const SizedBox(height: 24),
            _MenuCard(children: [
              _MenuRow(
                icon: Icons.receipt_long_outlined,
                label: 'My Orders',
                onTap: () => context.push(AppConstants.routeOrders),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.location_on_outlined,
                label: 'Saved Addresses',
                onTap: () => _comingSoon(context, 'Saved addresses'),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => _comingSoon(context, 'Notifications'),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () => _comingSoon(context, 'Help & Support'),
              ),
              const _MenuDivider(),
              _MenuRow(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                destructive: true,
                showChevron: false,
                onTap: () => _logOut(context, ref),
              ),
            ]),
            const SizedBox(height: 28),
            Row(
              children: [
                Text('Recent Orders', style: AppTextStyles.heading2),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(AppConstants.routeOrders),
                  child: Text('View All',
                      style: AppTextStyles.cartBarAction.copyWith(fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ordersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accent)),
              ),
              error: (e, _) => OrderHistoryError(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(userOrdersProvider),
              ),
              data: (orders) => orders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: OrderHistoryEmpty(),
                    )
                  : Column(
                      children: [
                        for (final o in orders.take(_recentPreviewCount))
                          OrderHistoryTile(order: o),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(AppUser? u) {
    if (u == null) return 'Guest';
    final name = u.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (u.phoneNumber.trim().isNotEmpty) return u.phoneNumber;
    return 'Guest';
  }

  String _subtitle(AppUser? u) {
    if (u == null) return 'Guest account';
    final name = u.displayName?.trim();
    final hasName = name != null && name.isNotEmpty;
    // Show phone as the subtitle only when it isn't already the headline name.
    if (hasName && u.phoneNumber.trim().isNotEmpty) return u.phoneNumber;
    return 'Guest account';
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onEditAvatar;

  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.textSecondary, size: 56),
            ),
            // Edit pencil — inert: photo upload needs Firebase Storage, which is
            // disabled (AppConstants.storageUploadEnabled). Shown for parity with
            // the mockup but wired only to a "coming soon" note, never an upload.
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditAvatar,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(name,
            style: AppTextStyles.appBarTitle.copyWith(fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.itemDescription),
      ],
    );
  }
}

// ─── Menu card ────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool showChevron;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.accent : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.itemName.copyWith(color: color)),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => const Divider(
      color: AppColors.divider, height: 1, indent: 16, endIndent: 16);
}
