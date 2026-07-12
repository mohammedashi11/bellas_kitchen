import '../../../core/error/app_failure.dart';

/// Maps a Firebase Auth error `code` to the app's canonical [AppFailure].
///
/// Pure Dart (no firebase_auth import) so it is trivially unit-testable. The
/// data-layer repository calls this from its `catch` blocks.
AppFailure authFailureForCode(String code, {String? message}) {
  final msg = message?.trim().isNotEmpty == true
      ? message!.trim()
      : _friendlyMessage(code);

  switch (code) {
    // Bad user input (wrong/expired code, malformed number, stale session,
    // wrong email/password credentials).
    case 'invalid-verification-code':
    case 'invalid-verification-id':
    case 'invalid-phone-number':
    case 'missing-verification-code':
    case 'session-expired':
    case 'code-expired':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-email':
    case 'user-not-found':
      return ValidationFailure(msg);

    // Connectivity.
    case 'network-request-failed':
      return NetworkFailure(msg);

    // Server-side rate limiting / quota.
    case 'too-many-requests':
    case 'quota-exceeded':
      return ServerFailure(msg);

    // Permission / account state.
    case 'user-disabled':
    case 'operation-not-allowed':
      return UnauthorizedFailure(msg);

    default:
      return UnknownFailure(msg);
  }
}

String _friendlyMessage(String code) {
  switch (code) {
    case 'invalid-verification-code':
    case 'missing-verification-code':
      return 'That code is incorrect. Please check and try again.';
    case 'wrong-password':
    case 'invalid-credential':
    case 'user-not-found':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'session-expired':
    case 'code-expired':
      return 'This code has expired. Request a new one.';
    case 'invalid-phone-number':
      return 'That phone number looks invalid.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
    case 'quota-exceeded':
      return 'Too many attempts. Please wait a bit and try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'operation-not-allowed':
      return 'Phone sign-in is not enabled.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
