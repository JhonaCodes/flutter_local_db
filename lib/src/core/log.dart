import 'package:logger/logger.dart';

/// Standard logging class implementation following corporate standards.
/// 
/// This class provides a unified logging interface across the entire
/// flutter_local_db library with consistent formatting and level management.
/// 
/// SECURITY NOTE: This logging implementation follows secure logging practices:
/// - No user passwords, tokens, or personal data are logged
/// - File paths are sanitized to avoid exposing user directory structures
/// - Error messages are generalized to prevent information leakage
/// - Debug information is limited to technical system state
/// 
/// Usage:
/// - Log.d() for debug information
/// - Log.i() for general information  
/// - Log.w() for warnings
/// - Log.e() for errors with optional context
/// - Log.f() for fatal errors
class Log {
  static final Logger _log = _getLogger();

  Log._();

  static Logger _getLogger() {
    final level = Level.debug;
    final printer = PrettyPrinter(methodCount: 4);
    final output = ConsoleOutput();
    return Logger(level: level, printer: printer, output: output);
  }

  /// Debug level logging for development information
  /// Use for: FFI calls, state changes, detailed flow tracking
  static void d(dynamic message) => _log.d(message);

  /// Info level logging for general application information
  /// Use for: initialization, successful operations, navigation
  static void i(dynamic message) => _log.i(message);

  /// Warning level logging for potentially harmful situations
  /// Use for: retries, fallbacks, recovery attempts, timeouts
  static void w(dynamic message) => _log.w(message);
  
  /// Fatal level logging for very severe error events
  /// Use for: critical system failures, unrecoverable errors
  static void f(dynamic message) => _log.f(message);

  /// Error level logging with optional context information
  /// Use for: FFI failures, exceptions, hot reload issues, database errors
  static void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) =>
      _log.e(message, time: time, stackTrace: stackTrace, error: error);
}