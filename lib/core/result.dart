sealed class Result<T, E extends Exception> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T get value;
  E get error;

  R fold<R>(R Function(T value) onSuccess, R Function(E error) onFailure) {
    switch (this) {
      case Success(value: final v):
        return onSuccess(v);
      case Failure(error: final e):
        return onFailure(e);
    }
  }
}

class Success<T, E extends Exception> extends Result<T, E> {
  @override
  final T value;
  const Success(this.value);

  @override
  E get error => throw StateError('Called get error on a Success result');
}

class Failure<T, E extends Exception> extends Result<T, E> {
  @override
  final E error;
  const Failure(this.error);

  @override
  T get value => throw StateError('Called get value on a Failure result: $error');
}
