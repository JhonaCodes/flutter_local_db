import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/repository/db_device_repository.dart';

import 'db_interface.dart';

/// ViewModel implementation for device-specific database operations implementing DataBaseServiceInterface.
/// Handles all database operations by delegating to the repository layer.
class DataBaseVM implements DataBaseServiceInterface {
  /// Initializes the database with the given configuration
  /// @param config Database configuration parameters
  /// @return Future<bool> Success status of initialization
  @override
  Future<bool> init(ConfigDBModel config) async {
    return await repositoryNotifier.notifier.init(config);
  }

  /// Retrieves a list of database records with pagination
  /// @param limit Maximum number of records to retrieve (default: 20)
  /// @param offset Number of records to skip (default: 0)
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<List<DataLocalDBModel>> List of retrieved records
  @override
  Future<List<DataLocalDBModel>> get(
      {int limit = 20, int offset = 0, bool secure = false}) async {
    return await repositoryNotifier.notifier.get(limit: limit, offset: offset);
  }

  /// Creates a new record in the database
  /// @param data The record data to store
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<DataLocalDBModel> The created record
  @override
  Future<DataLocalDBModel> post(DataLocalDBModel data,
          {bool secure = false}) async =>
      await repositoryNotifier.notifier.post(data);

  /// Cleans the database by removing all records
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<bool> Success status of the operation
  @override
  Future<bool> clean({bool secure = false}) async {
    await repositoryNotifier.notifier.clean();
    return true;
  }

  /// Deletes a specific record by ID
  /// @param id Identifier of the record to delete
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<bool> Success status of the deletion
  @override
  Future<bool> delete(String id, {bool secure = false}) async {
    await repositoryNotifier.notifier.delete(id);
    return true;
  }

  /// Retrieves a specific record by ID
  /// @param id Identifier of the record to retrieve
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<DataLocalDBModel> The retrieved record
  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) {
    return repositoryNotifier.notifier.getById(id);
  }

  /// Updates an existing record in the database
  /// @param data The updated record data
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<DataLocalDBModel> The updated record
  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false}) {
    return repositoryNotifier.notifier.put(data);
  }

  /// Performs a deep clean of the database, removing all data and resetting state
  /// @param secure Flag for secure storage access (default: false)
  /// @return Future<bool> Success status of the operation
  @override
  Future<bool> deepClean({bool secure = false}) async {
    await repositoryNotifier.notifier.deepClean();
    return true;
  }
}
