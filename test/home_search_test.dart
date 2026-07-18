import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';

import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/presentation/providers/menu_providers.dart';
import 'package:bellas_kitchen/features/menu/presentation/screens/home_screen.dart';

// Fake FutureProvider value for the repository fetch
List<MenuItem> _testItems() => [
      MenuItem(
        id: '1',
        name: 'Classic Burger',
        description: 'Juicy beef patty',
        price: 10.99,
        imageUrl: '',
        category: 'Burgers',
        createdAt: DateTime.now(),
      ),
      MenuItem(
        id: '2',
        name: 'Cheese Pizza',
        description: 'Cheesy goodness',
        price: 12.99,
        imageUrl: '',
        category: 'Pizza',
        createdAt: DateTime.now(),
      ),
      MenuItem(
        id: '3',
        name: 'Spicy Chicken Burger',
        description: 'Hot and spicy',
        price: 11.99,
        imageUrl: '',
        category: 'Burgers',
        createdAt: DateTime.now(),
      ),
    ];

Widget _harness() {
  return ProviderScope(
    overrides: [
      menuItemsProvider.overrideWith((ref, cat) async {
            final all = _testItems();
            if (cat == AppConstants.categoryAll || cat == null) return all;
            return all.where((i) => i.category == cat).toList();
          }),
    ],
    child: const MaterialApp(
      home: HomeScreen(),
    ),
  );
}

/// Tall viewport so every seeded card is built.
///
/// The menu is a lazy `ListView.builder` and a card is ~300px tall (16:9 image
/// + text), so the default 800x600 test surface only ever builds the FIRST
/// card — asserting on an unfiltered list would fail for off-screen items.
/// Same approach as order_tracking_test.dart.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('HomeScreen Search', () {
    testWidgets('search filters by name case-insensitively', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text('Cheese Pizza'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'BuRgEr');
      await tester.pump();

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text('Spicy Chicken Burger'), findsOneWidget);
      expect(find.text('Cheese Pizza'), findsNothing);
    });

    testWidgets('search filters by description', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cheesy');
      await tester.pump();

      expect(find.text('Cheese Pizza'), findsOneWidget);
      expect(find.text('Classic Burger'), findsNothing);
    });

    testWidgets('search empty state displays correctly', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not_found_item');
      await tester.pump();

      expect(find.text('No items match your search'), findsOneWidget);
      expect(find.text('Classic Burger'), findsNothing);
    });

    testWidgets('clearing search restores the list', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'pizza');
      await tester.pump();
      expect(find.text('Classic Burger'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Classic Burger'), findsOneWidget);
    });
  });
}
