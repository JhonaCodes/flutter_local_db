import 'package:flutter_local_db/src/model/local_db_error_model.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';

/// Abstract interface for database implementations across all platforms.
/// This interface ensures that both native (FFI) and web (IndexedDB) 
/// implementations provide the same API surface.
abstract class DatabaseInterface {
  /// Initialize the database with the specified name
  /// 
  /// [databaseName] - Name of the database to create/open
  /// Returns a Future that completes when initialization is done
  Future<void> initialize(String databaseName);

  /// Create a new record in the database
  /// 
  /// [model] - The model containing data to store
  /// Returns a Result with the created model or an error
  Future<Result<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model);

  /// Retrieve a record by its unique identifier
  /// 
  /// [id] - The unique identifier of the record
  /// Returns a Result with the model (or null if not found) or an error
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id);

  /// Retrieve all records from the database
  /// 
  /// Returns a Result with a list of all models or an error
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll();

  /// Update an existing record in the database
  /// 
  /// [model] - The model with updated data
  /// Returns a Result with the updated model or an error
  Future<Result<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model);

  /// Delete a record by its unique identifier
  /// 
  /// [id] - The unique identifier of the record to delete
  /// Returns a Result with success status or an error
  Future<Result<bool, ErrorLocalDb>> delete(String id);

  /// Clear all records from the database
  /// 
  /// Returns a Result with success status or an error
  Future<Result<bool, ErrorLocalDb>> cleanDatabase();

  /// Close the database connection and free resources
  /// 
  /// Returns a Future that completes when the database is closed
  Future<void> closeDatabase();

  /// Check if the database connection is valid
  /// 
  /// Returns true if the connection is valid, false otherwise
  Future<bool> ensureConnectionValid();

  /// Check if the database is available on this platform
  /// 
  /// Returns true if the database can be used on this platform
  bool get isSupported;

  /// Get the platform name for this implementation
  /// 
  /// Returns a string identifying the platform (e.g., 'native', 'web')
  String get platformName;
}