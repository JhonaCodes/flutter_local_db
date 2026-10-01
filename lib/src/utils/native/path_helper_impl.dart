// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                         PATH HELPER (NATIVE)                                 ║
// ║               Native Platform Path Management Utilities                      ║
// ══════════════════════════════════════════════════════════════════════════════║

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:result_controller/result_controller.dart';
import '../../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

class PathHelper {
  static const String defaultDatabaseName = 'local_database.lmdb';
  static const String defaultSubdirectory = 'flutter_local_db';

  static Future<Result<String, ErrorLocalDb>> getDefaultDatabasePath() async {
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

  static Future<Result<String, ErrorLocalDb>> getCustomDatabasePath(
    String databaseName,
  ) async {
    Log.i('🗂️ Creating custom database path with name: $databaseName');

    final validation = _validateDatabaseName(databaseName);
    if (validation.isErr) {
      return Err(validation.errorOrNull!);
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

  static Result<String, ErrorLocalDb> createCustomPath(
    String directory,
    String filename,
  ) {
    Log.i('🗂️ Creating custom path: $directory/$filename');

    final dirValidation = _validateDirectory(directory);
    if (dirValidation.isErr) {
      return Err(dirValidation.errorOrNull!);
    }

    final nameValidation = _validateDatabaseName(filename);
    if (nameValidation.isErr) {
      return Err(nameValidation.errorOrNull!);
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

  static Future<Result<String, ErrorLocalDb>> ensureDirectoryExists(
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

      final writeableResult = await _verifyDirectoryWriteable(directory);
      if (writeableResult.isErr) {
        return Err(writeableResult.errorOrNull!);
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

  static Future<Result<Map<String, dynamic>, ErrorLocalDb>> getStorageInfo(
    String databasePath,
  ) async {
    Log.d('💾 Getting storage information for: $databasePath');

    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);

      try {
        final stat = await dir.stat();
        final info = {
          'path': directory,
          'exists': await dir.exists(),
          'readable': true,
          'writable': await _isDirectoryWriteable(directory),
          'modified': stat.modified.toIso8601String(),
          'type': stat.type.toString(),
        };

        Log.d('✅ Storage information retrieved');
        return Ok(info);
      } catch (e) {
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

  static Result<String, ErrorLocalDb> validatePath(String databasePath) {
    Log.d('🔍 Validating database path: $databasePath');

    if (databasePath.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path cannot be empty',
          context: 'path_validation',
        ),
      );
    }

    final dangerousChars = RegExp(r'[<>:"|?*\x00-\x1f]');
    if (dangerousChars.hasMatch(databasePath)) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path contains invalid characters',
          context: databasePath,
        ),
      );
    }

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

  static Result<void, ErrorLocalDb> _validateDatabaseName(String filename) {
    if (filename.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename cannot be empty',
          context: 'filename_validation',
        ),
      );
    }

    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
    if (invalidChars.hasMatch(filename)) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename contains invalid characters',
          context: filename,
        ),
      );
    }

    if (filename.length > 255) {
      return Err(
        ErrorLocalDb.validationError(
          'Database filename exceeds maximum length (255 characters)',
          context: 'length: ${filename.length}',
        ),
      );
    }

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

    return Ok(null);
  }

  static Result<void, ErrorLocalDb> _validateDirectory(String directory) {
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

    return Ok(null);
  }

  static Future<Result<void, ErrorLocalDb>> _verifyDirectoryWriteable(
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
      return Ok(null);
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

  static Future<bool> _isDirectoryWriteable(String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) {
        return false;
      }

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

  /// Renames the files of the database at [databasePath] (`<path>.lmdb`) to
  /// `<path>.lmdb.1x-backup-<timestamp>` and returns the new location, so that
  /// a new database can be created there without losing the old files.
  static Future<Result<String, ErrorLocalDb>> moveAside(
    String databasePath,
  ) async {
    final directory = Directory('$databasePath.lmdb');
    if (!directory.existsSync()) {
      return Err(ErrorLocalDb.notFound('No database at ${directory.path}'));
    }
    final backup =
        '${directory.path}.1x-backup-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await directory.rename(backup);
      return Ok(backup);
    } on FileSystemException catch (e) {
      return Err(
        ErrorLocalDb.platformError(
          'Cannot move ${directory.path} aside',
          cause: e,
        ),
      );
    }
  }
}
