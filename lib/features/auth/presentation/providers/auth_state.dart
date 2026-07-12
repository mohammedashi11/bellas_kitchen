import '../../../../core/error/app_failure.dart';
import '../../../user/domain/entities/app_user.dart';

/// The customer auth flow state. Pure Dart (sealed for exhaustive matching).
sealed class AuthState {
  const AuthState();
}

/// A send/verify call is in flight.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No signed-in user.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// An OTP has been sent; awaiting the code. Holds the handle needed to verify.
class CodeSent extends AuthState {
  final String verificationId;
  final int? resendToken;
  final String phoneNumber;
  const CodeSent({
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });
}

/// A user is signed in.
class Authenticated extends AuthState {
  final AppUser user;
  const Authenticated(this.user);
}

/// The last operation failed. Carries the canonical [AppFailure] for display.
class AuthError extends AuthState {
  final AppFailure failure;
  const AuthError(this.failure);
}
