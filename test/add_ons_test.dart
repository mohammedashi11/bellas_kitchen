import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/cart/domain/entities/cart_item.dart';
import 'package:bellas_kitchen/features/cart/presentation/providers/cart_providers.dart';
import 'package:bellas_kitchen/features/menu/data/models/menu_item_model.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/add_on.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/menu/domain/menu_item_write_validator.dart';
import 'package:bellas_kitchen/features/order/data/models/order_item_model.dart';
import 'package:bellas_kitchen/features/order/data/models/order_model.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_add_on.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';
import 'package:bellas_kitchen/features/order/domain/repositories/order_repository.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/usecases/place_order_usecase.dart';
import 'package:bellas_kitchen/features/auth/domain/entities/otp_verification.dart';
import 'package:bellas_kitchen/features/auth/domain/repositories/auth_repository.dart';
import 'package:bellas_kitchen/features/user/domain/entities/app_user.dart';

const _cheese = AddOn(id: 'cheese', name: 'Extra Cheese', price: 1.00);
const _bacon = AddOn(id: 'bacon', name: 'Bacon', price: 1.50);
const _noOnions = AddOn(id: 'no-onions', name: 'No Onions', price: 0.00);

MenuItem _burger({
  double price = 12.99,
  List<AddOn> addOns = const [_cheese, _bacon, _noOnions],
}) =>
    MenuItem(
      id: 'burger',
      name: 'Classic Burger',
      description: 'desc',
      price: price,
      imageUrl: '',
      category: 'Burgers',
      createdAt: DateTime.utc(2024, 1, 1),
      availableAddOns: addOns,
    );

/// Captures the order the use case builds.
class _CapturingOrderRepo implements OrderRepository {
  Order? placed;

  @override
  Future<Result<Order>> placeOrder(Order order) async {
    placed = order;
    return Success(order);
  }

  @override
  Stream<Result<Order>> watchOrder(String orderId) =>
      Stream<Result<Order>>.empty();
  @override
  Stream<Result<List<Order>>> watchUserOrders(String userId) =>
      Stream<Result<List<Order>>>.empty();
  @override
  Stream<Result<List<Order>>> watchAllOrders() =>
      Stream<Result<List<Order>>>.empty();
  @override
  Future<Result<void>> updateOrderStatus(String id, OrderStatus s) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> cancelOrder(String orderId) => throw UnimplementedError();
}

class _StubAuthRepo implements AuthRepository {
  @override
  Future<Result<AppUser>> signInAnonymously() async => Success(
      AppUser(uid: 'anon', phoneNumber: '', createdAt: DateTime.utc(2024)));
  @override
  Future<Result<AppUser>> signInWithEmailPassword(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<Result<OtpVerification>> sendOtp(String p, {int? resendToken}) =>
      throw UnimplementedError();
  @override
  Future<Result<AppUser>> verifyOtp(
          {required String verificationId, required String smsCode}) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> signOut() => throw UnimplementedError();
  @override
  AppUser? currentUser() => null;
  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);
}

void main() {
  // ── Pricing ────────────────────────────────────────────────────────────────
  group('add-on pricing', () {
    test('unit price = base + selected add-ons; line total × quantity', () {
      final line = CartItem(
        item: _burger(),
        quantity: 2,
        selectedAddOns: const [_cheese, _bacon],
      );
      expect(line.unitPrice, closeTo(15.49, 1e-9)); // 12.99 + 1.00 + 1.50
      expect(line.lineTotal, closeTo(30.98, 1e-9));
    });

    test('a free preference leaves the price unchanged', () {
      final plain = CartItem(item: _burger(), quantity: 1);
      final withFree = CartItem(
          item: _burger(), quantity: 1, selectedAddOns: const [_noOnions]);
      expect(withFree.unitPrice, closeTo(plain.unitPrice, 1e-9));
    });

    test('add-ons flow through subtotal, tax and total', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(cartProvider.notifier)
          .addItem(_burger(), selectedAddOns: const [_cheese]);

      const expectedSubtotal = 13.99; // 12.99 + 1.00
      expect(container.read(cartSubtotalProvider),
          closeTo(expectedSubtotal, 1e-9));
      expect(container.read(cartTaxProvider),
          closeTo(expectedSubtotal * AppConstants.taxRate, 1e-9));
      expect(
        container.read(cartTotalProvider),
        closeTo(
          expectedSubtotal +
              AppConstants.deliveryFee +
              expectedSubtotal * AppConstants.taxRate,
          1e-9,
        ),
      );
    });
  });

  // ── Cart line distinctness ─────────────────────────────────────────────────
  group('cart distinctness', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('same item + DIFFERENT add-ons = two separate lines', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger(), selectedAddOns: const [_cheese]);
      cart.addItem(_burger(), selectedAddOns: const [_bacon]);

      final lines = container.read(cartItemsProvider);
      expect(lines.length, 2);
      expect(lines.every((l) => l.quantity == 1), isTrue);
      // 13.99 + 14.49
      expect(container.read(cartSubtotalProvider), closeTo(28.48, 1e-9));
    });

    test('same item + SAME add-ons = one line, quantity 2', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger(), selectedAddOns: const [_cheese]);
      cart.addItem(_burger(), selectedAddOns: const [_cheese]);

      final lines = container.read(cartItemsProvider);
      expect(lines.length, 1);
      expect(lines.single.quantity, 2);
      expect(container.read(cartSubtotalProvider), closeTo(27.98, 1e-9));
    });

    test('selection ORDER does not split a line', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger(), selectedAddOns: const [_cheese, _bacon]);
      cart.addItem(_burger(), selectedAddOns: const [_bacon, _cheese]);

      expect(container.read(cartItemsProvider).length, 1);
      expect(container.read(cartItemsProvider).single.quantity, 2);
    });

    test('with add-ons vs. without are distinct lines', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger());
      cart.addItem(_burger(), selectedAddOns: const [_cheese]);
      expect(container.read(cartItemsProvider).length, 2);
    });

    test('an add-on-free line still keys to the bare menu item id', () {
      // Keeps every pre-add-on caller (remove/decrement by item id) working.
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger());
      expect(container.read(cartProvider).containsKey('burger'), isTrue);

      cart.decrementItem('burger');
      expect(container.read(cartProvider), isEmpty);
    });

    test('removing one line leaves the other intact', () {
      final cart = container.read(cartProvider.notifier);
      cart.addItem(_burger(), selectedAddOns: const [_cheese]);
      cart.addItem(_burger(), selectedAddOns: const [_bacon]);

      final cheeseKey = CartItem.keyFor('burger', const [_cheese]);
      cart.removeItem(cheeseKey);

      final remaining = container.read(cartItemsProvider);
      expect(remaining.length, 1);
      expect(remaining.single.selectedAddOns.single.id, 'bacon');
    });
  });

  // ── Frozen order snapshot ──────────────────────────────────────────────────
  group('OrderItem add-on snapshot', () {
    Future<Order> placeWith(List<AddOn> selected, {double basePrice = 12.99}) async {
      final repo = _CapturingOrderRepo();
      await PlaceOrderUseCase(repo, _StubAuthRepo())(
        cartItems: [
          CartItem(
            item: _burger(price: basePrice),
            quantity: 2,
            selectedAddOns: selected,
          ),
        ],
        deliveryAddress: '123 St',
        payment: PaymentMethod.cash,
        currentUser: null,
      );
      return repo.placed!;
    }

    test('captures each selected add-on name and price', () async {
      final order = await placeWith(const [_cheese, _bacon]);
      final item = order.items.single;

      expect(item.addOns.map((a) => a.name), ['Extra Cheese', 'Bacon']);
      expect(item.addOns.map((a) => a.price), [1.00, 1.50]);
      expect(item.unitPrice, closeTo(15.49, 1e-9));
      expect(item.lineTotal, closeTo(30.98, 1e-9));
      expect(order.subtotal, closeTo(30.98, 1e-9));
    });

    test('no selection → empty add-ons, base price unchanged', () async {
      final order = await placeWith(const []);
      expect(order.items.single.addOns, isEmpty);
      expect(order.items.single.lineTotal, closeTo(25.98, 1e-9));
    });

    test('snapshot stays FROZEN when the menu item later changes', () async {
      final order = await placeWith(const [_cheese]);
      final snapshot = order.items.single;

      // The admin later reprices the add-on and the item, and renames the
      // add-on. None of it may reach an order already placed.
      const repricedCheese =
          AddOn(id: 'cheese', name: 'Premium Cheese', price: 99.00);
      final repricedItem =
          _burger(price: 88.00, addOns: const [repricedCheese]);
      expect(repricedItem.price, 88.00);
      expect(repricedItem.availableAddOns.single.price, 99.00);

      expect(snapshot.price, closeTo(12.99, 1e-9));
      expect(snapshot.addOns.single.name, 'Extra Cheese');
      expect(snapshot.addOns.single.price, closeTo(1.00, 1e-9));
      expect(snapshot.lineTotal, closeTo(27.98, 1e-9));
    });
  });

  // ── Serialisation ──────────────────────────────────────────────────────────
  group('serialisation', () {
    test('MenuItemModel round-trips add-ons', () {
      final model = MenuItemModel.fromMap('m1', {
        AppConstants.fieldName: 'Burger',
        AppConstants.fieldPrice: 12.99,
        AppConstants.fieldCategory: 'Burgers',
        AppConstants.fieldAddOns: [
          {
            AppConstants.fieldId: 'cheese',
            AppConstants.fieldName: 'Extra Cheese',
            AppConstants.fieldPrice: 1.00,
          },
        ],
      });
      expect(model.availableAddOns.single.id, 'cheese');
      expect(model.availableAddOns.single.price, 1.00);

      final written = model.toFirestore()[AppConstants.fieldAddOns] as List;
      expect(written.single, {
        AppConstants.fieldId: 'cheese',
        AppConstants.fieldName: 'Extra Cheese',
        AppConstants.fieldPrice: 1.00,
      });
    });

    test('a menu doc with NO addOns field reads as an empty list', () {
      final model = MenuItemModel.fromMap('m1', {
        AppConstants.fieldName: 'Burger',
        AppConstants.fieldPrice: 12.99,
        AppConstants.fieldCategory: 'Burgers',
      });
      expect(model.availableAddOns, isEmpty);
    });

    test('an add-on entry without an id is dropped, not given a fake one', () {
      // Ids are cart line identity — inventing one could merge distinct lines.
      final model = MenuItemModel.fromMap('m1', {
        AppConstants.fieldName: 'Burger',
        AppConstants.fieldPrice: 12.99,
        AppConstants.fieldCategory: 'Burgers',
        AppConstants.fieldAddOns: [
          {AppConstants.fieldName: 'Orphan', AppConstants.fieldPrice: 1.0},
        ],
      });
      expect(model.availableAddOns, isEmpty);
    });

    test('OrderItemModel round-trips frozen add-ons', () {
      const model = OrderItemModel(
        menuItemId: 'burger',
        name: 'Classic Burger',
        price: 12.99,
        quantity: 2,
        addOns: [OrderAddOn(name: 'Extra Cheese', price: 1.00)],
      );
      final map = model.toMap();
      expect(map[AppConstants.fieldAddOns], [
        {AppConstants.fieldName: 'Extra Cheese', AppConstants.fieldPrice: 1.00},
      ]);

      final back = OrderItemModel.fromMap(map);
      expect(back.addOns.single.name, 'Extra Cheese');
      expect(back.lineTotal, closeTo(27.98, 1e-9));
    });

    test('OrderModel.toFirestore PERSISTS add-ons on the nested items', () {
      // Regression: toFirestore rebuilt each OrderItemModel to serialise it and
      // omitted `addOns`, so every selected add-on was dropped at write time —
      // charged for in subtotal/total, absent from the stored document. The
      // OrderItemModel.toMap tests above passed because they never went through
      // the ORDER-level write path.
      final order = OrderModel(
        id: 'o1',
        userId: 'u1',
        items: const [
          OrderItemModel(
            menuItemId: 'burger',
            name: 'Classic Burger',
            price: 12.99,
            quantity: 2,
            addOns: [OrderAddOn(name: 'Extra Cheese', price: 1.00)],
          ),
        ],
        subtotal: 27.98,
        deliveryFee: 2.50,
        tax: 2.52,
        total: 33.00,
        status: OrderStatus.pending,
        payment: PaymentMethod.card,
        deliveryAddress: '123 St',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final written = order.toFirestore();
      final writtenItem =
          (written[AppConstants.fieldItems] as List).single as Map;
      expect(writtenItem[AppConstants.fieldAddOns], isNotEmpty,
          reason: 'add-ons must survive the order write path');

      // And they survive a full round trip back into the domain.
      final back = OrderModel.fromMap('o1', {
        ...written,
        // serverTimestamp() sentinels don't read back; irrelevant here.
        AppConstants.fieldCreatedAt: null,
        AppConstants.fieldUpdatedAt: null,
      });
      expect(back.items.single.addOns.single.name, 'Extra Cheese');
      expect(back.items.single.addOns.single.price, closeTo(1.00, 1e-9));
      expect(back.items.single.lineTotal, closeTo(27.98, 1e-9));
    });

    test('an order doc with NO addOns field reads as an empty list', () {
      final back = OrderItemModel.fromMap({
        AppConstants.fieldMenuItemId: 'burger',
        AppConstants.fieldName: 'Classic Burger',
        AppConstants.fieldPrice: 12.99,
        AppConstants.fieldQuantity: 2,
      });
      expect(back.addOns, isEmpty);
      expect(back.lineTotal, closeTo(25.98, 1e-9));
    });
  });

  // ── Write-side validation ──────────────────────────────────────────────────
  group('add-on write validation', () {
    test('valid add-ons pass, including a zero-priced preference', () {
      expect(validateMenuItemWrite(_burger()), isNull);
    });

    test('blank add-on name is rejected', () {
      final item = _burger(
          addOns: const [AddOn(id: 'a', name: '   ', price: 1.0)]);
      expect(validateMenuItemWrite(item), isA<ValidationFailure>());
    });

    test('negative add-on price is rejected', () {
      final item =
          _burger(addOns: const [AddOn(id: 'a', name: 'Discount', price: -1)]);
      expect(validateMenuItemWrite(item), isA<ValidationFailure>());
    });

    test('duplicate add-on ids are rejected', () {
      final item = _burger(addOns: const [
        AddOn(id: 'dup', name: 'One', price: 1.0),
        AddOn(id: 'dup', name: 'Two', price: 2.0),
      ]);
      expect(validateMenuItemWrite(item), isA<ValidationFailure>());
    });

    test('an item with no add-ons is still valid', () {
      expect(validateMenuItemWrite(_burger(addOns: const [])), isNull);
    });
  });
}
