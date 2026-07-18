import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/auth/domain/entities/otp_verification.dart';
import 'package:bellas_kitchen/features/auth/domain/repositories/auth_repository.dart';
import 'package:bellas_kitchen/features/auth/presentation/providers/auth_providers.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order.dart';
import 'package:bellas_kitchen/features/order/domain/entities/order_status.dart';
import 'package:bellas_kitchen/features/order/domain/entities/payment_method.dart';
import 'package:bellas_kitchen/features/order/presentation/order_display.dart';
import 'package:bellas_kitchen/features/order/presentation/providers/order_providers.dart';
import 'package:bellas_kitchen/features/order/presentation/screens/order_history_screen.dart';
import 'package:bellas_kitchen/features/profile/presentation/screens/profile_screen.dart';
import 'package:bellas_kitchen/features/user/domain/entities/app_user.dart';

Order _order({
  String id = 'abcd9021',
  OrderStatus status = OrderStatus.delivered,
  double total = 53.18,
}) =>
    Order(
      id: id,
      userId: 'u1',
      items: const [],
      subtotal: total,
      tax: 0,
      total: total,
      status: status,
      payment: PaymentMethod.card,
      deliveryAddress: 'x',
      createdAt: DateTime.utc(2023, 10, 12),
      updatedAt: DateTime.utc(2023, 10, 12),
    );

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    return const Success(null);
  }

  @override
  AppUser? currentUser() => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);

  @override
  Future<Result<AppUser>> signInAnonymously() => throw UnimplementedError();

  @override
  Future<Result<OtpVerification>> sendOtp(String phoneNumber,
          {int? resendToken}) =>
      throw UnimplementedError();

  @override
  Future<Result<AppUser>> verifyOtp(
          {required String verificationId, required String smsCode}) =>
      throw UnimplementedError();

  @override
  Future<Result<AppUser>> signInWithEmailPassword(
          String email, String password) =>
      throw UnimplementedError();
}

Widget _harness({
  required String initial,
  required List<Order> orders,
  AppUser? user,
  _FakeAuthRepository? auth,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/orders', builder: (_, _) => const OrderHistoryScreen()),
      GoRoute(
          path: '/order/:id',
          builder: (c, s) =>
              Scaffold(body: Text('TRACK ${s.pathParameters['id']}'))),
    ],
  );
  return ProviderScope(
    overrides: [
      userOrdersProvider.overrideWith((ref) => Stream.value(orders)),
      currentUserProvider.overrideWithValue(user),
      authRepositoryProvider.overrideWithValue(auth ?? _FakeAuthRepository()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('OrderHistoryScreen', () {
    testWidgets('renders the user\'s orders from the stream', (tester) async {
      await tester.pumpWidget(
          _harness(initial: '/orders', orders: [_order(id: 'abcd9021')]));
      await tester.pump();

      expect(find.text(orderNumber('abcd9021')), findsOneWidget); // #BK-9021
      expect(find.text('\$53.18'), findsOneWidget);
      expect(find.text('Oct 12, 2023'), findsOneWidget);
    });

    testWidgets('empty history → friendly empty state', (tester) async {
      await tester.pumpWidget(_harness(initial: '/orders', orders: const []));
      await tester.pump();
      expect(find.text('No orders yet'), findsOneWidget);
    });

    testWidgets('tapping an order navigates to /order/:id', (tester) async {
      await tester.pumpWidget(
          _harness(initial: '/orders', orders: [_order(id: 'zzz1')]));
      await tester.pump();

      await tester.tap(find.text(orderNumber('zzz1')));
      await tester.pumpAndSettle();
      expect(find.text('TRACK zzz1'), findsOneWidget);
    });
  });

  group('ProfileScreen', () {
    testWidgets('named user shows displayName + phone', (tester) async {
      final user = AppUser(
        uid: 'u1',
        phoneNumber: '+15550123456',
        displayName: 'Sarah Jenkins',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      await tester.pumpWidget(
          _harness(initial: '/profile', orders: const [], user: user));
      await tester.pump();

      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('+15550123456'), findsOneWidget);
    });

    testWidgets('anonymous / null user → Guest, never crashes', (tester) async {
      await tester.pumpWidget(
          _harness(initial: '/profile', orders: const [], user: null));
      await tester.pump();

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Sign in to save your history'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Log Out'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Log Out calls signOut and routes home for authenticated user', (tester) async {
      final auth = _FakeAuthRepository();
      final user = AppUser(
        uid: 'u1',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      await tester.pumpWidget(_harness(
          initial: '/profile', orders: const [], user: user, auth: auth));
      await tester.pump();

      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
