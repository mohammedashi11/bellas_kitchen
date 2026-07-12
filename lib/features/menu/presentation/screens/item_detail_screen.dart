import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../domain/entities/menu_item.dart';
import '../providers/menu_providers.dart';

// ─── Add-on model + pricing (local, not persisted) ────────────────────────────

/// A single customization option. Local UI concept only — see the add-on
/// modeling note in the item detail feature; not persisted to the cart yet.
class AddOn {
  final String label;
  final double priceDelta;

  /// Toggle (Switch) styling for free preferences vs. a priced checkbox.
  final bool isToggle;

  const AddOn(this.label, this.priceDelta, {this.isToggle = false});
}

/// Placeholder add-ons for the detail screen. Deliberately simple.
const List<AddOn> kDetailAddOns = [
  AddOn('Extra Cheese', 1.00),
  AddOn('Bacon', 1.50),
  AddOn('No Onions', 0.00, isToggle: true),
  AddOn('Toasted Bun', 0.00, isToggle: true),
];

/// Total shown on the "Add to Cart" button:
/// `quantity × (basePrice + Σ selected add-on deltas)`. Pure & testable.
double itemDetailTotal({
  required double basePrice,
  required int quantity,
  required Iterable<double> selectedDeltas,
}) {
  final unit =
      basePrice + selectedDeltas.fold<double>(0.0, (sum, d) => sum + d);
  return unit * quantity;
}

// ─── Screen (resolves the MenuItem, then renders the body) ────────────────────

/// Item detail screen for a single [MenuItem].
///
/// Receives the [MenuItem] directly via go_router `extra` in the normal
/// navigation path (no refetch). When [item] is null — deep link, hot restart,
/// or web refresh, where `extra` doesn't survive — it resolves by [itemId]
/// through the existing [menuItemByIdProvider].
class ItemDetailScreen extends ConsumerWidget {
  final String itemId;
  final MenuItem? item;

  const ItemDetailScreen({super.key, required this.itemId, this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passed = item;
    if (passed != null) {
      return _ItemDetailBody(item: passed);
    }

    final async = ref.watch(menuItemByIdProvider(itemId));
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (e, _) => _DetailMessage(message: 'Something went wrong.\n$e'),
      data: (resolved) => resolved == null
          ? const _DetailMessage(message: 'This item is no longer available.')
          : _ItemDetailBody(item: resolved),
    );
  }
}

// ─── Body (stateful: quantity, add-on selection, favourite) ───────────────────

class _ItemDetailBody extends ConsumerStatefulWidget {
  final MenuItem item;
  const _ItemDetailBody({required this.item});

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody> {
  int _quantity = 1;
  bool _isFavorite = false;
  final Set<int> _selectedAddOns = {};

  // Static/mock rating — no reviews backend yet.
  static const double _rating = 4.8;
  static const int _reviewCount = 124;

  // Add-ons are display-only for now (real modeling lands in the Order feature,
  // where OrderItem is the frozen snapshot). The button total therefore reflects
  // ONLY what actually enters the cart — quantity × base price — so it never
  // shows a figure that differs from the cart line. Selected deltas are
  // intentionally excluded here.
  double get _total => itemDetailTotal(
        basePrice: widget.item.price,
        quantity: _quantity,
        selectedDeltas: const [],
      );

  void _addToCart() {
    // Uses the EXISTING CartNotifier.addItem with the current CartItem shape.
    // Adding N is done by adding one unit at a time (see feature note on why
    // add-ons are not carried into the cart yet).
    final notifier = ref.read(cartProvider.notifier);
    for (var i = 0; i < _quantity; i++) {
      notifier.addItem(widget.item);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_quantity × ${widget.item.name} added to cart',
          style:
              AppTextStyles.itemDescription.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _HeaderImage(
                    item: item,
                    isFavorite: _isFavorite,
                    onBack: () => Navigator.of(context).maybePop(),
                    onToggleFavorite: () =>
                        setState(() => _isFavorite = !_isFavorite),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(item.name,
                                  style: AppTextStyles.heading1),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: AppTextStyles.price.copyWith(fontSize: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _RatingChip(
                                rating: _rating, reviewCount: _reviewCount),
                            const Spacer(),
                            const _OpenNowBadge(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(item.description,
                            style: AppTextStyles.itemDescription
                                .copyWith(fontSize: 15, height: 1.5)),
                        const SizedBox(height: 20),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Customize your order',
                                style: AppTextStyles.heading2),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.borderColor, width: 0.5),
                              ),
                              child: Text('Preview',
                                  style: AppTextStyles.cartBarLabel),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Selections here don't change the price or your cart "
                          'yet — coming soon.',
                          style: AppTextStyles.itemDescription
                              .copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < kDetailAddOns.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AddOnRow(
                              addOn: kDetailAddOns[i],
                              selected: _selectedAddOns.contains(i),
                              onChanged: (v) => setState(() {
                                if (v) {
                                  _selectedAddOns.add(i);
                                } else {
                                  _selectedAddOns.remove(i);
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              quantity: _quantity,
              total: _total,
              onDecrement: () => setState(
                  () => _quantity = _quantity > 1 ? _quantity - 1 : 1),
              onIncrement: () => setState(() => _quantity++),
              onAddToCart: _addToCart,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header image (back + favourite overlay) ──────────────────────────────────

class _HeaderImage extends StatelessWidget {
  final MenuItem item;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;

  const _HeaderImage({
    required this.item,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.surface),
            errorWidget: (_, _, _) => Container(
              color: AppColors.surface,
              child: const Icon(Icons.restaurant,
                  color: AppColors.textSecondary, size: 64),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _CircleButton(
              icon: Icons.arrow_back_rounded, onTap: onBack),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _CircleButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor: isFavorite ? AppColors.accent : Colors.white,
            onTap: onToggleFavorite,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 22),
      ),
    );
  }
}

// ─── Rating chip + open-now badge ─────────────────────────────────────────────

class _RatingChip extends StatelessWidget {
  final double rating;
  final int reviewCount;
  const _RatingChip({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1),
            style: AppTextStyles.itemName.copyWith(color: AppColors.accent)),
        const SizedBox(width: 6),
        Text('($reviewCount reviews)', style: AppTextStyles.itemDescription),
      ],
    );
  }
}

class _OpenNowBadge extends StatelessWidget {
  const _OpenNowBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.openNowGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: AppColors.openNowGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('OPEN NOW', style: AppTextStyles.openNow),
        ],
      ),
    );
  }
}

// ─── Add-on row (checkbox for priced, switch for free toggle) ─────────────────

class _AddOnRow extends StatelessWidget {
  final AddOn addOn;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _AddOnRow({
    required this.addOn,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderColor,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            if (!addOn.isToggle) ...[
              _CheckSquare(selected: selected),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(addOn.label, style: AppTextStyles.itemName),
            ),
            if (addOn.isToggle)
              Switch(
                value: selected,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accent,
              )
            else
              Text(
                '+\$${addOn.priceDelta.toStringAsFixed(2)}',
                style: AppTextStyles.price,
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  final bool selected;
  const _CheckSquare({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.textSecondary,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

// ─── Bottom bar (quantity + total + add to cart) ──────────────────────────────

class _BottomBar extends StatelessWidget {
  final int quantity;
  final double total;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAddToCart;

  const _BottomBar({
    required this.quantity,
    required this.total,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
            Row(
              children: [
                _QuantityStepper(
                  quantity: quantity,
                  onDecrement: onDecrement,
                  onIncrement: onIncrement,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TOTAL PRICE', style: AppTextStyles.cartBarLabel),
                    const SizedBox(height: 2),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: AppTextStyles.heading2),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onAddToCart,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add to Cart  -  \$${total.toStringAsFixed(2)}',
                      style: AppTextStyles.heading2.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          SizedBox(
            width: 36,
            child: Text('$quantity',
                textAlign: TextAlign.center, style: AppTextStyles.heading2),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

// ─── Full-screen message (loading error / not found) ──────────────────────────

class _DetailMessage extends StatelessWidget {
  final String message;
  const _DetailMessage({required this.message});

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.itemDescription),
        ),
      ),
    );
  }
}
