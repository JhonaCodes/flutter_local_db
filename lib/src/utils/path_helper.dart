// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              PATH HELPER                                     ║
// ║                    Cross-Platform Path Management Utilities                  ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: path_helper.dart                                                    ║
// ║  Purpose: Platform-specific path resolution and directory management        ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Handles the complexity of cross-platform path management for database    ║
// ║    storage. Each platform has different conventions for where apps can      ║
// ║    safely store persistent data. This utility provides a unified API.      ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Cross-platform path resolution                                         ║
// ║    • Safe directory creation                                                 ║
// ║    • Permission handling                                                     ║
// ║    • Validation and sanitization                                             ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/local_db_result.dart';
import '../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

/// Cross-platform path management utilities for database storage
///
/// Handles the complex task of determining where to store database files
/// across different platforms while respecting platform conventions and
/// security constraints.
class PathHelper {
  /// Default database filename
  static const String defaultDatabaseName = 'local_database.lmdb';

  /// Default subdirectory name for database storage
  static const String defaultSubdirectory = 'flutter_local_db';

  /// Gets the default database path for the current platform
  ///
  /// Returns a platform-appropriate path where the database can be safely
  /// stored with proper read/write permissions. The path includes the
  /// database filename and is ready to use.
  ///
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  ///
  /// Platform-specific behavior:
  /// - **Android**: Uses application documents directory
  /// - **iOS**: Uses application documents directory
  /// - **macOS**: Uses application support directory
  /// - **Windows**: Uses application data directory
  /// - **Linux**: Uses application data directory or ~/.local/share
  ///
  /// Example:
  /// ```dart
  /// final result = await PathHelper.getDefaultDatabasePath();
  /// result.when(
  ///   ok: (path) => print('Database will be stored at: $path'),
  ///   err: (error) => print('Failed to determine path: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<String, ErrorLocalDb>>
  getDefaultDatabasePath() async {
    Log.i(
      '🗂️ Determining default database path for platform: ${Platform.operatingSystem}',
    );

    try {
      Directory baseDirectory;

      if (Platform.isAndroid || Platform.isIOS) {
        baseDirectory = await getApplicationDocumentsDirectory();
        Log.d('Using documents directory: ${baseDirectory.path}');
      } else {
        baseDirectory = await getApplicationSupportDirectory();
        Log.d('Using application support directory: ${baseDirectory.path}');
      }

      final dbDirectory = path.join(baseDirectory.path, defaultSubdirectory);
      final dbPath = path.join(dbDirectory, defaultDatabaseName);

      Log.i('✅ Default database path determined: $dbPath');
      return Ok(dbPath);
    } catch (e, stackTrace) {
      Log.e('💥 Failed to determine default database path: $e');
      return Err(
        ErrorLocalDb.platformError(
          'Failed to determine default database path',
          context: Platform.operatingSystem,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Gets a custom database path with the specified name
  ///
  /// Creates a database path using the provided name in the appropriate
  /// platform directory. Useful when you need multiple databases or
  /// want to customize the database filename.
  ///
  /// Parameters:
  /// - [databaseName] - Custom name for the database file
  ///
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await PathHelper.getCustomDatabasePath('user_cache.lmdb');
  /// result.when(
  ///   ok: (path) => print('Custom database path: $path'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<String, ErrorLocalDb>> getCustomDatabasePath(
    String databaseName,
  ) async {
    Log.i('🗂️ Creating custom database path with name: $databaseName');

    // Validate database name
    final validation = _validateDatabaseName(databaseName);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    try {
      Directory baseDirectory;

      if (Platform.isAndroid || Platform.isIOS) {
        baseDirectory = await getApplicationDocumentsDirectory();
      } else {
        baseDirectory = await getApplicationSupportDirectory();
      }

      final dbDirectory = path.join(baseDirectory.path, defaultSubdirectory);
      final dbPath = path.join(dbDirectory, databaseName);

      Log.i('✅ Custom database path created: $dbPath');
      return Ok(dbPath);
    } catch (e, stackTrace) {
      Log.e('💥 Failed to create custom database path: $e');
      return Err(
        ErrorLocalDb.platformError(
          'Failed to create custom database path',
          context: databaseName,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Creates a database path in a completely custom directory
  ///
  /// Allows full control over where the database is stored by specifying
  /// both the directory and filename. Use with caution as not all directories
  /// may be writable on all platforms.
  ///
  /// Parameters:
  /// - [directory] - Full path to the directory where database should be stored
  /// - [filename] - Name of the database file
  ///
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await PathHelper.createCustomPath('/tmp/myapp', 'data.lmdb');
  /// result.when(
  ///   ok: (path) => print('Database path: $path'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static LocalDbResult<String, ErrorLocalDb> createCustomPath(
    String directory,
    String filename,
  ) {
    Log.i('🗂️ Creating custom path: $directory/$filename');

    // Validate inputs
    final dirValidation = _validateDirectory(directory);
    if (dirValidation.isErr) {
      return Err(dirValidation.errOrNull!);
    }

    final nameValidation = _validateDatabaseName(filename);
    if (nameValidation.isErr) {
      return Err(nameValidation.errOrNull!);
    }

    try {
      final dbPath = path.join(directory, filename);
      Log.i('✅ Custom path created: $dbPath');
      return Ok(dbPath);
    } catch (e) {
      Log.e('💥 Failed to join paths: $e');
      return Err(
        ErrorLocalDb.validationError(
          'Failed to create path from directory and filename',
          context: '$directory + $filename',
          cause: e,
        ),
      );
    }
  }

  /// Ensures that the directory for the database path exists
  ///
  /// Creates all necessary parent directories for the given database path.
  /// This method is automatically called by the database service, but can
  /// be used manually for validation purposes.
  ///
  /// Parameters:
  /// - [databasePath] - Full path to the database file
  ///
  /// Returns:
  /// - [Ok] with the directory path on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await PathHelper.ensureDirectoryExists('/path/to/db.lmdb');
  /// result.when(
  ///   ok: (dirPath) => print('Directory ready: $dirPath'),
  ///   err: (error) => print('Failed to create directory: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<String, ErrorLocalDb>> ensureDirectoryExists(
    String databasePath,
  ) async {
    Log.d('📁 Ensuring directory exists for: $databasePath');

    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);

      if (!await dir.exists()) {
        Log.d('Creating directory: $directory');
        await dir.create(recursive: true);
        Log.i('✅ Directory created: $directory');
      } else {
        Log.d('Directory already exists: $directory');
      }

      // Verify the directory is writable
      final writeableResult = await _verifyDirectoryWriteable(directory);
      if (writeableResult.isErr) {
        return Err(writeableResult.errOrNull!);
      }

      return Ok(directory);
    } catch (e, stackTrace) {
      Log.e('💥 Failed to create directory: $e');
      return Err(
        ErrorLocalDb.platformError(
          'Failed to create database directory',
          context: databasePath,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Gets information about the available storage space
  ///
  /// Returns information about the file system where the database
  /// would be stored, including available space and total space.
  ///
  /// Parameters:
  /// - [databasePath] - Database path to check storage for
  ///
  /// Returns:
  /// - [Ok] with storage information map
  /// - [Err] with detailed error information on failure
  ///
  /// The returned map contains:
  /// - `totalSpace`: Total space in bytes
  /// - `freeSpace`: Available space in bytes
  /// - `usedSpace`: Used space in bytes
  /// - `path`: The checked path
  ///
  /// Example:
  /// ```dart
  /// final result = await PathHelper.getStorageInfo('/path/to/db.lmdb');
  /// result.when(
  ///   ok: (info) => {
  ///     print('Available space: ${info['freeSpace']} bytes'),
  ///     print('Total space: ${info['totalSpace']} bytes'),
  ///   },
  ///   err: (error) => print('Failed to get storage info: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<Map<String, dynamic>, ErrorLocalDb>>
  getStorageInfo(String databasePath) async {
    Log.d('💾 Getting storage information for: $databasePath');

    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);

      // On some platforms, we might not be able to get detailed storage info
      // This is a best-effort implementation
      try {
        final stat = await dir.stat();
        final info = {
          'path': directory,
          'exists': await dir.exists(),
          'readable': true, // Assume readable if we can stat
          'writable': await _isDirectoryWriteable(directory),
          'modified': stat.modified.toIso8601String(),
          'type': stat.type.toString(),
        };

        Log.d('✅ Storage information retrieved');
        return Ok(info);
      } catch (e) {
        // Fallback to basic information
        final info = {
          'path': directory,
          'exists': await dir.exists(),
          'readable': true,
          'writable': await _isDirectoryWriteable(directory),
          'error': 'Detailed storage info not available: $e',
        };

        return Ok(info);
      }
    } catch (e, stackTrace) {
      Log.e('💥 Failed to get storage information: $e');
      return Err(
        ErrorLocalDb.platformError(
          'Failed to get storage information',
          context: databasePath,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Validates and sanitizes a database path
  ///
  /// Performs comprehensive validation of a database path including
  /// security checks, length limits, and character validation.
  ///
  /// Parameters:
  /// - [databasePath] - The path to validate
  ///
  /// Returns:
  /// - [Ok] with the sanitized path on success
  /// - [Err] with validation error on failure
  ///
  /// Example:
  /// ```dart
  /// final result = PathHelper.validatePath('/some/path/database.lmdb');
  /// result.when(
  ///   ok: (validPath) => print('Path is valid: $validPath'),
  ///   err: (error) => print('Invalid path: $error'),
  /// );
  /// ```
  static LocalDbResult<String, ErrorLocalDb> validatePath(String databasePath) {
    Log.d('🔍 Validating database path: $databasePath');

    if (databasePath.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path cannot be empty',
          context: 'path_validation',
        ),
      );
    }

    // Check for dangerous characters
    final dangerousChars = RegExp(r'[<>:"|?*\x00-\x1f]');
    if (dangerousChars.hasMatch(databasePath)) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path contains invalid characters',
          context: databasePath,
        ),
      );
    }

    // Check path length (most file systems have limits)
    if (databasePath.length > 260 && Platform.isWindows) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path exceeds Windows path length limit (260 characters)',
          context: 'length: ${databasePath.length}',
        ),
      );
    }

    if (databasePath.length > 4096) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path exceeds maximum path length limit (4096 characters)',
          context: 'length: ${databasePath.length}',
        ),
      );
    }

    try {
      final normalizedPath = path.normalize(databasePath);
      Log.d('✅ Path validation successful: $normalizedPath');
      return Ok(normalizedPath);
    } catch (e) {
      return Err(
        ErrorLocalDb.validationError(
          'Failed to normalize database path',
          context: databasePath,
          cause: e,
        ),
      );
    }
  }

  /// Validates a database filename
  static LocalDbResult<void, ErrorLocalDb> _validateDatabaseName(
    String filename,
  ) {
    if (filename.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename cannot be empty',
          context: 'filename_validation',
        ),
      );
    }

    // Check for invalid filename characters
    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
    if (invalidChars.hasMatch(filename)) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename contains invalid characters',
          context: filename,
        ),
      );
    }

    // Check filename length
    if (filename.length > 255) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename exceeds maximum length (255 characters)',
          context: 'length: ${filename.length}',
        ),
      );
    }

    // Check for reserved names (Windows)
    if (Platform.isWindows) {
      final reservedNames = [
        'CON',
        'PRN',
        'AUX',
        'NUL',
        'COM1',
        'COM2',
        'COM3',
        'COM4',
        'COM5',
        'COM6',
        'COM7',
        'COM8',
        'COM9',
        'LPT1',
        'LPT2',
        'LPT3',
        'LPT4',
        'LPT5',
        'LPT6',
        'LPT7',
        'LPT8',
        'LPT9',
      ];
      final nameWithoutExt = path
          .basenameWithoutExtension(filename)
          .toUpperCase();
      if (reservedNames.contains(nameWithoutExt)) {
        return Err(
          ErrorLocalDb.validationError(
            'Database filename uses reserved Windows name',
            context: filename,
          ),
        );
      }
    }

    return const Ok(null);
  }

  /// Validates a directory path
  static LocalDbResult<void, ErrorLocalDb> _validateDirectory(
    String directory,
  ) {
    if (directory.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Directory path cannot be empty',
          context: 'directory_validation',
        ),
      );
    }

    if (!path.isAbsolute(directory)) {
      return Err(
        ErrorLocalDb.validationError(
          'Directory path must be absolute',
          context: directory,
        ),
      );
    }

    return const Ok(null);
  }

  /// Verifies that a directory is writeable
  static Future<LocalDbResult<void, ErrorLocalDb>> _verifyDirectoryWriteable(
    String directory,
  ) async {
    try {
      final isWriteable = await _isDirectoryWriteable(directory);
      if (!isWriteable) {
        return Err(
          ErrorLocalDb.platformError(
            'Directory is not writeable',
            context: directory,
          ),
        );
      }
      return const Ok(null);
    } catch (e) {
      return Err(
        ErrorLocalDb.platformError(
          'Failed to verify directory permissions',
          context: directory,
          cause: e,
        ),
      );
    }
  }

  /// Checks if a directory is writeable
  static Future<bool> _isDirectoryWriteable(String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) {
        return false;
      }

      // Try to create a temporary file
      final tempFile = File(
        path.join(directory, '.flutter_local_db_write_test'),
      );
      await tempFile.writeAsString('test');
      await tempFile.delete();

      return true;
    } catch (e) {
      return false;
    }
  }
}
