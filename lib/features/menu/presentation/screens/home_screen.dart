import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../providers/menu_providers.dart';
import '../widgets/category_tab_bar.dart';
import '../widgets/floating_cart_button.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/search_bar_widget.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';

/// The main Home / Menu screen for the Customer App.
/// Matches the Bella's Kitchen design reference image exactly.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Home is index 0 in the bottom nav; the other tabs navigate away.
  static const int _homeNavIndex = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break; // Already on Home.
      case 1:
        context.push(AppConstants.routeOrders);
      case 2:
        context.push(AppConstants.routeProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(filteredMenuItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────
            _HomeAppBar(),
            const SizedBox(height: 16),

            // ── Search Bar ────────────────────────────────────────────
            SearchBarWidget(
              onChanged: (query) {
                ref.read(searchQueryProvider.notifier).state = query;
              },
            ),
            const SizedBox(height: 16),

            // ── Category Tabs ─────────────────────────────────────────
            const CategoryTabBar(),
            const SizedBox(height: 12),

            // ── Menu List ─────────────────────────────────────────────
            Expanded(
              child: menuAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) => _ErrorView(
                  message: e.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(menuItemsProvider),
                ),
                data: (items) => items.isEmpty
                    ? _EmptyView(
                        isWholeMenu: ref.read(selectedCategoryProvider) ==
                            AppConstants.categoryAll,
                        hasSearchQuery: ref.read(searchQueryProvider).trim().isNotEmpty,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return MenuItemCard(
                            item: item,
                            onTap: () => context.push(
                              '${AppConstants.routeItem}/${item.id}',
                              extra: item,
                            ),
                            onAddToCart: () {
                              ref.read(cartProvider.notifier).addItem(item);
                              _showAddedSnackBar(item.name);
                            },
                          );
                        },
                      ),
              ),
            ),

            // ── Floating Cart Bar (above bottom nav) ──────────────────
            FloatingCartButton(
              onViewCart: () => context.push(AppConstants.routeCart),
            ),

            // ── Bottom Navigation ─────────────────────────────────────
            BellasBottomNavBar(
              currentIndex: _homeNavIndex,
              onTap: _onNavTap,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddedSnackBar(String itemName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$itemName added to cart',
          style: AppTextStyles.itemDescription
              .copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Logo flame icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          // Title + open now badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bella's Kitchen",
                  style: AppTextStyles.appBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.openNowGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('OPEN NOW', style: AppTextStyles.openNow),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Search icon button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor, width: 0.5),
            ),
            child: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 160, height: 16),
                const SizedBox(height: 8),
                _SkeletonLine(width: double.infinity, height: 12),
                const SizedBox(height: 4),
                _SkeletonLine(width: 220, height: 12),
                const SizedBox(height: 12),
                _SkeletonLine(width: 60, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.accent, size: 48),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.itemDescription,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
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
              label: Text('Retry',
                  style: AppTextStyles.cartBarAction),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  /// True when the WHOLE menu is empty ('All' tab), not just one category.
  final bool isWholeMenu;
  final bool hasSearchQuery;
  const _EmptyView({required this.isWholeMenu, this.hasSearchQuery = false});

  @override
  Widget build(BuildContext context) {
    if (hasSearchQuery) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.textHint, size: 56),
            const SizedBox(height: 12),
            Text(
              'No items match your search',
              style: AppTextStyles.itemDescription,
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu,
              color: AppColors.textHint, size: 56),
          const SizedBox(height: 12),
          Text(
            isWholeMenu
                ? 'Menu coming soon — check back shortly!'
                : 'No items in this category',
            style: AppTextStyles.itemDescription,
          ),
        ],
      ),
    );
  }
}
