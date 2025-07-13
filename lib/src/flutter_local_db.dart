import 'core/database.dart';
import 'core/models.dart';
import 'core/result.dart' as core;
import 'core/log.dart';
import 'database_factory.dart';

// Legacy model compatibility
import 'model/local_db_request_model.dart';
import 'model/local_db_error_model.dart';
import 'service/local_db_result.dart' as legacy;

/// A comprehensive local database management utility for Flutter
/// 
/// Provides high-performance cross-platform local database operations:
/// - **Native platforms** (Android, iOS, macOS): Rust + LMDB via FFI
/// - **Web platform**: In-memory storage with localStorage persistence
/// 
/// Features:
/// - ✅ Unified API across all platforms
/// - ✅ Result-based error handling (no exceptions)
/// - ✅ JSON-serializable data storage
/// - ✅ Hot restart support
/// - ✅ High performance (10,000+ ops/sec on native)
/// 
/// Example:
/// ```dart
/// // Initialize database
/// await LocalDB.init();
/// 
/// // Create record
/// final createResult = await LocalDB.Post('user-123', {
///   'name': 'John Doe',
///   'email': 'john@example.com'
/// });
/// 
/// createResult.when(
///   ok: (entry) => print('Created: ${entry.id}'),
///   err: (error) => print('Error: ${error.message}')
/// );
/// 
/// // Retrieve record
/// final getResult = await LocalDB.GetById('user-123');
/// getResult.when(
///   ok: (entry) => print('Found: ${entry?.data}'),
///   err: (error) => print('Not found: ${error.message}')
/// );
/// ```
class LocalDB {
  static Database? _database;
  static bool _isInitialized = false;

  LocalDB._();

  /// Initializes the local database with a standard name
  /// 
  /// This method must be called before performing any database operations.
  /// Uses a standard database name to avoid user errors and simplify the API.
  /// 
  /// The method automatically:
  /// - Selects the appropriate platform implementation
  /// - Sets up the database connection
  /// - Prepares for CRUD operations
  /// 
  /// Example:
  /// ```dart
  /// await LocalDB.init();
  /// print('Database ready for operations');
  /// ```
  /// 
  /// Throws an exception if initialization fails.
  static Future<void> init() async {
    Log.i('LocalDB.init started');
    
    try {
      final config = DbConfig(name: 'flutter_local_db');
      final result = await DatabaseFactory.createAndInitialize(config);
      
      result.when(
        ok: (database) {
          _database = database;
          _isInitialized = true;
          Log.i('LocalDB initialized successfully');
        },
        err: (error) {
          Log.e('LocalDB initialization failed: ${error.message}');
          throw Exception('Database initialization failed: ${error.message}');
        },
      );

    } catch (e, stackTrace) {
      Log.e('LocalDB.init failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Initializes database for testing purposes
  /// 
  /// **Warning**: This method is for testing only and should not be used in production.
  /// 
  /// Parameters:
  /// - [localDbName]: Custom database name for testing
  /// - [binaryPath]: Path to native library (ignored on web)
  /// 
  /// Example:
  /// ```dart
  /// await LocalDB.initForTesting(
  ///   localDbName: 'test_db',
  ///   binaryPath: '/path/to/test/lib'
  /// );
  /// ```
  static Future<void> initForTesting({
    required String localDbName,
    required String binaryPath,
  }) async {
    Log.w('LocalDB.initForTesting - DO NOT USE IN PRODUCTION');
    
    try {
      final config = DbConfig(name: localDbName);
      final result = await DatabaseFactory.createAndInitialize(config);
      
      result.when(
        ok: (database) {
          _database = database;
          _isInitialized = true;
          Log.i('LocalDB test instance initialized');
        },
        err: (error) {
          Log.e('LocalDB test initialization failed: ${error.message}');
          throw Exception('Test database initialization failed: ${error.message}');
        },
      );

    } catch (e, stackTrace) {
      Log.e('LocalDB.initForTesting failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Creates a new record in the database
  /// 
  /// Validates the key and data before attempting to create the record.
  /// Returns an error if a record with the same key already exists.
  /// 
  /// Parameters:
  /// - [key]: A unique identifier for the record
  ///   - Must be at least 3 characters long
  ///   - Can only contain letters, numbers, hyphens, and underscores
  /// - [data]: A map containing the data to be stored (must be JSON-serializable)
  /// - [lastUpdate]: Optional timestamp (not used in current implementation)
  /// 
  /// Returns:
  /// - [Ok] with the created [LocalDbModel] if successful
  /// - [Err] with error details if the operation fails
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.Post('user-456', {
  ///   'name': 'Jane Smith',
  ///   'age': 28,
  ///   'preferences': {'theme': 'dark', 'language': 'en'}
  /// });
  /// 
  /// result.when(
  ///   ok: (model) => print('User created: ${model.id}'),
  ///   err: (error) => print('Creation failed: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<LocalDbModel, ErrorLocalDb>> Post(
    String key,
    Map<String, dynamic> data, {
    String? lastUpdate,
  }) async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.Post: $key');

    final result = await _database!.insert(key, data);
    return result.when(
      ok: (entry) {
        final model = _entryToLocalDbModel(entry);
        return legacy.Ok(model);
      },
      err: (error) => legacy.Err(_dbErrorToLocalDbError(error)),
    );
  }

  /// Retrieves all records from the local database
  /// 
  /// Returns all stored records as a list of [LocalDbModel] objects.
  /// Returns an empty list if no records are found.
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.GetAll();
  /// 
  /// result.when(
  ///   ok: (models) {
  ///     print('Found ${models.length} records');
  ///     for (final model in models) {
  ///       print('Record: ${model.id} - ${model.data}');
  ///     }
  ///   },
  ///   err: (error) => print('Query failed: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> GetAll() async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.GetAll');

    final result = await _database!.getAll();
    return result.when(
      ok: (entries) {
        final models = entries.map(_entryToLocalDbModel).toList();
        return legacy.Ok(models);
      },
      err: (error) => legacy.Err(_dbErrorToLocalDbError(error)),
    );
  }

  /// Retrieves a single record by its unique identifier
  /// 
  /// Returns the record if found, or null if no record matches the ID.
  /// 
  /// Parameters:
  /// - [id]: The unique identifier of the record to retrieve
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.GetById('user-123');
  /// 
  /// result.when(
  ///   ok: (model) {
  ///     if (model != null) {
  ///       print('User found: ${model.data['name']}');
  ///     } else {
  ///       print('User not found');
  ///     }
  ///   },
  ///   err: (error) => print('Query error: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<LocalDbModel?, ErrorLocalDb>> GetById(String id) async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.GetById: $id');

    final result = await _database!.get(id);
    return result.when(
      ok: (entry) {
        final model = _entryToLocalDbModel(entry);
        return legacy.Ok(model);
      },
      err: (error) {
        // Convert not found to null result instead of error for backward compatibility
        if (error.type == core.DbErrorType.notFound) {
          return const legacy.Ok(null);
        }
        return legacy.Err(_dbErrorToLocalDbError(error));
      },
    );
  }

  /// Updates an existing record in the database
  /// 
  /// Replaces the data for an existing key. Returns an error if the record doesn't exist.
  /// 
  /// Parameters:
  /// - [key]: The unique identifier of the record to update
  /// - [data]: The new data to store (must be JSON-serializable)
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.Put('user-123', {
  ///   'name': 'John Smith', // Updated name
  ///   'age': 31,            // Updated age
  ///   'email': 'john.smith@example.com'
  /// });
  /// 
  /// result.when(
  ///   ok: (model) => print('User updated: ${model.id}'),
  ///   err: (error) => print('Update failed: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<LocalDbModel, ErrorLocalDb>> Put(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.Put: $key');

    final result = await _database!.update(key, data);
    return result.when(
      ok: (entry) {
        final model = _entryToLocalDbModel(entry);
        return legacy.Ok(model);
      },
      err: (error) => legacy.Err(_dbErrorToLocalDbError(error)),
    );
  }

  /// Deletes a record by its unique identifier
  /// 
  /// Removes the record from the database. Returns success even if the
  /// record didn't exist.
  /// 
  /// Parameters:
  /// - [id]: The unique identifier of the record to delete
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.Delete('user-123');
  /// 
  /// result.when(
  ///   ok: (_) => print('User deleted successfully'),
  ///   err: (error) => print('Delete failed: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<bool, ErrorLocalDb>> Delete(String id) async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.Delete: $id');

    final result = await _database!.delete(id);
    return result.when(
      ok: (_) => const legacy.Ok(true),
      err: (error) => legacy.Err(_dbErrorToLocalDbError(error)),
    );
  }

  /// Clears all data from the database
  /// 
  /// Removes all records but keeps the database structure intact.
  /// This operation cannot be undone.
  /// 
  /// Example:
  /// ```dart
  /// final result = await LocalDB.ClearData();
  /// 
  /// result.when(
  ///   ok: (_) => print('All data cleared'),
  ///   err: (error) => print('Clear failed: ${error.message}')
  /// );
  /// ```
  // ignore: non_constant_identifier_names
  static Future<legacy.LocalDbResult<bool, ErrorLocalDb>> ClearData() async {
    if (!_ensureInitialized()) {
      return legacy.Err(ErrorLocalDb.databaseError('Database not initialized. Call LocalDB.init() first.'));
    }

    Log.d('LocalDB.ClearData');

    final result = await _database!.clear();
    return result.when(
      ok: (_) => const legacy.Ok(true),
      err: (error) => legacy.Err(_dbErrorToLocalDbError(error)),
    );
  }

  /// Gets information about the current platform's database implementation
  /// 
  /// Useful for debugging and understanding which backend technology
  /// is being used on the current platform.
  /// 
  /// Example:
  /// ```dart
  /// final info = LocalDB.getPlatformInfo();
  /// print('Platform: ${info.platform}');
  /// print('Backend: ${info.backend}');
  /// ```
  static DatabasePlatformInfo getPlatformInfo() {
    return DatabaseFactory.getPlatformInfo();
  }

  /// Checks if the database is properly initialized
  /// 
  /// Returns true if [init] has been called successfully and the database
  /// is ready for operations.
  static bool get isInitialized => _isInitialized;

  /// Closes the database connection and releases resources
  /// 
  /// Should be called when the database is no longer needed.
  /// After calling this method, [init] must be called again before
  /// performing any operations.
  /// 
  /// Example:
  /// ```dart
  /// await LocalDB.close();
  /// print('Database connection closed');
  /// ```
  static Future<void> close() async {
    Log.i('LocalDB.close');
    
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    _isInitialized = false;
  }

  /// Ensures the database is initialized, throwing if not
  static bool _ensureInitialized() {
    if (!_isInitialized || _database == null) {
      Log.e('Database operation attempted without initialization');
      return false;
    }
    return true;
  }

  /// Converts a DbEntry to LocalDbModel for backward compatibility
  static LocalDbModel _entryToLocalDbModel(DbEntry entry) {
    return LocalDbModel(
      id: entry.id,
      data: entry.data,
      hash: entry.hash,
    );
  }

  /// Converts a DbError to ErrorLocalDb for backward compatibility
  static ErrorLocalDb _dbErrorToLocalDbError(core.DbError error) {
    switch (error.type) {
      case core.DbErrorType.notFound:
        return ErrorLocalDb.notFound(error.message);
      case core.DbErrorType.validation:
        return ErrorLocalDb.validationError(error.message);
      case core.DbErrorType.serialization:
        return ErrorLocalDb.serializationError(error.message);
      case core.DbErrorType.database:
      case core.DbErrorType.connection:
      case core.DbErrorType.unknown:
        return ErrorLocalDb.databaseError(error.message);
    }
  }
}