import 'core/database.dart';
import 'core/models.dart';
import 'core/result.dart';
import 'core/log.dart';

// Conditional imports for platform-specific implementations
import 'platform/database_stub.dart'
    if (dart.library.io) 'platform/database_io.dart'
    if (dart.library.js) 'platform/database_web.dart';

/// Factory class for creating platform-appropriate database instances
///
/// Automatically selects the correct database implementation based on
/// the target platform:
/// - Native platforms (Android, iOS, macOS): Uses FFI with Rust/LMDB
/// - Web platform: Uses IndexedDB with JavaScript interop
///
/// This provides a unified API while leveraging optimal storage
/// technologies for each platform.
///
/// Example:
/// ```dart
/// // Create and initialize database
/// final database = DatabaseFactory.create();
/// await database.initialize(DbConfig(name: 'my_app_db'));
///
/// // Use database operations
/// final result = await database.insert('user-1', {'name': 'John'});
/// result.when(
///   ok: (entry) => print('Saved: ${entry.id}'),
///   err: (error) => print('Error: ${error.message}')
/// );
/// ```
class DatabaseFactory {
  DatabaseFactory._();

  /// Creates a database instance for the current platform
  ///
  /// Parameters:
  /// - [dbName]: Optional database name. If provided, database will be initialized
  ///
  /// Returns:
  /// - [Database] if no name provided (requires manual initialization)
  /// - [Future<Database>] if name provided (already initialized)
  ///
  /// Example:
  /// ```dart
  /// // Manual initialization
  /// final db = DatabaseFactory.create();
  /// final config = DbConfig(name: 'my_database');
  /// await db.initialize(config);
  ///
  /// // Auto initialization
  /// final db = await DatabaseFactory.create('my_app_db');
  /// ```
  static dynamic create([String? dbName]) {
    Log.i('DatabaseFactory.create - selecting platform implementation');
    final database = createDatabase();
    Log.d('Created database instance: ${database.runtimeType}');
    
    if (dbName != null) {
      return _initializeDatabase(database, dbName);
    }
    
    return database;
  }

  static Future<Database> _initializeDatabase(Database database, String dbName) async {
    final config = DbConfig(name: dbName);
    final initResult = await database.initialize(config);
    
    return initResult.when(
      ok: (_) {
        Log.i('Database initialized successfully: $dbName');
        return database;
      },
      err: (error) {
        Log.e('Database initialization failed: ${error.message}');
        throw Exception('Failed to initialize database "$dbName": ${error.message}');
      },
    );
  }

  /// Creates and initializes a database with the given configuration
  ///
  /// Convenience method that combines database creation and initialization
  /// in a single call with proper error handling.
  ///
  /// Parameters:
  /// - [config]: Database configuration including name and options
  ///
  /// Returns:
  /// - [Ok] with the initialized database instance
  /// - [Err] with initialization error details
  ///
  /// Example:
  /// ```dart
  /// final config = DbConfig(name: 'user_data', maxRecordsPerFile: 5000);
  /// final result = await DatabaseFactory.createAndInitialize(config);
  ///
  /// result.when(
  ///   ok: (db) => print('Database ready: ${db.runtimeType}'),
  ///   err: (error) => print('Setup failed: ${error.message}')
  /// );
  /// ```
  static Future<DbResult<Database>> createAndInitialize(DbConfig config) async {
    try {
      Log.i('DatabaseFactory.createAndInitialize: ${config.name}');

      final database = create() as Database;
      final initResult = await database.initialize(config);

      return initResult.when(
        ok: (_) {
          Log.i('Database created and initialized successfully');
          return Ok(database);
        },
        err: (error) {
          Log.e('Database initialization failed: ${error.message}');
          return Err(error);
        },
      );
    } catch (e, stackTrace) {
      Log.e(
        'DatabaseFactory.createAndInitialize failed',
        error: e,
        stackTrace: stackTrace,
      );
      return Err(
        DbError.connectionError(
          'Failed to create and initialize database: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Validates database configuration before creation
  ///
  /// Checks that the configuration is valid and suitable for the
  /// current platform before attempting to create the database.
  ///
  /// Example:
  /// ```dart
  /// final config = DbConfig(name: 'test-db');
  /// final validation = DatabaseFactory.validateConfig(config);
  ///
  /// validation.when(
  ///   ok: (_) => print('Config is valid'),
  ///   err: (error) => print('Invalid config: ${error.message}')
  /// );
  /// ```
  static DbResult<void> validateConfig(DbConfig config) {
    Log.d('DatabaseFactory.validateConfig: ${config.name}');

    // Validate database name
    if (!DatabaseValidator.isValidDatabaseName(config.name)) {
      return Err(
        DbError.validationError(
          'Invalid database name: "${config.name}". Name must not contain special characters.',
        ),
      );
    }

    // Validate configuration parameters
    if (config.maxRecordsPerFile <= 0) {
      return Err(
        DbError.validationError(
          'maxRecordsPerFile must be greater than 0, got: ${config.maxRecordsPerFile}',
        ),
      );
    }

    if (config.backupEveryDays < 0) {
      return Err(
        DbError.validationError(
          'backupEveryDays must be non-negative, got: ${config.backupEveryDays}',
        ),
      );
    }

    Log.d('Database configuration validated successfully');
    return const Ok(null);
  }

  /// Gets information about the current platform's database implementation
  ///
  /// Useful for debugging and logging to understand which backend
  /// is being used on the current platform.
  ///
  /// Example:
  /// ```dart
  /// final info = DatabaseFactory.getPlatformInfo();
  /// print('Using ${info.implementation} on ${info.platform}');
  /// ```
  static DatabasePlatformInfo getPlatformInfo() {
    final database = create();
    final implementation = database.runtimeType.toString();

    String platform;
    String backend;

    if (implementation.contains('Native')) {
      platform = 'Native (Android/iOS/macOS)';
      backend = 'Rust + LMDB via FFI';
    } else if (implementation.contains('Web')) {
      platform = 'Web Browser';
      backend = 'IndexedDB (persistent)';
    } else {
      platform = 'Unknown';
      backend = 'Unknown';
    }

    return DatabasePlatformInfo(
      platform: platform,
      implementation: implementation,
      backend: backend,
    );
  }
}

/// Information about the database platform and implementation
///
/// Provides details about which database backend is being used
/// on the current platform.
class DatabasePlatformInfo {
  /// The platform name (e.g., "Native", "Web Browser")
  final String platform;

  /// The implementation class name
  final String implementation;

  /// The backend technology being used
  final String backend;

  const DatabasePlatformInfo({
    required this.platform,
    required this.implementation,
    required this.backend,
  });

  @override
  String toString() =>
      'DatabasePlatformInfo(platform: $platform, implementation: $implementation, backend: $backend)';
}
