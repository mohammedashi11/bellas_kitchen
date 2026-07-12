/// Canonical failure type for the whole app. Pure Dart — no Flutter/Firebase
/// imports. Carried by [Result]'s failure branch (see core/utils/result.dart).
///
/// Data/repository layers map low-level exceptions (FirebaseException,
/// TimeoutException, SocketException, …) into one of these subtypes so the
/// rest of the app can pattern-match on a stable, typed error surface.
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

/// The device/app could not reach the backend (offline, timeout, DNS, …).
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

/// The backend was reached but responded with an error (5xx, internal, …).
final class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}

/// A requested resource does not exist.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// The caller is not authenticated or lacks permission for the operation.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message);
}

/// Input failed validation before or after hitting the backend.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// Anything that doesn't map to a more specific failure.
final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
