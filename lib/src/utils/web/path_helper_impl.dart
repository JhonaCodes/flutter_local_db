// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                         PATH HELPER (WEB)                                    ║
// ║                  Web Platform Path Management Utilities                      ║
// ║══════════════════════════════════════════════════════════════════════════════║

import '../../models/local_db_result.dart';
import '../../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

class PathHelper {
  static const String defaultDatabaseName = 'local_database';
  static const String defaultSubdirectory = 'flutter_local_db';

  static Future<LocalDbResult<String, ErrorLocalDb>>
  getDefaultDatabasePath() async {
    Log.i('🌐 Determining default database name for Web');
    // On Web, "Path" is just the database name for IndexedDB
    return const Ok(defaultDatabaseName);
  }

  static Future<LocalDbResult<String, ErrorLocalDb>> getCustomDatabasePath(
    String databaseName,
  ) async {
    Log.i('🌐 Using custom database name for Web: $databaseName');
    return Ok(databaseName);
  }

  static LocalDbResult<String, ErrorLocalDb> createCustomPath(
    String directory,
    String filename,
  ) {
    // Directory is irrelevant on web, just use filename
    Log.i('🌐 Ignoring directory on Web, using filename: $filename');
    return Ok(filename);
  }

  static Future<LocalDbResult<String, ErrorLocalDb>> ensureDirectoryExists(
    String databasePath,
  ) async {
    // No directories on Web IndexedDB
    return const Ok('');
  }

  static Future<LocalDbResult<Map<String, dynamic>, ErrorLocalDb>>
  getStorageInfo(String databasePath) async {
    // Web Storage Manager API could be used here in future,
    // but for now return basic info
    return const Ok({
      'type': 'IndexedDB',
      'path': 'browser_storage',
      'writable': true,
      'readable': true,
    });
  }

  static LocalDbResult<String, ErrorLocalDb> validatePath(String databasePath) {
    if (databasePath.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database name cannot be empty',
          context: 'path_validation',
        ),
      );
    }
    return Ok(databasePath);
  }

  /// Browsers keep 1.x data readable (IndexedDB did not change): there is
  /// nothing to move aside.
  static Future<LocalDbResult<String, ErrorLocalDb>> moveAside(
    String databasePath,
  ) async {
    return Err(ErrorLocalDb.platformError('Nothing to migrate on the web'));
  }
}
