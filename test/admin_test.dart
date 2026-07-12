import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/auth/domain/entities/otp_verification.dart';
import 'package:bellas_kitchen/features/auth/domain/repositories/auth_repository.dart';
import 'package:bellas_kitchen/features/auth/presentation/providers/auth_providers.dart';
import 'package:bellas_kitchen/features/auth/presentation/providers/auth_state.dart';
import 'package:bellas_kitchen/features/user/data/models/app_user_model.dart';
import 'package:bellas_kitchen/features/user/domain/entities/app_user.dart';
import 'package:bellas_kitchen/features/user/domain/entities/user_role.dart';

/// Only `signInWithEmailPassword` is exercised here; the rest are stubs.
class FakeAuthRepository implements AuthRepository {
  final Result<AppUser> emailResult;
  FakeAuthRepository(this.emailResult);

  @override
  Future<Result<AppUser>> signInWithEmailPassword(
          String email, String password) async =>
      emailResult;

  @override
  AppUser? currentUser() => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signInAnonymously() => throw UnimplementedError();

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
}

AppUser _user({UserRole role = UserRole.customer}) => AppUser(
      uid: 'u1',
      phoneNumber: '',
      createdAt: DateTime.utc(2024, 1, 1),
      role: role,
    );

void main() {
  // ── Role parsing (defensive) ───────────────────────────────────────────────
  group('UserRole.fromStorage', () {
    test('absent (null) → customer', () {
      expect(UserRole.fromStorage(null), UserRole.customer);
    });
    test("exact 'admin' → admin", () {
      expect(UserRole.fromStorage('admin'), UserRole.admin);
    });
    test("'customer' → customer", () {
      expect(UserRole.fromStorage('customer'), UserRole.customer);
    });
    test('unknown value → customer (never accidental admin)', () {
      expect(UserRole.fromStorage('superuser'), UserRole.customer);
      expect(UserRole.fromStorage('Admin'), UserRole.customer); // case-sensitive
      expect(UserRole.fromStorage(''), UserRole.customer);
    });
  });

  group('AppUser.isAdmin', () {
    test('admin role → true', () {
      expect(_user(role: UserRole.admin).isAdmin, isTrue);
    });
    test('default/customer → false', () {
      expect(_user().isAdmin, isFalse);
    });
  });

  // ── Model read/write ───────────────────────────────────────────────────────
  group('AppUserModel role serialisation', () {
    test('fromMap with NO role field → customer', () {
      final model = AppUserModel.fromMap('u1', {'phoneNumber': '+15550123456'});
      expect(model.role, UserRole.customer);
      expect(model.isAdmin, isFalse);
    });

    test("fromMap with role 'admin' → admin", () {
      final model = AppUserModel.fromMap(
          'u1', {'phoneNumber': '+15550123456', 'role': 'admin'});
      expect(model.role, UserRole.admin);
      expect(model.isAdmin, isTrue);
    });

    test('toFirestore OMITS role for a customer', () {
      final model = AppUserModel(
        uid: 'u1',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      expect(model.toFirestore().containsKey('role'), isFalse);
    });

    test('toFirestore writes role for an admin (never downgraded)', () {
      final model = AppUserModel(
        uid: 'u1',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
        role: UserRole.admin,
      );
      expect(model.toFirestore()['role'], 'admin');
    });
  });

  // ── Admin sign-in gate (controller + mocked repo) ──────────────────────────
  group('AuthController.signInAsAdmin', () {
    ProviderContainer containerWith(Result<AppUser> emailResult) {
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(emailResult)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('admin credentials → Authenticated with isAdmin', () async {
      final container = containerWith(Success(_user(role: UserRole.admin)));
      await container
          .read(authControllerProvider.notifier)
          .signInAsAdmin('admin@bella.com', 'pw');

      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).user.isAdmin, isTrue);
    });

    test('non-admin (gate rejected) → AuthError(UnauthorizedFailure)', () async {
      // The repository enforces the gate: a non-admin is signed out and returns
      // UnauthorizedFailure. Here we simulate that contract.
      final container = containerWith(
        const Failure(UnauthorizedFailure("This account doesn't have admin access.")),
      );
      await container
          .read(authControllerProvider.notifier)
          .signInAsAdmin('user@bella.com', 'pw');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).failure, isA<UnauthorizedFailure>());
    });

    test('wrong credentials → AuthError(ValidationFailure)', () async {
      final container = containerWith(
        const Failure(ValidationFailure('Incorrect email or password.')),
      );
      await container
          .read(authControllerProvider.notifier)
          .signInAsAdmin('user@bella.com', 'bad');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).failure, isA<ValidationFailure>());
    });
  });
}
