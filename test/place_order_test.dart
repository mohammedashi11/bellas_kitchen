import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/constants/app_constants.dart';
import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/auth/domain/entities/otp_verification.dart';
import 'package:bellas_kitchen/features/auth/domain/repositories/auth_repository.dart';
import 'package:bellas_kitchen/features/cart/domain/entities/cart_item.dart';
import 'package:bellas_kitchen/features/menu/domain/entities/menu_item.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';
import 'package:bellas_kitchen/features/order/domain/repositories/order_repository.dart';
import 'package:bellas_kitchen/features/order/domain/usecases/place_order_usecase.dart';
import 'package:bellas_kitchen/features/user/domain/entities/app_user.dart';

/// Records what the use case builds and echoes it back as success.
class FakeOrderRepository implements OrderRepository {
  Order? placedOrder;
  int placeCalls = 0;

  @override
  Future<Result<Order>> placeOrder(Order order) async {
    placeCalls++;
    placedOrder = order;
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
  Future<Result<void>> updateOrderStatus(
          String orderId, OrderStatus newStatus) =>
      throw UnimplementedError();
}

/// Only `signInAnonymously` is exercised by PlaceOrderUseCase; the rest are
/// unused stubs.
class FakeAuthRepository implements AuthRepository {
  Result<AppUser> anonResult;
  int anonCalls = 0;

  FakeAuthRepository({Result<AppUser>? anonResult})
      : anonResult = anonResult ??
            Success(AppUser(
              uid: 'anon-default',
              phoneNumber: '',
              createdAt: DateTime.utc(2024, 1, 1),
            ));

  @override
  Future<Result<AppUser>> signInAnonymously() async {
    anonCalls++;
    return anonResult;
  }

  @override
  Future<Result<AppUser>> signInWithEmailPassword(
          String email, String password) =>
      throw UnimplementedError();

  @override
  Future<Result<OtpVerification>> sendOtp(String phoneNumber,
          {int? resendToken}) =>
      throw UnimplementedError();

  @override
  Future<Result<AppUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> signOut() => throw UnimplementedError();

  @override
  AppUser? currentUser() => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);
}

MenuItem _menuItem(String id, String name, double price) => MenuItem(
      id: id,
      name: name,
      description: 'desc',
      price: price,
      imageUrl: '',
      category: 'Burgers',
      createdAt: DateTime.utc(2024, 1, 1),
    );

CartItem _line(String id, String name, double price, int qty) =>
    CartItem(item: _menuItem(id, name, price), quantity: qty);

void main() {
  group('PlaceOrderUseCase', () {
    test('empty cart → ValidationFailure; neither repo is called', () async {
      final orderRepo = FakeOrderRepository();
      final authRepo = FakeAuthRepository();
      final result = await PlaceOrderUseCase(orderRepo, authRepo)(
        cartItems: const [],
        deliveryAddress: '123 St',
        payment: PaymentMethod.cash,
        currentUser: null,
      );
      expect(result, isA<Failure<Order>>());
      expect((result as Failure<Order>).failure, isA<ValidationFailure>());
      expect(orderRepo.placeCalls, 0);
      expect(authRepo.anonCalls, 0);
    });

    test('freezes cart items into OrderItem snapshots', () async {
      final orderRepo = FakeOrderRepository();
      await PlaceOrderUseCase(orderRepo, FakeAuthRepository())(
        cartItems: [
          _line('1', 'Burger', 12.99, 2),
          _line('2', 'Pizza', 15.50, 1),
        ],
        deliveryAddress: '123 St',
        payment: PaymentMethod.card,
        currentUser: null,
      );

      final order = orderRepo.placedOrder!;
      expect(order.items.length, 2);
      expect(order.items[0].menuItemId, '1');
      expect(order.items[0].name, 'Burger');
      expect(order.items[0].price, closeTo(12.99, 1e-9));
      expect(order.items[0].quantity, 2);
      expect(order.items[0].lineTotal, closeTo(25.98, 1e-9));
      expect(order.status, OrderStatus.pending);
      expect(order.payment, PaymentMethod.card);
      expect(order.deliveryAddress, '123 St');
    });

    test('snapshot price is frozen, independent of later menu prices', () async {
      final orderRepo = FakeOrderRepository();
      await PlaceOrderUseCase(orderRepo, FakeAuthRepository())(
        cartItems: [_line('1', 'Burger', 10.00, 1)],
        deliveryAddress: 'x',
        payment: PaymentMethod.cash,
        currentUser: null,
      );
      expect(orderRepo.placedOrder!.items[0].price, 10.00);

      // A new price for the same menu id must NOT retroactively change the
      // already-placed order's frozen line price.
      final repriced = _menuItem('1', 'Burger', 99.00);
      expect(repriced.price, 99.00);
      expect(orderRepo.placedOrder!.items[0].price, 10.00);
    });

    test('total = subtotal + deliveryFee + tax', () async {
      final orderRepo = FakeOrderRepository();
      await PlaceOrderUseCase(orderRepo, FakeAuthRepository())(
        cartItems: [
          _line('1', 'B', 12.99, 1),
          _line('2', 'P', 15.50, 2),
        ],
        deliveryAddress: 'x',
        payment: PaymentMethod.cash,
        currentUser: null,
      );

      final order = orderRepo.placedOrder!;
      const subtotal = 12.99 + 15.50 * 2; // 43.99
      expect(order.subtotal, closeTo(subtotal, 1e-9));
      expect(order.deliveryFee, AppConstants.deliveryFee);
      expect(order.tax, closeTo(subtotal * AppConstants.taxRate, 1e-9));
      expect(
        order.total,
        closeTo(
          subtotal + AppConstants.deliveryFee + subtotal * AppConstants.taxRate,
          1e-9,
        ),
      );
    });

    test('userId: authenticated user → real uid, no anonymous sign-in',
        () async {
      final orderRepo = FakeOrderRepository();
      final authRepo = FakeAuthRepository();
      final user = AppUser(
        uid: 'firebase-uid-1',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      await PlaceOrderUseCase(orderRepo, authRepo)(
        cartItems: [_line('1', 'B', 5, 1)],
        deliveryAddress: 'x',
        payment: PaymentMethod.cash,
        currentUser: user,
      );
      expect(orderRepo.placedOrder!.userId, 'firebase-uid-1');
      expect(authRepo.anonCalls, 0);
    });

    test('userId: unauthenticated → anonymous uid via signInAnonymously',
        () async {
      final orderRepo = FakeOrderRepository();
      final authRepo = FakeAuthRepository(
        anonResult: Success(AppUser(
          uid: 'anon-xyz',
          phoneNumber: '',
          createdAt: DateTime.utc(2024, 1, 1),
        )),
      );
      await PlaceOrderUseCase(orderRepo, authRepo)(
        cartItems: [_line('1', 'B', 5, 1)],
        deliveryAddress: 'x',
        payment: PaymentMethod.cash,
        currentUser: null,
      );
      expect(authRepo.anonCalls, 1);
      expect(orderRepo.placedOrder!.userId, 'anon-xyz');
    });

    test('anonymous sign-in failure → order not placed, failure propagated',
        () async {
      final orderRepo = FakeOrderRepository();
      final authRepo = FakeAuthRepository(
        anonResult: const Failure(NetworkFailure('offline')),
      );
      final result = await PlaceOrderUseCase(orderRepo, authRepo)(
        cartItems: [_line('1', 'B', 5, 1)],
        deliveryAddress: 'x',
        payment: PaymentMethod.cash,
        currentUser: null,
      );
      expect(result, isA<Failure<Order>>());
      expect((result as Failure<Order>).failure, isA<NetworkFailure>());
      expect(orderRepo.placeCalls, 0);
    });
  });
}
