import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/utils/result.dart';

import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/domain/repositories/menu_repository.dart';
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

/// Menu repository fake for the REAL-CHAIN harness below.
class _FakeMenuRepo implements MenuRepository {
  /// How many times the menu was actually fetched — a search must filter the
  /// already-loaded list, never re-query the backend per keystroke.
  int fetchCalls = 0;

  @override
  Future<Result<List<MenuItem>>> getMenuItems({String? category}) async {
    fetchCalls++;
    final all = _testItems();
    final filtered = category == null || category == AppConstants.categoryAll
        ? all
        : all.where((i) => i.category == category).toList();
    return Success(filtered);
  }

  @override
  Future<Result<MenuItem?>> getMenuItemById(String id) async => Success(null);
  @override
  Stream<Result<List<MenuItem>>> watchAllMenuItems() =>
      Stream<Result<List<MenuItem>>>.empty();
  @override
  Future<Result<MenuItem>> addMenuItem(MenuItem item) async => Success(item);
  @override
  Future<Result<void>> updateMenuItem(MenuItem item) async =>
      const Success(null);
  @override
  Future<Result<void>> deleteMenuItem(String id) async => const Success(null);
  @override
  Future<Result<void>> setAvailability(String id, bool isAvailable) async =>
      const Success(null);
}

/// Harness that overrides only the REPOSITORY, so the real
/// `menuItemsProvider → GetMenuItems → filteredMenuItemsProvider` chain runs.
///
/// The `_harness()` above stubs `menuItemsProvider` itself, which means it
/// never exercises that chain — a break anywhere inside it would leave those
/// tests passing while the app failed on device. This closes that gap.
Widget _realChainHarness(_FakeMenuRepo repo) {
  return ProviderScope(
    overrides: [menuRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: HomeScreen()),
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

  // ── Real provider chain ────────────────────────────────────────────────────
  //
  // Everything above stubs `menuItemsProvider`. These drive the same UI through
  // the REAL menuItemsProvider + GetMenuItems, overriding only the repository,
  // so a break inside that chain is caught here instead of on a device.
  group('HomeScreen Search — real provider chain', () {
    testWidgets('typing filters the list through the real chain',
        (tester) async {
      useTallViewport(tester);
      final repo = _FakeMenuRepo();
      await tester.pumpWidget(_realChainHarness(repo));
      await tester.pumpAndSettle();

      // Unfiltered baseline.
      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text('Cheese Pizza'), findsOneWidget);
      expect(find.text('Spicy Chicken Burger'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'burger');
      await tester.pump();

      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text('Spicy Chicken Burger'), findsOneWidget);
      expect(find.text('Cheese Pizza'), findsNothing);
    });

    testWidgets('searching does NOT re-query the backend per keystroke',
        (tester) async {
      useTallViewport(tester);
      final repo = _FakeMenuRepo();
      await tester.pumpWidget(_realChainHarness(repo));
      await tester.pumpAndSettle();
      expect(repo.fetchCalls, 1);

      for (final q in ['b', 'bu', 'bur', 'burg']) {
        await tester.enterText(find.byType(TextField), q);
        await tester.pump();
      }

      // Filtering is client-side over the already-loaded list.
      expect(repo.fetchCalls, 1);
      expect(find.text('Cheese Pizza'), findsNothing);
    });

    testWidgets('description match works through the real chain',
        (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(_realChainHarness(_FakeMenuRepo()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cheesy');
      await tester.pump();

      expect(find.text('Cheese Pizza'), findsOneWidget);
      expect(find.text('Classic Burger'), findsNothing);
    });
  });

  // ── Single search entry point ──────────────────────────────────────────────
  testWidgets('the search field is the ONLY search affordance', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(_realChainHarness(_FakeMenuRepo()));
    await tester.pumpAndSettle();

    // The app bar used to carry a decorative magnifier with no tap handler,
    // which read as the way to search while doing nothing. The only
    // search_rounded icon left is the one INSIDE the search field's prefix.
    final searchIcons = find.byIcon(Icons.search_rounded);
    expect(searchIcons, findsOneWidget);
    expect(
      find.descendant(of: find.byType(TextField), matching: searchIcons),
      findsOneWidget,
      reason: 'the remaining magnifier must be the search field prefix',
    );
  });
}
