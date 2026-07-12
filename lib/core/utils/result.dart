// Lightweight Result type for Clean Architecture repository returns.
// Avoids adding dartz as a heavy dependency.
import '../error/app_failure.dart';

sealed class Result<S> {
  const Result();
}

final class Success<S> extends Result<S> {
  final S data;
  const Success(this.data);
}

final class Failure<S> extends Result<S> {
  final AppFailure failure;
  const Failure(this.failure);
}

extension ResultExtensions<S> on Result<S> {
  bool get isSuccess => this is Success<S>;
  bool get isFailure => this is Failure<S>;

  S? get dataOrNull => switch (this) {
        Success<S> s => s.data,
        Failure<S> _ => null,
      };

  AppFailure? get errorOrNull => switch (this) {
        Success<S> _ => null,
        Failure<S> f => f.failure,
      };

  T fold<T>({
    required T Function(S data) onSuccess,
    required T Function(AppFailure failure) onFailure,
  }) =>
      switch (this) {
        Success<S> s => onSuccess(s.data),
        Failure<S> f => onFailure(f.failure),
      };
}
