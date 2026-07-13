import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/admin/presentation/screens/menu_item_form_screen.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/domain/menu_item_write_validator.dart';
import 'package:bellas_kitchen/features/menu/domain/repositories/menu_repository.dart';

MenuItem _item({
  String id = 'm1',
  String name = 'Classic Cheeseburger',
  double price = 12.50,
  String category = 'Burgers',
}) =>
    MenuItem(
      id: id,
      name: name,
      description: 'desc',
      price: price,
      imageUrl: '',
      category: category,
      createdAt: DateTime.utc(2024, 1, 1),
    );

/// Records write calls so the CRUD contract can be asserted without Firestore.
class RecordingMenuRepository implements MenuRepository {
  final added = <MenuItem>[];
  final updated = <MenuItem>[];
  final deleted = <String>[];
  final toggles = <(String, bool)>[];

  @override
  Future<Result<MenuItem>> addMenuItem(MenuItem item) async {
    final invalid = validateMenuItemWrite(item);
    if (invalid != null) return Failure(invalid);
    added.add(item);
    return Success(item);
  }

  @override
  Future<Result<void>> updateMenuItem(MenuItem item) async {
    final invalid = validateMenuItemWrite(item);
    if (invalid != null) return Failure(invalid);
    updated.add(item);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteMenuItem(String id) async {
    deleted.add(id);
    return const Success(null);
  }

  @override
  Future<Result<void>> setAvailability(String id, bool isAvailable) async {
    toggles.add((id, isAvailable));
    return const Success(null);
  }

  @override
  Stream<Result<List<MenuItem>>> watchAllMenuItems() =>
      Stream<Result<List<MenuItem>>>.empty();

  @override
  Future<Result<List<MenuItem>>> getMenuItems({String? category}) async =>
      const Success([]);

  @override
  Future<Result<MenuItem?>> getMenuItemById(String id) async =>
      const Success(null);
}

void main() {
  // ── Write-side validation guard (tech-debt #11) ────────────────────────────
  group('validateMenuItemWrite', () {
    test('valid item passes (null)', () {
      expect(validateMenuItemWrite(_item()), isNull);
    });

    test('empty / whitespace name → ValidationFailure', () {
      expect(validateMenuItemWrite(_item(name: '')), isA<ValidationFailure>());
      expect(
          validateMenuItemWrite(_item(name: '   ')), isA<ValidationFailure>());
    });

    test('price <= 0 → ValidationFailure', () {
      expect(validateMenuItemWrite(_item(price: 0)), isA<ValidationFailure>());
      expect(
          validateMenuItemWrite(_item(price: -5)), isA<ValidationFailure>());
    });

    test("'Other' (read-only fallback) is rejected on write", () {
      expect(validateMenuItemWrite(_item(category: 'Other')),
          isA<ValidationFailure>());
    });

    test("'All' (UI sentinel) and unknown categories are rejected", () {
      expect(validateMenuItemWrite(_item(category: 'All')),
          isA<ValidationFailure>());
      expect(validateMenuItemWrite(_item(category: 'Sushi')),
          isA<ValidationFailure>());
      expect(validateMenuItemWrite(_item(category: '')),
          isA<ValidationFailure>());
    });

    test('every storable category passes', () {
      for (final c in AppConstants.storableCategories) {
        expect(validateMenuItemWrite(_item(category: c)), isNull,
            reason: '$c should be storable');
      }
    });
  });

  // ── Image URL input (primary image path while Storage is gated off) ───────
  group('validateImageUrlInput', () {
    test('empty is allowed (neutral placeholder renders everywhere)', () {
      expect(validateImageUrlInput(''), isNull);
      expect(validateImageUrlInput('   '), isNull);
    });

    test('valid http(s) URLs pass', () {
      expect(validateImageUrlInput('https://example.com/burger.jpg'), isNull);
      expect(validateImageUrlInput('http://cdn.example.com/img?id=1'), isNull);
    });

    test('non-http(s) or malformed input → ValidationFailure', () {
      expect(validateImageUrlInput('not a url'), isA<ValidationFailure>());
      expect(validateImageUrlInput('ftp://example.com/a.jpg'),
          isA<ValidationFailure>());
      expect(validateImageUrlInput('example.com/a.jpg'),
          isA<ValidationFailure>());
      expect(validateImageUrlInput('https://'), isA<ValidationFailure>());
    });
  });

  test('storage upload is gated off on Spark', () {
    expect(AppConstants.storageUploadEnabled, isFalse);
  });

  // ── Form dropdown source ───────────────────────────────────────────────────
  test("menuFormCategoryOptions excludes 'Other' and 'All'", () {
    expect(menuFormCategoryOptions, AppConstants.storableCategories);
    expect(menuFormCategoryOptions.contains(AppConstants.defaultCategory),
        isFalse); // 'Other'
    expect(menuFormCategoryOptions.contains(AppConstants.categoryAll),
        isFalse); // 'All'
    expect(menuFormCategoryOptions, isNotEmpty);
  });

  // ── CRUD contract through a mock repository ────────────────────────────────
  group('menu CRUD via repository contract', () {
    test('add: valid item is written; invalid never reaches the store',
        () async {
      final repo = RecordingMenuRepository();

      final ok = await repo.addMenuItem(_item());
      expect(ok, isA<Success<MenuItem>>());
      expect(repo.added.length, 1);

      final bad = await repo.addMenuItem(_item(category: 'Other'));
      expect(bad, isA<Failure<MenuItem>>());
      expect((bad as Failure<MenuItem>).failure, isA<ValidationFailure>());
      expect(repo.added.length, 1); // unchanged — guard blocked the write
    });

    test('update: valid item updates; invalid is rejected', () async {
      final repo = RecordingMenuRepository();

      final ok = await repo.updateMenuItem(_item(name: 'Renamed'));
      expect(ok, isA<Success<void>>());
      expect(repo.updated.single.name, 'Renamed');

      final bad = await repo.updateMenuItem(_item(price: 0));
      expect(bad, isA<Failure<void>>());
      expect(repo.updated.length, 1);
    });

    test('delete and setAvailability pass through with the right args',
        () async {
      final repo = RecordingMenuRepository();

      await repo.deleteMenuItem('m9');
      expect(repo.deleted, ['m9']);

      await repo.setAvailability('m1', false);
      await repo.setAvailability('m2', true);
      expect(repo.toggles, [('m1', false), ('m2', true)]);
    });
  });
}
