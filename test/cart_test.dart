import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/features/cart/presentation/providers/cart_providers.dart';
import 'package:bellas_kitchen/features/cart/presentation/screens/cart_screen.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';

final _burger = MenuItem(
  id: '1',
  name: 'Classic Cheeseburger',
  description: 'Beef patty, cheddar, house sauce',
  price: 12.99,
  imageUrl: '',
  category: 'Burgers',
  createdAt: DateTime.utc(2024, 1, 1),
);

final _pizza = MenuItem(
  id: '2',
  name: 'Margherita Pizza',
  description: 'San Marzano, mozzarella',
  price: 15.50,
  imageUrl: '',
  category: 'Pizza',
  createdAt: DateTime.utc(2024, 1, 2),
);

void main() {
  // ── Behaviors 1, 2, 3: cart mutations drive the pricing providers ──────────
  group('cart pricing providers', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('1. quantity changes update subtotal/tax/total in real time', () {
      final cart = container.read(cartProvider.notifier);

      // Empty cart: no fee, no total.
      expect(container.read(cartSubtotalProvider), 0.0);
      expect(container.read(cartDeliveryFeeProvider), 0.0);
      expect(container.read(cartTotalProvider), 0.0);

      // Add one burger (12.99).
      cart.addItem(_burger);
      expect(container.read(cartItemCountProvider), 1);
      expect(container.read(cartSubtotalProvider), closeTo(12.99, 1e-9));
      expect(container.read(cartDeliveryFeeProvider), AppConstants.deliveryFee);
      expect(container.read(cartTaxProvider),
          closeTo(12.99 * AppConstants.taxRate, 1e-9));
      expect(
        container.read(cartTotalProvider),
        closeTo(12.99 + AppConstants.deliveryFee + 12.99 * AppConstants.taxRate,
            1e-9),
      );

      // Increment burger to qty 2 — subtotal must track live.
      cart.addItem(_burger);
      expect(container.read(cartItemCountProvider), 2);
      expect(container.read(cartSubtotalProvider), closeTo(25.98, 1e-9));

      // Add a pizza, then decrement it back off.
      cart.addItem(_pizza);
      expect(container.read(cartSubtotalProvider), closeTo(41.48, 1e-9));
      cart.decrementItem(_pizza.id);
      expect(container.read(cartSubtotalProvider), closeTo(25.98, 1e-9));
    });

    test('2. removing an item drops it and recomputes totals', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger);
      cart.addItem(_pizza);
      expect(container.read(cartSubtotalProvider), closeTo(28.49, 1e-9));

      cart.removeItem(_burger.id);
      expect(container.read(cartProvider).containsKey(_burger.id), isFalse);
      expect(container.read(cartItemCountProvider), 1);
      expect(container.read(cartSubtotalProvider), closeTo(15.50, 1e-9));

      // Removing the last item returns everything to the empty state.
      cart.removeItem(_pizza.id);
      expect(container.read(cartItemCountProvider), 0);
      expect(container.read(cartDeliveryFeeProvider), 0.0);
      expect(container.read(cartTotalProvider), 0.0);
    });

    test('3. clear() empties the cart (Place Order stub)', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger);
      cart.addItem(_pizza);
      expect(container.read(cartItemCountProvider), 2);

      cart.clear();
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartItemCountProvider), 0);
      expect(container.read(cartTotalProvider), 0.0);
    });

    test('decrementing quantity 1 removes the line entirely', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger);
      cart.decrementItem(_burger.id);
      expect(container.read(cartProvider), isEmpty);
    });
  });

  // ── Behavior 4: cart state survives navigation between routes ──────────────
  testWidgets('4. cart state persists across Home -> Orders -> Profile -> Home',
      (tester) async {
    // A minimal app that shares ONE root ProviderScope across all routes,
    // mirroring how main.dart wraps MaterialApp.router. Each route just prints
    // the live cart count so we can assert it survives navigation.
    Widget countScreen(String title) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(cartItemCountProvider);
              return Column(
                children: [
                  Text('$title count: $count'),
                  TextButton(
                    onPressed: () => context.push(AppConstants.routeOrders),
                    child: const Text('go orders'),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppConstants.routeProfile),
                    child: const Text('go profile'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('back'),
                  ),
                ],
              );
            },
          ),
        );

    final router = GoRouter(
      initialLocation: AppConstants.routeHome,
      routes: [
        GoRoute(
            path: AppConstants.routeHome,
            builder: (_, _) => countScreen('Home')),
        GoRoute(
            path: AppConstants.routeOrders,
            builder: (_, _) => countScreen('Orders')),
        GoRoute(
            path: AppConstants.routeProfile,
            builder: (_, _) => countScreen('Profile')),
      ],
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Seed the cart before the UI mounts.
    container.read(cartProvider.notifier).addItem(_burger);
    container.read(cartProvider.notifier).addItem(_pizza);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Home count: 2'), findsOneWidget);

    // Home -> Orders
    await tester.tap(find.text('go orders'));
    await tester.pumpAndSettle();
    expect(find.text('Orders count: 2'), findsOneWidget);

    // Orders -> Profile
    await tester.tap(find.text('go profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile count: 2'), findsOneWidget);

    // Back to Orders, back to Home — count still intact.
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('Home count: 2'), findsOneWidget);
  });

  // ── CartScreen: steppers/trash work; Place Order requires an address ───────
  testWidgets('CartScreen: steppers/trash work; Place Order needs an address',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(_burger);
    container.read(cartProvider.notifier).addItem(_pizza);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Classic Cheeseburger'), findsOneWidget);
    expect(find.text('Margherita Pizza'), findsOneWidget);
    expect(find.text('Place Order'), findsOneWidget);

    // Tap "+" on the burger row -> quantity provider updates live.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    expect(container.read(cartProvider)[_burger.id]!.quantity, 2);

    // Trash the pizza -> it disappears from the list.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pump();
    expect(find.text('Margherita Pizza'), findsNothing);
    expect(container.read(cartProvider).containsKey(_pizza.id), isFalse);

    // Place Order with an empty address -> inline validation, cart untouched.
    await tester.tap(find.text('Place Order'));
    await tester.pump();
    expect(find.text('Please enter a delivery address.'), findsOneWidget);
    expect(container.read(cartProvider).containsKey(_burger.id), isTrue);
  });
}
