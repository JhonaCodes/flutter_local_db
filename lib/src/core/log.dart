import 'package:logger/logger.dart';

/// Standard logging implementation for Flutter Local DB
/// 
/// Provides structured logging with different levels for development and production.
/// All log calls are centralized through this class to ensure consistency.
/// 
/// Example:
/// ```dart
/// // Debug information (development only)
/// Log.d('User initiated database operation');
/// 
/// // General information
/// Log.i('Database initialized successfully');
/// 
/// // Warnings for potential issues
/// Log.w('Network timeout, retrying operation...');
/// 
/// // Errors with context
/// Log.e('Failed to save user data', error: exception, stackTrace: stackTrace);
/// 
/// // Fatal errors
/// Log.f('Critical database corruption detected');
/// ```
class Log {
  static final Logger _log = _getLogger();

  Log._();

  static Logger _getLogger() {
    final level = Level.debug;
    final printer = PrettyPrinter(methodCount: 4);
    final output = ConsoleOutput();
    return Logger(level: level, printer: printer, output: output);
  }

  /// Debug logging - for development debugging information
  /// 
  /// Use for detailed information that is useful during development
  /// but not needed in production.
  /// 
  /// Example:
  /// ```dart
  /// Log.d('FFI function called: ${functionName}');
  /// Log.d('Database path: ${dbPath}');
  /// ```
  static void d(dynamic message) => _log.d(message);

  /// Info logging - for general application information
  /// 
  /// Use for important application events and successful operations.
  /// 
  /// Example:
  /// ```dart
  /// Log.i('LocalDB initialized successfully');
  /// Log.i('User data saved: ${userId}');
  /// ```
  static void i(dynamic message) => _log.i(message);

  /// Warning logging - for potentially harmful situations
  /// 
  /// Use when something unexpected happened but the application can continue.
  /// 
  /// Example:
  /// ```dart
  /// Log.w('Hot restart detected, reestablishing connection');
  /// Log.w('Data validation warning: ${field} may be invalid');
  /// ```
  static void w(dynamic message) => _log.w(message);
  
  /// Fatal logging - for very severe error events
  /// 
  /// Use for critical errors that may cause the application to abort.
  /// 
  /// Example:
  /// ```dart
  /// Log.f('Critical database failure: ${error}');
  /// Log.f('Native library could not be loaded');
  /// ```
  static void f(dynamic message) => _log.f(message);

  /// Error logging - for error events with optional context
  /// 
  /// Use for errors that occurred but the application can recover from.
  /// Always include error details and stack trace when available.
  /// 
  /// Example:
  /// ```dart
  /// Log.e('Failed to fetch user data', error: exception, stackTrace: stackTrace);
  /// Log.e('FFI operation failed: ${operation}', error: error);
  /// ```
  static void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log.e(message, time: time, stackTrace: stackTrace, error: error);
}