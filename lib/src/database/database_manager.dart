import 'package:result_controller/result_controller.dart';

import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'database_interface.dart';
import 'database_factory.dart';

// Import for accessing DatabaseNative type safely across platforms  
import 'database_native_stub.dart'
    if (dart.library.io) 'database_native.dart' as native_db;


/// Database manager that handles a single database instance without singleton pattern.
/// Each database gets its own manager instance for better isolation and hot reload safety.
class DatabaseManager {
  final DatabaseInterface _database;
  final String _databaseName;
  
  DatabaseManager._(this._database, this._databaseName);

  /// Creates a new database manager for the specified database name.
  /// Automatically selects the appropriate implementation based on platform.
  /// 
  /// Returns Result<DatabaseManager, ErrorLocalDb>:
  /// - Ok(DatabaseManager) if initialization succeeds
  /// - Err(ErrorLocalDb) if initialization fails
  static Future<Result<DatabaseManager, ErrorLocalDb>> create(String databaseName) async {
    final database = DatabaseFactory.create();
    
    if (!database.isSupported) {
      return Err(ErrorLocalDb.databaseError(
        'Database is not supported on platform: ${database.platformName}'
      ));
    }
    
    try {
      await database.initialize(databaseName);
      return Ok(DatabaseManager._(database, databaseName));
    } catch (error) {
      return Err(ErrorLocalDb.databaseError(
        'Failed to initialize database "$databaseName": $error'
      ));
    }
  }

  /// Creates a database manager for testing with custom binary path.
  /// Only works on native platforms.
  static Future<Result<DatabaseManager, ErrorLocalDb>> createForTesting({
    required String databaseName, 
    required String binaryPath
  }) async {
    final database = DatabaseFactory.create();
    
    if (database.platformName == 'web') {
      return Err(ErrorLocalDb.validationError(
        'Testing with binary path is not supported on web platform'
      ));
    }
    
    try {
      // Use the conditionally imported DatabaseNative class
      if (database is native_db.DatabaseNative) {
        await database.initForTesting(databaseName, binaryPath);
        return Ok(DatabaseManager._(database, databaseName));
      } else {
        throw Exception('Testing with binary path requires native platform');
      }
    } catch (error) {
      return Err(ErrorLocalDb.databaseError(
        'Failed to initialize test database "$databaseName": $error'
      ));
    }
  }

  /// Gets the database name for this manager
  String get databaseName => _databaseName;
  
  /// Gets the platform name for this database implementation
  String get platformName => _database.platformName;
  
  /// Checks if the database connection is still valid
  Future<bool> isConnectionValid() async {
    return await _database.ensureConnectionValid();
  }

  /// Creates a new record in the database
  Future<Result<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    return await _database.post(model);
  }

  /// Retrieves a record by its unique identifier
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    return await _database.getById(id);
  }

  /// Retrieves all records from the database
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    return await _database.getAll();
  }

  /// Updates an existing record in the database
  Future<Result<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    return await _database.put(model);
  }

  /// Deletes a record by its unique identifier
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
    return await _database.delete(id);
  }

  /// Clears all records from the database
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    return await _database.cleanDatabase();
  }

  /// Closes the database connection and frees resources
  Future<Result<void, ErrorLocalDb>> close() async {
    try {
      await _database.closeDatabase();
      return Ok(());
    } catch (error) {
      return Err(ErrorLocalDb.databaseError(
        'Failed to close database "$_databaseName": $error'
      ));
    }
  }
}