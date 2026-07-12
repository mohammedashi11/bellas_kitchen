import '../../../../core/utils/result.dart';
import '../../../user/domain/entities/app_user.dart';
import '../entities/otp_verification.dart';

/// Abstract auth contract — domain layer. Implementations live in data.
///
/// All fallible calls return [Result] carrying an `AppFailure` on the failure
/// branch (reusing the app-wide error types — no auth-specific error type).
abstract class AuthRepository {
  /// Starts phone verification for [phoneNumber] (E.164, e.g. +15550123456).
  /// On success returns the [OtpVerification] handle needed by [verifyOtp].
  /// Pass [resendToken] from a prior attempt to force a resend.
  Future<Result<OtpVerification>> sendOtp(String phoneNumber, {int? resendToken});

  /// Completes sign-in with the [smsCode] the user entered, using the
  /// [verificationId] from a prior [sendOtp]. Returns the signed-in [AppUser].
  Future<Result<AppUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  /// Signs in anonymously and ensures a `users/{uid}` profile exists. Used at
  /// checkout so an unauthenticated customer still gets a real Firebase uid
  /// (request.auth.uid) without going through the phone-login wall.
  Future<Result<AppUser>> signInAnonymously();

  /// Admin sign-in with email/password. On success, verifies the user's role is
  /// `admin` (from their `users/{uid}` doc); a non-admin is signed straight back
  /// out and an `UnauthorizedFailure` is returned — no non-admin admin session.
  Future<Result<AppUser>> signInWithEmailPassword(String email, String password);

  /// Signs the current user out.
  Future<Result<void>> signOut();

  /// The currently signed-in user, or null. Synchronous snapshot.
  AppUser? currentUser();

  /// Emits on sign-in / sign-out. Null means signed out.
  Stream<AppUser?> authStateChanges();
}
