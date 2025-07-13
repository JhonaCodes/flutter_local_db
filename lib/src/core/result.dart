/// Result Pattern Implementation for Flutter Local DB
/// Based on result_controller standard
/// 
/// Represents a result that can be either successful (Ok) or an error (Err).
/// This eliminates the need for exceptions by encapsulating operations that can fail.
/// 
/// Example:
/// ```dart
/// Result<String, DbError> saveUser(User user) {
///   try {
///     final id = database.save(user);
///     return Ok(id);
///   } catch (e) {
///     return Err(DbError.saveFailed(e.toString()));
///   }
/// }
/// 
/// // Usage:
/// final result = saveUser(user);
/// final message = result.when(
///   ok: (id) => 'User saved with ID: $id',
///   err: (error) => 'Failed to save: ${error.message}'
/// );
/// ```
abstract class Result<T, E> {
  const Result();

  /// Pattern matches on the result to handle both success and error cases
  /// 
  /// Example:
  /// ```dart
  /// result.when(
  ///   ok: (data) => print('Success: $data'),
  ///   err: (error) => print('Error: $error')
  /// );
  /// ```
  R when<R>({
    required R Function(T) ok,
    required R Function(E) err,
  });

  /// Transforms the success value if present, preserving error
  /// 
  /// Example:
  /// ```dart
  /// final userResult = Ok<User, String>(user);
  /// final nameResult = userResult.map((user) => user.name);
  /// // Returns: Ok<String, String>(user.name)
  /// ```
  Result<R, E> map<R>(R Function(T value) transform);

  /// Chains operations that might fail
  /// 
  /// Example:
  /// ```dart
  /// final result = getUserById(id)
  ///   .flatMap((user) => validateUser(user))
  ///   .flatMap((user) => saveUser(user));
  /// ```
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform);

  /// Returns true if this is a success result
  bool get isOk => when(ok: (_) => true, err: (_) => false);

  /// Returns true if this is an error result
  bool get isErr => !isOk;

  /// Gets the success value or throws if this is an error
  /// 
  /// Warning: Use with caution. Prefer `when()` for safe access.
  T get data => when(
    ok: (value) => value,
    err: (error) => throw StateError('Cannot access data on Err value: $error'),
  );

  /// Gets the error value if present, null otherwise
  E? get errorOrNull => when(
    ok: (_) => null,
    err: (error) => error,
  );

  @override
  String toString() => when(
    ok: (data) => 'Ok($data)',
    err: (error) => 'Err($error)',
  );

  @override
  bool operator ==(Object other) {
    return when(
      ok: (data) => other is Ok<T, E> && other.data == data,
      err: (error) => other is Err<T, E> && other.error == error,
    );
  }

  @override
  int get hashCode => when(
    ok: (data) => data.hashCode,
    err: (error) => error.hashCode,
  );
}

/// Represents a successful result containing a value of type T
/// 
/// Example:
/// ```dart
/// final success = Ok<String, String>('Operation completed');
/// final transformed = success.map((value) => value.toUpperCase());
/// // Result: Ok('OPERATION COMPLETED')
/// ```
class Ok<T, E> extends Result<T, E> {
  final T data;

  const Ok(this.data);

  @override
  R when<R>({
    required R Function(T) ok,
    required R Function(E) err,
  }) => ok(data);

  @override
  Result<R, E> map<R>(R Function(T value) transform) => Ok(transform(data));

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) => transform(data);
}

/// Represents an error result containing an error of type E
/// 
/// Example:
/// ```dart
/// final failure = Err<String, String>('Operation failed');
/// final preserved = failure.map((value) => value.toUpperCase());
/// // Result: Err('Operation failed') - error preserved
/// ```
class Err<T, E> extends Result<T, E> {
  final E error;

  const Err(this.error);

  @override
  R when<R>({
    required R Function(T) ok,
    required R Function(E) err,
  }) => err(error);

  @override
  Result<R, E> map<R>(R Function(T value) transform) => Err(error);

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) => Err(error);
}

/// Specialized Result for Local Database operations
/// 
/// Example:
/// ```dart
/// Future<DbResult<User>> fetchUser(String id) async {
///   try {
///     final userData = await database.get(id);
///     return DbResult.ok(User.fromJson(userData));
///   } catch (e) {
///     return DbResult.err(DbError.fetchFailed('User not found: $id'));
///   }
/// }
/// ```
typedef DbResult<T> = Result<T, DbError>;

/// Extension methods for Result
extension ResultExtensions<T, E> on Result<T, E> {
  /// Transforms the error value if present
  /// 
  /// Example:
  /// ```dart
  /// final result = Err<String, String>('network error');
  /// final mapped = result.mapError((error) => DbError.networkError(error));
  /// ```
  Result<T, F> mapError<F>(F Function(E error) transform) {
    return when(
      ok: (value) => Ok(value),
      err: (error) => Err(transform(error)),
    );
  }

  /// Attempts to recover from an error
  /// 
  /// Example:
  /// ```dart
  /// final result = fetchFromNetwork()
  ///   .recover((error) => fetchFromCache());
  /// ```
  Result<T, E> recover(Result<T, E> Function(E error) transform) {
    return when(
      ok: (value) => Ok(value),
      err: transform,
    );
  }

  /// Gets the success value or a default from the error
  /// 
  /// Example:
  /// ```dart
  /// final value = result.getOrElse((error) => 'default value');
  /// ```
  T getOrElse(T Function(E error) orElse) {
    return when(
      ok: (value) => value,
      err: orElse,
    );
  }

  /// Gets the success value or a default value
  /// 
  /// Example:
  /// ```dart
  /// final value = result.getOrDefault('default value');
  /// ```
  T getOrDefault(T defaultValue) {
    return when(
      ok: (value) => value,
      err: (_) => defaultValue,
    );
  }
}

/// Extension methods for Future<Result>
extension FutureResultExtensions<T, E> on Future<Result<T, E>> {
  /// Maps the success value of a Future<Result>
  /// 
  /// Example:
  /// ```dart
  /// final futureResult = fetchUser(id).map((user) => user.name);
  /// ```
  Future<Result<R, E>> map<R>(R Function(T value) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// Chains async operations that might fail
  /// 
  /// Example:
  /// ```dart
  /// final result = fetchUser(id)
  ///   .flatMap((user) => validateUser(user))
  ///   .flatMap((user) => saveUser(user));
  /// ```
  Future<Result<R, E>> flatMap<R>(
    Future<Result<R, E>> Function(T value) transform,
  ) async {
    final result = await this;
    return result.when(
      ok: transform,
      err: (error) => Err(error),
    );
  }
}

/// Database-specific error types
/// 
/// Example:
/// ```dart
/// final error = DbError.notFound('User with ID 123 not found');
/// final error2 = DbError.validationError('Invalid email format');
/// ```
class DbError {
  final String title;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;
  final DbErrorType type;

  const DbError({
    required this.title,
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
  });

  /// Creates a not found error
  factory DbError.notFound(String message) => DbError(
    title: 'Not Found',
    message: message,
    type: DbErrorType.notFound,
  );

  /// Creates a validation error
  factory DbError.validationError(String message) => DbError(
    title: 'Validation Error',
    message: message,
    type: DbErrorType.validation,
  );

  /// Creates a database operation error
  factory DbError.databaseError(String message, {Object? originalError, StackTrace? stackTrace}) => DbError(
    title: 'Database Error',
    message: message,
    type: DbErrorType.database,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// Creates a serialization error
  factory DbError.serializationError(String message, {Object? originalError, StackTrace? stackTrace}) => DbError(
    title: 'Serialization Error',
    message: message,
    type: DbErrorType.serialization,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// Creates a connection error
  factory DbError.connectionError(String message, {Object? originalError, StackTrace? stackTrace}) => DbError(
    title: 'Connection Error',
    message: message,
    type: DbErrorType.connection,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  @override
  String toString() => '$title: $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DbError &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          message == other.message &&
          type == other.type;

  @override
  int get hashCode => title.hashCode ^ message.hashCode ^ type.hashCode;
}

/// Types of database errors
enum DbErrorType {
  notFound,
  validation,
  database,
  serialization,
  connection,
  unknown,
}