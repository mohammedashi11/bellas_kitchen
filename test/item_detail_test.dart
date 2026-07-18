import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/features/cart/domain/entities/cart_item.dart';
import 'package:bellas_kitchen/features/cart/presentation/providers/cart_providers.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/add_on.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/presentation/screens/item_detail_screen.dart';

const _cheese = AddOn(id: 'cheese', name: 'Extra Cheese', price: 1.00);
const _bacon = AddOn(id: 'bacon', name: 'Bacon', price: 1.50);
const _noOnions = AddOn(id: 'no-onions', name: 'No Onions', price: 0.00);

MenuItem _item({List<AddOn> addOns = const []}) => MenuItem(
      id: 'x',
      name: 'Test Burger',
      description: 'desc',
      price: 12.99,
      imageUrl: '',
      category: 'Burgers',
      createdAt: DateTime.utc(2024, 1, 1),
      availableAddOns: addOns,
    );

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

    test('matches CartItem.unitPrice × quantity (button cannot lie)', () {
      // The button total and the resulting cart line are computed by different
      // code paths; they must agree or the customer sees one price and is
      // charged another.
      final cartLine = CartItem(
        item: _item(addOns: const [_cheese, _bacon]),
        quantity: 2,
        selectedAddOns: const [_cheese, _bacon],
      );
      final buttonTotal = itemDetailTotal(
        basePrice: 12.99,
        quantity: 2,
        selectedDeltas: const [_cheese, _bacon].map((a) => a.price),
      );
      expect(buttonTotal, closeTo(cartLine.lineTotal, 1e-9));
    });
  });

  // The button must not lie: its total tracks the add-on selection live, and
  // that is exactly what enters the cart.
  testWidgets('button total tracks add-ons live and matches the cart line',
      (tester) async {
    final item = _item(addOns: const [_cheese, _bacon, _noOnions]);
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

    // qty 1, nothing selected → base price.
    expect(find.text('Add to Cart  -  \$12.99'), findsOneWidget);

    // Selecting a priced add-on updates the button LIVE (12.99 + 1.00).
    await tester.tap(find.text('Extra Cheese'));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$13.99'), findsOneWidget);

    // A free preference is selectable but changes nothing.
    await tester.tap(find.text('No Onions'));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$13.99'), findsOneWidget);

    // Deselecting returns to the base price.
    await tester.tap(find.text('Extra Cheese'));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$12.99'), findsOneWidget);

    // Reselect, then increment to qty 2 → (12.99 + 1.00) × 2 = 27.98.
    await tester.tap(find.text('Extra Cheese'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(find.text('Add to Cart  -  \$27.98'), findsOneWidget);

    // Add to cart → the cart line total equals the button total exactly.
    await tester.tap(find.textContaining('Add to Cart'));
    await tester.pump();
    expect(container.read(cartSubtotalProvider), closeTo(27.98, 1e-9));
    expect(container.read(cartItemCountProvider), 2);

    // And the line carries the selection it was added with.
    final line = container.read(cartItemsProvider).single;
    expect(line.selectedAddOns.map((a) => a.id),
        containsAll(<String>['cheese', 'no-onions']));

    // Let the confirmation snackbar's timer elapse before teardown.
    await tester.pump(const Duration(seconds: 2));
  });
}
