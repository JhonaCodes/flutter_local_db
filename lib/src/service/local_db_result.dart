/// Because help to use [when] and [map] methods.
/// Represents a result that can be either successful (Ok) or an error (Err)
///
/// Example:
/// ```dart
/// LocalDbResult<String, Exception> getUser(int id) {
///   try {
///     final user = database.getUser(id);
///     return Ok(user);
///   } catch (e) {
///     return Err(Exception('User not found'));
///   }
/// }
///
/// // Usage:
/// final result = getUser(1);
/// final username = result.when(
///   ok: (user) => user.name,
///   err: (e) => 'Unknown user'
/// );
/// ```
abstract class LocalDbResult<T, E> {
  const LocalDbResult();

  /// Pattern matches on the result to handle both success and error cases
  R when<R>({required R Function(T) ok, required R Function(E) err});

  /// Transforms the success value if present
  LocalDbResult<R, E> map<R>(R Function(T value) transform);

  /// Chains operations that might fail
  LocalDbResult<R, E> flatMap<R>(
    LocalDbResult<R, E> Function(T value) transform,
  );

  /// Safely attempts to get the success value
  R whenData<R>(R Function(T) ok) {
    return this.when(
      ok: ok,
      err: (error) =>
          throw StateError('Cannot access data on Err value: $error'),
    );
  }

  /// Safely handles the error if present
  R? whenError<R>(R Function(E) err) {
    return this.when(ok: (_) => null, err: err);
  }

  /// Returns true if this is a success result
  bool get isOk => this.when(ok: (_) => true, err: (_) => false);

  /// Returns true if this is an error result
  bool get isErr => !isOk;

  /// Gets the success value or throws if this is an error
  T get data => this.whenData((data) => data);

  /// Gets the error value if present, null otherwise
  E? get errorOrNull => this.whenError((error) => error);

  @override
  String toString() =>
      this.when(ok: (data) => 'Ok($data)', err: (error) => 'Err($error)');

  @override
  bool operator ==(Object other) {
    return this.when(
      ok: (data) => other is Ok<T, E> && other.data == data,
      err: (error) => other is Err<T, E> && other.error == error,
    );
  }

  @override
  int get hashCode =>
      this.when(ok: (data) => data.hashCode, err: (error) => error.hashCode);
}

/// Represents a successful result
class Ok<T, E> extends LocalDbResult<T, E> {
  @override
  final T data;

  const Ok(this.data);

  @override
  R when<R>({required R Function(T) ok, required R Function(E) err}) {
    return ok(data);
  }

  @override
  LocalDbResult<R, E> map<R>(R Function(T value) transform) {
    return Ok(transform(data));
  }

  @override
  LocalDbResult<R, E> flatMap<R>(
    LocalDbResult<R, E> Function(T value) transform,
  ) {
    return transform(data);
  }
}

/// Represents an error result
class Err<T, E> extends LocalDbResult<T, E> {
  final E error;

  const Err(this.error);

  @override
  R when<R>({required R Function(T) ok, required R Function(E) err}) {
    return err(error);
  }

  @override
  LocalDbResult<R, E> map<R>(R Function(T value) transform) {
    return Err(error);
  }

  @override
  LocalDbResult<R, E> flatMap<R>(
    LocalDbResult<R, E> Function(T value) transform,
  ) {
    return Err(error);
  }
}

/// Extension methods for LocalDbResult
extension ResultExtensions<T, E> on LocalDbResult<T, E> {
  /// Transforms the error value if present
  LocalDbResult<T, F> mapError<F>(F Function(E error) transform) {
    return when(
      ok: (value) => Ok(value),
      err: (error) => Err(transform(error)),
    );
  }

  /// Attempts to recover from an error
  LocalDbResult<T, E> recover(LocalDbResult<T, E> Function(E error) transform) {
    return when(ok: (value) => Ok(value), err: transform);
  }

  /// Gets the success value or a default from the error
  T getOrElse(T Function(E error) orElse) {
    return when(ok: (value) => value, err: orElse);
  }

  /// Gets the success value or a default value
  T getOrDefault(T defaultValue) {
    return when(ok: (value) => value, err: (_) => defaultValue);
  }
}

/// Extension methods for [Future LocalDbResult]
extension FutureResultExtensions<T, E> on Future<LocalDbResult<T, E>> {
  /// Maps the success value of a [Future LocalDbResult]
  Future<LocalDbResult<R, E>> map<R>(R Function(T value) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// Chains async operations that might fail
  Future<LocalDbResult<R, E>> flatMap<R>(
    Future<LocalDbResult<R, E>> Function(T value) transform,
  ) async {
    final result = await this;
    return result.when(ok: transform, err: (error) => Err(error));
  }
}
