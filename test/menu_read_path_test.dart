import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/menu/data/repositories/firestore_menu_repository.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';

/// The customer read path against a mocked Firestore source. The dev-only mock
/// fallback is GONE: Firestore is the single source of truth — empty is empty,
/// errors are failures, and only real docs come back.
void main() {
  Future<void> seed(
    FakeFirebaseFirestore firestore, {
    required String id,
    required String name,
    String category = 'Burgers',
    bool isAvailable = true,
    int minute = 0,
  }) {
    return firestore.collection(AppConstants.menuItemsCollection).doc(id).set({
      'name': name,
      'description': 'desc',
      'price': 9.99,
      'imageUrl': 'https://example.com/$id.jpg',
      'category': category,
      'isBestSeller': false,
      'isAvailable': isAvailable,
      'createdAt': DateTime.utc(2026, 1, 1, 12, minute),
    });
  }

  group('getMenuItems (no mock fallback)', () {
    test('empty collection → EMPTY list, not mock items', () async {
      final repo =
          FirestoreMenuRepository(firestore: FakeFirebaseFirestore());
      final result = await repo.getMenuItems();

      expect(result, isA<Success<List<MenuItem>>>());
      final items = (result as Success<List<MenuItem>>).data;
      expect(items, isEmpty);
    });

    test('returns the real seeded docs (admin-added item appears)', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, id: 'real1', name: 'My Real Admin Item');
      final repo = FirestoreMenuRepository(firestore: firestore);

      final result = await repo.getMenuItems();
      final items = (result as Success<List<MenuItem>>).data;

      expect(items.length, 1);
      expect(items.single.name, 'My Real Admin Item');
      expect(items.single.imageUrl, 'https://example.com/real1.jpg');
      // The old mock names must NOT appear.
      expect(items.any((i) => i.name == 'Classic Cheeseburger'), isFalse);
    });

    test('unavailable items are filtered out client-side', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, id: 'a', name: 'Visible', minute: 1);
      await seed(firestore,
          id: 'b', name: 'Hidden', isAvailable: false, minute: 2);
      final repo = FirestoreMenuRepository(firestore: firestore);

      final items =
          (await repo.getMenuItems() as Success<List<MenuItem>>).data;
      expect(items.map((i) => i.name), ['Visible']);
    });

    test('category filter works against real category fields', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore,
          id: 'a', name: 'Burger', category: 'Burgers', minute: 1);
      await seed(firestore,
          id: 'b', name: 'Pizza', category: 'Pizza', minute: 2);
      final repo = FirestoreMenuRepository(firestore: firestore);

      final pizza = (await repo.getMenuItems(category: 'Pizza')
              as Success<List<MenuItem>>)
          .data;
      expect(pizza.map((i) => i.name), ['Pizza']);

      final all = (await repo.getMenuItems(category: AppConstants.categoryAll)
              as Success<List<MenuItem>>)
          .data;
      expect(all.length, 2);
    });

    test('items come back ordered by createdAt ascending', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, id: 'later', name: 'Second', minute: 30);
      await seed(firestore, id: 'earlier', name: 'First', minute: 1);
      final repo = FirestoreMenuRepository(firestore: firestore);

      final items =
          (await repo.getMenuItems() as Success<List<MenuItem>>).data;
      expect(items.map((i) => i.name), ['First', 'Second']);
    });

    test('Firestore unavailable → NetworkFailure, NOT mock data', () async {
      // Construct with no Firestore instance (pre-init / unavailable).
      final repo = FirestoreMenuRepository(firestore: null);
      final result = await repo.getMenuItems();

      expect(result, isA<Failure<List<MenuItem>>>());
      expect((result as Failure<List<MenuItem>>).failure, isA<NetworkFailure>());
    });
  });

  group('getMenuItemById (no mock fallback)', () {
    test('missing doc → Success(null), not a mock item', () async {
      final repo =
          FirestoreMenuRepository(firestore: FakeFirebaseFirestore());
      final result = await repo.getMenuItemById('nope');

      expect(result, isA<Success<MenuItem?>>());
      expect((result as Success<MenuItem?>).data, isNull);
    });

    test('existing doc → the real item', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, id: 'x1', name: 'Real Item');
      final repo = FirestoreMenuRepository(firestore: firestore);

      final item =
          (await repo.getMenuItemById('x1') as Success<MenuItem?>).data;
      expect(item, isNotNull);
      expect(item!.name, 'Real Item');
    });

    test('Firestore unavailable → NetworkFailure', () async {
      final repo = FirestoreMenuRepository(firestore: null);
      final result = await repo.getMenuItemById('x1');
      expect(result, isA<Failure<MenuItem?>>());
      expect((result as Failure<MenuItem?>).failure, isA<NetworkFailure>());
    });
  });
}
