import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

/// Interface defining the contract for database operations.
/// This abstract class ensures consistent database operations across different implementations.
/// @protected - Only visible to the declaring library and implementations
/// @immutable - Interface cannot be modified after instantiation
@protected
@immutable
abstract interface class DataBaseServiceInterface {
  /// Initializes the database with provided configuration
  /// @param config Configuration settings for database setup
  Future<bool> init(ConfigDBModel config);

  /// Deletes a record by its unique identifier
  /// @param id Unique identifier of the record to delete
  /// @param secure Whether to use secure storage (default: false)
  Future<bool> delete(String id, {bool secure = false});

  /// Retrieves a paginated list of records
  /// @param limit Maximum number of records to return (default: 20)
  /// @param offset Number of records to skip for pagination (default: 0)
  /// @param secure Whether to access secure storage (default: false)
  /// @return List of database records
  Future<List<DataLocalDBModel>> get(
      {int limit = 20, int offset = 0, bool secure = false});

  /// Retrieves a single record by its unique identifier
  /// @param id Unique identifier of the record to retrieve
  /// @param secure Whether to access secure storage (default: false)
  Future<DataLocalDBModel> getById(String id, {bool secure = false});

  /// Creates a new record in the database
  /// @param data The record data to be stored
  /// @param secure Whether to use secure storage (default: false)
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false});

  /// Updates an existing record in the database
  /// @param data The record data to be updated
  /// @param secure Whether to use secure storage (default: false)
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false});

  /// Removes all records from the database
  /// @param secure Whether to clean secure storage (default: false)
  Future<bool> clean({bool secure = false});

  /// Performs a complete reset of the database, removing all data and metadata
  /// @param secure Whether to deep clean secure storage (default: false)
  Future<bool> deepClean({bool secure = false});
}
