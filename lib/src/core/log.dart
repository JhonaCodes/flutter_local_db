import 'dart:io';

import 'package:logging/logging.dart';

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

  // ANSI Color codes - Rust style with proper dim colors
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _redDim = '\x1B[2m\x1B[31m'; // Dim red
  static const String _yellow = '\x1B[33m';
  static const String _yellowDim = '\x1B[2m\x1B[33m'; // Dim yellow
  static const String _green = '\x1B[32m';
  static const String _greenDim = '\x1B[2m\x1B[32m'; // Dim green
  static const String _cyan = '\x1B[36m';
  static const String _cyanDim = '\x1B[2m\x1B[36m'; // Dim cyan
  static const String _magenta = '\x1B[35m';
  static const String _magentaDim = '\x1B[2m\x1B[35m'; // Dim magenta
  static const String _gray = '\x1B[90m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';

  static Logger _getLogger() {
    final logger = Logger.root;

    Logger.root.level = Level.ALL;

    Logger.root.onRecord.listen((LogRecord record) {
      final now = DateTime.now();
      final timestamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

      String levelName = '';
      String prefix = '';
      String message = '';
      String additionalInfo = '';

      // Get caller information for Rust-like location display with clickable links
      final stackTrace = StackTrace.current.toString();
      final lines = stackTrace.split('\n');
      String location = 'unknown:0:0';
      String clickableLink = '';

      // First pass: extract project root from any stackTrace line that has full path
      String? projectRoot;
      for (final line in lines) {
        // Look for a line with full path to extract project root
        final fullPathMatch = RegExp(
          r'\(([^)]+)/lib/[^)]+\.dart:\d+:\d+\)',
        ).firstMatch(line);
        if (fullPathMatch != null) {
          projectRoot = fullPathMatch.group(1);
          break;
        }
      }

      // Extract precise caller location from stack trace
      for (final line in lines) {
        // Look for application code (skip logging infrastructure)
        if ((line.contains('package:') || line.contains('file:///')) &&
            !line.contains('log.dart') &&
            !line.contains('logging.dart') &&
            !line.contains('zone.dart') &&
            !line.contains('Logger.') &&
            !line.contains('onRecord.listen')) {
          RegExpMatch? match;
          String? fileName, lineNum, colNum, fullPath;
          String? packageName;

          // Try generic package format: package:<pkg>/path/to/file.dart:48:7)
          match = RegExp(
            r'package:([^)]+)/([^)]+\.dart):(\d+):(\d+)',
          ).firstMatch(line);
          if (match != null) {
            packageName = match.group(1)!;
            final filePath = match.group(2)!;
            fileName = filePath.split('/').last;
            lineNum = match.group(3)!;
            colNum = match.group(4)!;

            // Extract absolute path from stackTrace itself
            // Look for the full path in stackTrace lines
            String? absolutePath;
            for (final stackLine in lines) {
              if (stackLine.contains('package:$packageName/$filePath')) {
                // Try to find the real path in the stackTrace
                final fullPathMatch = RegExp(
                  '\\(([^)]+/$filePath):\\d+:\\d+\\)',
                ).firstMatch(stackLine);
                if (fullPathMatch != null) {
                  absolutePath = fullPathMatch.group(1);
                  break;
                }
              }
            }

            // If not found in stack, construct using extracted project root
            if (absolutePath != null) {
              fullPath = absolutePath;
            } else if (projectRoot != null) {
              // Use automatically detected project root
              fullPath = '$projectRoot/lib/$filePath';
            } else {
              // Last resort: try to guess from current script location
              final scriptUri = Platform.script;
              if (scriptUri.path.contains('/lib/')) {
                final basePath = scriptUri.path.substring(
                  0,
                  scriptUri.path.lastIndexOf('/lib/'),
                );
                fullPath = '$basePath/lib/$filePath';
              } else {
                // Ultimate fallback
                fullPath = './lib/$filePath';
              }
            }
          } else {
            // Try file format: file:///absolute/path/file.dart:48:7)
            match = RegExp(
              r'file://([^:)]+\.dart):(\d+):(\d+)',
            ).firstMatch(line);
            if (match != null) {
              fullPath = match.group(1)!;
              fileName = fullPath.split('/').last;
              lineNum = match.group(2)!;
              colNum = match.group(3)!;
            }
          }

          if (fileName != null &&
              lineNum != null &&
              colNum != null &&
              fullPath != null) {
            location = '$fileName:$lineNum:$colNum';
            // Just show the clean path without file:// prefix
            clickableLink = '$fullPath:$lineNum:$colNum';
            break;
          }
        }
      }

      // If no precise location found, try to get at least the method name
      if (location == 'unknown:0:0') {
        for (final line in lines) {
          if (line.contains('_incrementCounter') ||
              line.contains('main.dart')) {
            final match = RegExp(
              r'([^/\s]+\.dart):(\d+):(\d+)',
            ).firstMatch(line);
            if (match != null) {
              final fallbackFile = match.group(1)!;
              final fallbackLine = match.group(2)!;
              final fallbackCol = match.group(3)!;
              location = '$fallbackFile:$fallbackLine:$fallbackCol';

              // Use detected project root or Platform.script fallback
              String fallbackFullPath;
              if (projectRoot != null) {
                fallbackFullPath = '$projectRoot/lib/$fallbackFile';
              } else {
                final scriptUri = Platform.script;
                if (scriptUri.path.contains('/lib/')) {
                  final basePath = scriptUri.path.substring(
                    0,
                    scriptUri.path.lastIndexOf('/lib/'),
                  );
                  fallbackFullPath = '$basePath/lib/$fallbackFile';
                } else {
                  fallbackFullPath = './lib/$fallbackFile';
                }
              }
              clickableLink = '$fallbackFullPath:$fallbackLine:$fallbackCol';
              break;
            }
          }
        }
      }

      // Rust-like formatting with proper spacing and colors
      switch (record.level) {
        case Level.SEVERE: // Check if it's e() or f() call
          final stackLines = StackTrace.current.toString().split('\n');
          bool isFatalCall = false;

          // Check if called via f() method by looking at stack
          for (final line in stackLines) {
            if (line.contains('Log.f')) {
              isFatalCall = true;
              break;
            }
          }

          if (isFatalCall) {
            // F = CRITICAL (morado)
            levelName = 'critical';
            prefix =
                '$_bold${_magenta}CRITICAL$_reset: $_magentaDim${record.message}$_reset';
            additionalInfo =
                '\n$_bold$_magenta  --> $_reset$_gray$location$_reset $_dim($clickableLink)$_reset';
            additionalInfo += '\n$_bold$_magenta   |$_reset';
            additionalInfo +=
                '\n$_bold$_magenta   = $_reset${_bold}critical$_reset: ${_magentaDim}System requires immediate attention$_reset';
            additionalInfo +=
                '\n$_bold$_magenta   = $_reset${_bold}help$_reset: ${_magentaDim}Check system logs and restart if necessary$_reset';
          } else {
            // E = ERROR (rojo)
            levelName = 'error';
            prefix =
                '$_bold${_red}ERROR$_reset: $_redDim${record.message}$_reset';
            additionalInfo =
                '\n$_bold$_red  --> $_reset$_gray$location$_reset $_dim($clickableLink)$_reset';
            additionalInfo += '\n$_bold$_red   |$_reset';

            if (record.error != null) {
              additionalInfo +=
                  '\n$_bold$_red   = $_reset${_bold}error$_reset: $_redDim${record.error}$_reset';
            }
            if (record.stackTrace != null) {
              final errorStackLines = record.stackTrace
                  .toString()
                  .split('\n')
                  .take(4)
                  .toList();
              for (int i = 0; i < errorStackLines.length; i++) {
                final lineNum = (i + 1).toString().padLeft(2);
                additionalInfo +=
                    '\n$_bold$_red$lineNum |$_reset $_gray${errorStackLines[i].trim()}$_reset';
              }
              additionalInfo += '\n$_bold$_red   |$_reset';
            }
          }
          additionalInfo += '\n'; // Empty line after error/critical
          message = '';
          break;

        case Level.WARNING: // Warning - Yellow like Rust warning
          levelName = 'warning';
          prefix =
              '$_bold${_yellow}warning$_reset: $_yellowDim${record.message}$_reset';
          additionalInfo =
              '\n$_bold$_yellow  --> $_reset$_gray$location$_reset $_dim($clickableLink)$_reset';
          additionalInfo += '\n$_bold$_yellow   |$_reset';

          if (record.error != null) {
            additionalInfo +=
                '\n$_bold$_yellow   = $_reset${_bold}note$_reset: $_yellowDim${record.error}$_reset';
          }
          additionalInfo += '\n'; // Empty line after warning
          message = '';
          break;

        case Level.INFO: // Info - Green with spacing and clickable link
          levelName = 'info';
          prefix =
              '$_bold${_green}INFO$_reset: $_greenDim${record.message}$_reset $_dim($clickableLink)$_reset';
          message = '';
          additionalInfo = '\n'; // Empty line after info
          break;

        case Level.FINE: // Debug - Cyan with spacing and clickable link
          levelName = 'debug';
          prefix =
              '$_bold${_cyan}DEBUG$_reset: $_cyanDim${record.message}$_reset $_dim($clickableLink)$_reset';
          message = '';
          additionalInfo = '\n'; // Empty line after debug
          break;

        default: // Trace - Dim with spacing and clickable link
          levelName = 'trace';
          prefix =
              '$_dim${_gray}TRACE$_reset: $_gray${record.message}$_reset $_dim($clickableLink)$_reset';
          message = '';
          additionalInfo = '\n'; // Empty line after trace
      }

      // Rust-like format with proper spacing
      final rustFormat = '$prefix$message$additionalInfo';

      // Print only with Rust-like format (no duplication)

      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux) {
        // ignore: avoid_print
        print(rustFormat);
      } else {
        // ignore: avoid_print
        print('[$levelName] $timestamp ${record.message}$additionalInfo');
      }
    });

    return logger;
  }

  static void d(dynamic message) => _log.fine(message);

  static void i(dynamic message) => _log.info(message);

  static void w(dynamic message) => _log.warning(message);

  static void f(dynamic message) => _log.severe(message);

  static void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) => _log.severe(message, error, stackTrace);
}
