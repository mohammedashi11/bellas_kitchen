import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/core/error/app_failure.dart';
import 'package:bellas_kitchen/core/utils/result.dart';
import 'package:bellas_kitchen/features/auth/data/auth_error_mapper.dart';
import 'package:bellas_kitchen/features/auth/domain/entities/otp_verification.dart';
import 'package:bellas_kitchen/features/auth/domain/repositories/auth_repository.dart';
import 'package:bellas_kitchen/features/auth/domain/validators/phone_validator.dart';
import 'package:bellas_kitchen/features/auth/presentation/providers/auth_providers.dart';
import 'package:bellas_kitchen/features/auth/presentation/providers/auth_state.dart';
import 'package:bellas_kitchen/features/user/domain/entities/app_user.dart';

/// Controllable fake so transitions can be exercised without live Firebase.
class FakeAuthRepository implements AuthRepository {
  Result<OtpVerification> sendResult;
  Result<AppUser> verifyResult;
  AppUser? current;
  int sendOtpCalls = 0;
  int verifyOtpCalls = 0;
  final _controller = StreamController<AppUser?>.broadcast();

  FakeAuthRepository({
    this.sendResult = const Success(OtpVerification(verificationId: 'vid')),
    Result<AppUser>? verifyResult,
    this.current,
  }) : verifyResult = verifyResult ??
            Success(AppUser(
              uid: 'u1',
              phoneNumber: '+15550123456',
              createdAt: DateTime.utc(2024, 1, 1),
            ));

  @override
  Future<Result<OtpVerification>> sendOtp(String phoneNumber,
      {int? resendToken}) async {
    sendOtpCalls++;
    return sendResult;
  }

  @override
  Future<Result<AppUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    verifyOtpCalls++;
    return verifyResult;
  }

  @override
  Future<Result<AppUser>> signInAnonymously() async {
    final user = AppUser(
      uid: 'anon-1',
      phoneNumber: '',
      createdAt: DateTime.utc(2024, 1, 1),
    );
    current = user;
    _controller.add(user);
    return Success(user);
  }

  @override
  Future<Result<AppUser>> signInWithEmailPassword(
          String email, String password) async =>
      const Failure(UnauthorizedFailure('Not an admin.'));

  @override
  Future<Result<void>> signOut() async {
    current = null;
    _controller.add(null);
    return const Success(null);
  }

  @override
  AppUser? currentUser() => current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;
}

ProviderContainer _containerWith(FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // ── Error mapping ──────────────────────────────────────────────────────────
  group('authFailureForCode', () {
    test('invalid / expired code → ValidationFailure', () {
      expect(authFailureForCode('invalid-verification-code'),
          isA<ValidationFailure>());
      expect(authFailureForCode('session-expired'), isA<ValidationFailure>());
      expect(authFailureForCode('invalid-phone-number'),
          isA<ValidationFailure>());
    });
    test('network-request-failed → NetworkFailure', () {
      expect(
          authFailureForCode('network-request-failed'), isA<NetworkFailure>());
    });
    test('rate limiting → ServerFailure', () {
      expect(authFailureForCode('too-many-requests'), isA<ServerFailure>());
      expect(authFailureForCode('quota-exceeded'), isA<ServerFailure>());
    });
    test('account state → UnauthorizedFailure', () {
      expect(authFailureForCode('user-disabled'), isA<UnauthorizedFailure>());
    });
    test('unknown code → UnknownFailure', () {
      expect(authFailureForCode('something-weird'), isA<UnknownFailure>());
    });
    test('uses the provided message when present', () {
      expect(authFailureForCode('user-disabled', message: 'Blocked.').message,
          'Blocked.');
    });
  });

  // ── Input validation ───────────────────────────────────────────────────────
  group('validatePhone', () {
    test('empty → ValidationFailure', () {
      expect(validatePhone(''), isA<ValidationFailure>());
      expect(validatePhone('   '), isA<ValidationFailure>());
    });
    test('too short → ValidationFailure', () {
      expect(validatePhone('12345'), isA<ValidationFailure>());
    });
    test('plausible number → null (accepted)', () {
      expect(validatePhone('5550123456'), isNull);
      expect(validatePhone('(555) 012-3456'), isNull);
    });
    test('toE164 strips formatting and prefixes the dial code', () {
      expect(toE164(dialCode: '+1', raw: '(555) 012-3456'), '+15550123456');
    });
  });

  // ── Controller transitions ─────────────────────────────────────────────────
  group('AuthController transitions', () {
    test('starts Unauthenticated when no current user', () {
      final container = _containerWith(FakeAuthRepository());
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });

    test('sendOtp: unauthenticated → loading → codeSent', () async {
      final repo = FakeAuthRepository(
        sendResult: const Success(
            OtpVerification(verificationId: 'vid-123', resendToken: 7)),
      );
      final container = _containerWith(repo);
      final notifier = container.read(authControllerProvider.notifier);

      final future =
          notifier.sendOtp(dialCode: '+1', rawPhone: '5550123456');
      expect(container.read(authControllerProvider), isA<AuthLoading>());

      await future;
      final state = container.read(authControllerProvider);
      expect(state, isA<CodeSent>());
      expect((state as CodeSent).verificationId, 'vid-123');
      expect(state.phoneNumber, '+15550123456');
      expect(repo.sendOtpCalls, 1);
    });

    test('sendOtp with invalid input → AuthError, repo not called', () async {
      final repo = FakeAuthRepository();
      final container = _containerWith(repo);
      final notifier = container.read(authControllerProvider.notifier);

      await notifier.sendOtp(dialCode: '+1', rawPhone: '');
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).failure, isA<ValidationFailure>());
      expect(repo.sendOtpCalls, 0);
    });

    test('verify: codeSent → authenticated', () async {
      final user = AppUser(
        uid: 'user-9',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final repo = FakeAuthRepository(verifyResult: Success(user));
      final container = _containerWith(repo);
      final notifier = container.read(authControllerProvider.notifier);

      await notifier.sendOtp(dialCode: '+1', rawPhone: '5550123456');
      await notifier.verify('123456');

      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).user.uid, 'user-9');
      expect(repo.verifyOtpCalls, 1);
    });

    test('verify with wrong code → AuthError(ValidationFailure)', () async {
      final repo = FakeAuthRepository(
        verifyResult: const Failure(ValidationFailure('That code is incorrect.')),
      );
      final container = _containerWith(repo);
      final notifier = container.read(authControllerProvider.notifier);

      await notifier.sendOtp(dialCode: '+1', rawPhone: '5550123456');
      await notifier.verify('000000');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).failure, isA<ValidationFailure>());
    });

    test('verify before any code requested → AuthError', () async {
      final container = _containerWith(FakeAuthRepository());
      final notifier = container.read(authControllerProvider.notifier);

      await notifier.verify('123456');
      expect(container.read(authControllerProvider), isA<AuthError>());
    });

    test('signOut returns to Unauthenticated', () async {
      final user = AppUser(
        uid: 'u1',
        phoneNumber: '+15550123456',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final repo = FakeAuthRepository(verifyResult: Success(user));
      final container = _containerWith(repo);
      final notifier = container.read(authControllerProvider.notifier);

      await notifier.sendOtp(dialCode: '+1', rawPhone: '5550123456');
      await notifier.verify('123456');
      expect(container.read(authControllerProvider), isA<Authenticated>());

      await notifier.signOut();
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
    });
  });
}
