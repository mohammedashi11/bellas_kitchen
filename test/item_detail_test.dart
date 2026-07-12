import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/features/cart/presentation/providers/cart_providers.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/presentation/screens/item_detail_screen.dart';

void main() {
  group('itemDetailTotal', () {
    test('single item, no add-ons = base price', () {
      expect(
        itemDetailTotal(basePrice: 12.99, quantity: 1, selectedDeltas: const []),
        closeTo(12.99, 1e-9),
      );
    });

    test('quantity multiplies the base price', () {
      expect(
        itemDetailTotal(basePrice: 12.99, quantity: 3, selectedDeltas: const []),
        closeTo(38.97, 1e-9),
      );
    });

    test('add-on deltas are added to the unit price before multiplying', () {
      // (12.99 + 1.00 + 1.50) * 2 = 30.98
      expect(
        itemDetailTotal(
          basePrice: 12.99,
          quantity: 2,
          selectedDeltas: const [1.00, 1.50],
        ),
        closeTo(30.98, 1e-9),
      );
    });

    test('free (toggle) add-ons do not change the total', () {
      final withFree = itemDetailTotal(
        basePrice: 8.99,
        quantity: 2,
        selectedDeltas: const [0.0],
      );
      final without = itemDetailTotal(
        basePrice: 8.99,
        quantity: 2,
        selectedDeltas: const [],
      );
      expect(withFree, closeTo(without, 1e-9));
      expect(withFree, closeTo(17.98, 1e-9));
    });

    test('kDetailAddOns carries the expected priced deltas', () {
      final priced =
          kDetailAddOns.where((a) => !a.isToggle).map((a) => a.priceDelta);
      expect(priced, containsAll(<double>[1.00, 1.50]));
      // Toggle add-ons are free.
      expect(
        kDetailAddOns.where((a) => a.isToggle).every((a) => a.priceDelta == 0.0),
        isTrue,
      );
    });
  });

  // The button must not lie: its total equals base × qty (add-ons deferred),
  // and that equals exactly what enters the cart.
  testWidgets('button total = base×qty, ignores add-ons, matches cart line',
      (tester) async {
    final item = MenuItem(
      id: 'x',
      name: 'Test Burger',
      description: 'desc',
      price: 12.99,
      imageUrl: '',
      category: 'Burgers',
      createdAt: DateTime.utc(2024, 1, 1),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Tall viewport so the whole screen (incl. add-on rows) is on-screen and
    // tappable. Kept wide (800) because GoogleFonts can't load in tests and the
    // wider fallback font would overflow narrow rows — a test-only artifact.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ItemDetailScreen(itemId: 'x', item: item)),
      ),
    );
    await tester.pump();

    // qty 1 → button shows base price.
    expect(find.text('Add to Cart  -  \$12.99'), findsOneWidget);

    // Selecting a priced add-on must NOT change the button total.
    await tester.tap(find.text('Extra Cheese'));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$12.99'), findsOneWidget);
    expect(find.textContaining('13.99'), findsNothing);

    // Increment to qty 2 → base × 2.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$25.98'), findsOneWidget);

    // Add to cart → cart line total equals the button total (add-on excluded).
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pump();
    expect(container.read(cartSubtotalProvider), closeTo(25.98, 1e-9));
    expect(container.read(cartItemCountProvider), 2);

    // Let the confirmation snackbar's timer elapse before teardown.
    await tester.pump(const Duration(seconds: 2));
  });
}
