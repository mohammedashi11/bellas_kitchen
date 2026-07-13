import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../theme/admin_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_live_orders_view.dart';

/// The admin app shell: one Scaffold + one shared bottom nav across all admin
/// tabs. Post-login landing (`/admin/dashboard`) opens on Home (Dashboard).
///
/// Tabs: Home (Dashboard) · Orders (Live Orders) · Menu (placeholder) ·
/// Settings (placeholder, holds sign-out).
class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            AdminDashboardScreen(
              onViewAllOrders: () => setState(() => _index = 1),
            ),
            const AdminLiveOrdersView(),
            const _AdminPlaceholder(
                title: 'Menu Management', icon: Icons.menu_book_rounded),
            _SettingsPlaceholder(
              onSignOut: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────

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

// ─── Shared bottom nav ────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _AdminBottomNav({required this.index, required this.onTap});

  static const _items = [
    (Icons.dashboard_rounded, 'Home'),
    (Icons.receipt_long_rounded, 'Orders'),
    (Icons.menu_book_rounded, 'Menu'),
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
