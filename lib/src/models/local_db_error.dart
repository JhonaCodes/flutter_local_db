// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              ERROR MODEL                                     ║
// ║                      Comprehensive Error Handling                           ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: local_db_error.dart                                                 ║
// ║  Purpose: Structured error types for database operations                    ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Defines comprehensive error types for all database operations. Provides  ║
// ║    structured error information with context, types, and recovery hints.    ║
// ║    Makes debugging easier and error handling more predictable.              ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Structured error types                                                  ║
// ║    • Contextual error messages                                               ║
// ║    • Error recovery suggestions                                              ║
// ║    • Debug-friendly formatting                                               ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Enumeration of all possible error types in the database
///
/// Each error type represents a different category of failure
/// that can occur during database operations.
enum LocalDbErrorType {
  /// Database could not be initialized or opened
  initialization,

  /// Record with the specified key was not found
  notFound,

  /// Input validation failed (invalid key, data, etc.)
  validation,

  /// Low-level database operation failed
  database,

  /// JSON serialization/deserialization failed
  serialization,

  /// FFI operation failed (library loading, function calls)
  ffi,

  /// Platform-specific operation failed
  platform,

  /// Unknown or unexpected error occurred
  unknown,
}

/// Comprehensive error class for database operations
///
/// Provides detailed information about what went wrong, where it happened,
/// and potentially how to fix it. Makes debugging and error handling much easier.
///
/// Example:
/// ```dart
/// if (result.isErr) {
///   final error = result.errOrNull!;
///   print('Error type: ${error.type}');
///   print('Message: ${error.message}');
///   if (error.context != null) {
///     print('Context: ${error.context}');
///   }
/// }
/// ```
class ErrorLocalDb {
  /// The type of error that occurred
  final LocalDbErrorType type;

  /// Human-readable error message
  final String message;

  /// Optional context information (key, operation, etc.)
  final String? context;

  /// Optional underlying cause (original exception, etc.)
  final dynamic cause;

  /// Optional stack trace for debugging
  final StackTrace? stackTrace;

  const ErrorLocalDb({
    required this.type,
    required this.message,
    this.context,
    this.cause,
    this.stackTrace,
  });

  /// Creates an initialization error
  ///
  /// Used when database cannot be opened or initialized.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.initialization(
  ///   'Failed to open database: invalid path',
  ///   context: 'database_path',
  /// ));
  /// ```
  factory ErrorLocalDb.initialization(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.initialization,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates a not found error
  ///
  /// Used when a requested record doesn't exist.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.notFound(
  ///   'Record not found',
  ///   context: key,
  /// ));
  /// ```
  factory ErrorLocalDb.notFound(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.notFound,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates a validation error
  ///
  /// Used when input validation fails.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.validationError(
  ///   'Key must be at least 3 characters',
  ///   context: key,
  /// ));
  /// ```
  factory ErrorLocalDb.validationError(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.validation,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates a database error
  ///
  /// Used when low-level database operations fail.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.databaseError(
  ///   'LMDB transaction failed',
  ///   cause: originalException,
  /// ));
  /// ```
  factory ErrorLocalDb.databaseError(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.database,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates a serialization error
  ///
  /// Used when JSON operations fail.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.serializationError(
  ///   'Invalid JSON format',
  ///   cause: jsonException,
  /// ));
  /// ```
  factory ErrorLocalDb.serializationError(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.serialization,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an FFI error
  ///
  /// Used when FFI operations fail.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.ffiError(
  ///   'Failed to load native library',
  ///   context: libraryPath,
  /// ));
  /// ```
  factory ErrorLocalDb.ffiError(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.ffi,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates a platform error
  ///
  /// Used when platform-specific operations fail.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.platformError(
  ///   'Cannot access documents directory',
  ///   context: Platform.operatingSystem,
  /// ));
  /// ```
  factory ErrorLocalDb.platformError(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.platform,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Creates an unknown error
  ///
  /// Used for unexpected errors that don't fit other categories.
  ///
  /// Example:
  /// ```dart
  /// return Err(ErrorLocalDb.unknown(
  ///   'Unexpected error occurred',
  ///   cause: exception,
  /// ));
  /// ```
  factory ErrorLocalDb.unknown(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: LocalDbErrorType.unknown,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Returns a user-friendly description of the error
  ///
  /// Includes suggestions for common error types.
  String get description {
    switch (type) {
      case LocalDbErrorType.initialization:
        return 'Database initialization failed. Check that the database path is writable and the native library is available.';
      case LocalDbErrorType.notFound:
        return 'The requested record was not found. Verify the key exists in the database.';
      case LocalDbErrorType.validation:
        return 'Input validation failed. Check that your key and data meet the requirements.';
      case LocalDbErrorType.database:
        return 'Database operation failed. This could be due to corruption, disk space, or permissions.';
      case LocalDbErrorType.serialization:
        return 'JSON serialization failed. Ensure your data contains only serializable types.';
      case LocalDbErrorType.ffi:
        return 'Native library interaction failed. Check that the native library is properly installed.';
      case LocalDbErrorType.platform:
        return 'Platform-specific operation failed. This may be due to permissions or platform limitations.';
      case LocalDbErrorType.unknown:
        return 'An unexpected error occurred. Check the cause and stack trace for more details.';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('ErrorLocalDb(${type.name}: $message');

    if (context != null) {
      buffer.write(', context: $context');
    }

    if (cause != null) {
      buffer.write(', cause: $cause');
    }

    buffer.write(')');
    return buffer.toString();
  }

  /// Returns a detailed string representation for debugging
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('ErrorLocalDb Details:');
    buffer.writeln('  Type: ${type.name}');
    buffer.writeln('  Message: $message');
    buffer.writeln('  Description: $description');

    if (context != null) {
      buffer.writeln('  Context: $context');
    }

    if (cause != null) {
      buffer.writeln('  Cause: $cause');
    }

    if (stackTrace != null) {
      buffer.writeln('  Stack Trace:');
      buffer.writeln('    ${stackTrace.toString().replaceAll('\n', '\n    ')}');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is ErrorLocalDb &&
        other.type == type &&
        other.message == message &&
        other.context == context &&
        other.cause == cause;
  }

  @override
  int get hashCode {
    return Object.hash(type, message, context, cause);
  }
}
