// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              RESULT MODEL                                    ║
// ║                        Type-Safe Result Handling                            ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: local_db_result.dart                                                ║
// ║  Purpose: Rust-style Result type for type-safe error handling               ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides a Rust-style Result<T, E> type for type-safe error handling.    ║
// ║    Eliminates null pointer exceptions and forces explicit error handling    ║
// ║    throughout the entire library. Includes convenient helper methods.       ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Type-safe error handling                                                ║
// ║    • Pattern matching with when()                                            ║
// ║    • Convenient helper methods                                               ║
// ║    • No null pointer exceptions                                              ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// A type-safe result type inspired by Rust's ```dart Result<T, E> ```
///
/// This sealed class represents either a successful result ([Ok]) containing a value of type [T],
/// or a failure ([Err]) containing an error of type [E].
///
/// Example:
/// ```dart
/// LocalDbResult<String, Error> result = someOperation();
/// result.when(
///   ok: (value) => print('Success: $value'),
///   err: (error) => print('Error: $error'),
/// );
/// ```
sealed class LocalDbResult<T, E> {
  const LocalDbResult();

  /// Pattern matching method for handling both success and error cases
  ///
  /// This method forces you to handle both cases explicitly, preventing
  /// unhandled errors and making your code more robust.
  ///
  /// Example:
  /// ```dart
  /// final message = result.when(
  ///   ok: (data) => 'Got data: $data',
  ///   err: (error) => 'Failed: $error',
  /// );
  /// ```
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  });

  /// Returns true if this is a successful result
  bool get isOk => this is Ok<T, E>;

  /// Returns true if this is an error result
  bool get isErr => this is Err<T, E>;

  /// Returns the success value if present, null otherwise
  ///
  /// Use with caution - prefer [when] for type-safe handling
  T? get okOrNull => isOk ? (this as Ok<T, E>).value : null;

  /// Returns the error if present, null otherwise
  ///
  /// Use with caution - prefer [when] for type-safe handling
  E? get errOrNull => isErr ? (this as Err<T, E>).error : null;

  /// Returns the success value or throws the error
  ///
  /// Use with caution - prefer [when] for explicit error handling
  T unwrap() {
    return when(
      ok: (value) => value,
      err: (error) => throw Exception('Unwrap called on error result: $error'),
    );
  }

  /// Returns the success value or the provided default
  ///
  /// Example:
  /// ```dart
  /// final data = result.unwrapOr('default value');
  /// ```
  T unwrapOr(T defaultValue) {
    return when(ok: (value) => value, err: (_) => defaultValue);
  }

  /// Maps the success value to a new type
  ///
  /// Example:
  /// ```dart
  /// LocalDbResult<int, Error> numberResult = Ok(42);
  /// LocalDbResult<String, Error> stringResult = numberResult.map((n) => n.toString());
  /// ```
  LocalDbResult<R, E> map<R>(R Function(T value) mapper) {
    return when(ok: (value) => Ok(mapper(value)), err: (error) => Err(error));
  }

  /// Maps the error to a new type
  ///
  /// Example:
  /// ```dart
  /// result.mapErr((error) => 'Mapped: $error');
  /// ```
  LocalDbResult<T, R> mapErr<R>(R Function(E error) mapper) {
    return when(ok: (value) => Ok(value), err: (error) => Err(mapper(error)));
  }
}

/// Represents a successful result containing a value
class Ok<T, E> extends LocalDbResult<T, E> {
  /// The successful value
  final T value;

  const Ok(this.value);

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) {
    return ok(value);
  }

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) {
    return other is Ok<T, E> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed result containing an error
class Err<T, E> extends LocalDbResult<T, E> {
  /// The error that occurred
  final E error;

  const Err(this.error);

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) {
    return err(error);
  }

  @override
  String toString() => 'Err($error)';

  @override
  bool operator ==(Object other) {
    return other is Err<T, E> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;
}
