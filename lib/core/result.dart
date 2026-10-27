/// Represents either a successful value of type [T] or a failure of type [E].
///
/// Use [fold] to handle both cases without accessing a member that is only
/// available on one variant.
sealed class Result<T, E extends Exception> {
  const Result();

  /// Whether this result contains a [Success] value.
  bool get isSuccess => this is Success<T, E>;

  /// Whether this result contains a [Failure] error.
  bool get isFailure => this is Failure<T, E>;

  /// The successful value.
  ///
  /// Throws [StateError] when this result is a [Failure].
  T get value;

  /// The failure exception.
  ///
  /// Throws [StateError] when this result is a [Success].
  E get error;

  /// Calls [onSuccess] with the value or [onFailure] with the error.
  R fold<R>(R Function(T value) onSuccess, R Function(E error) onFailure) {
    switch (this) {
      case Success(value: final v):
        return onSuccess(v);
      case Failure(error: final e):
        return onFailure(e);
    }
  }
}

/// Successful variant of [Result], containing [value].
class Success<T, E extends Exception> extends Result<T, E> {
  @override
  final T value;
  const Success(this.value);

  @override
  E get error => throw StateError('Called get error on a Success result');
}

/// Failed variant of [Result], containing an [error].
class Failure<T, E extends Exception> extends Result<T, E> {
  @override
  final E error;
  const Failure(this.error);

  @override
  T get value => throw StateError('Called get value on a Failure result: $error');
}
