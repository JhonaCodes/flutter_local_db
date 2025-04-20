import 'dart:convert';
import 'dart:developer';

import 'package:flutter_local_db/src/service/local_db_result.dart';

import 'bridge/local_db_bridge.dart';
import 'model/local_db_request_model.dart';

/// A comprehensive local database management utility.
///
/// Provides static methods for performing CRUD (Create, Read, Update, Delete)
/// operations on a local database with robust validation and error handling.
///
/// Uses a bridge pattern to abstract database interactions and provides
/// type-safe results using [LocalDbResult].
class LocalDB {

  static LocalDbBridge get _localDb => LocalDbBridge();

  /// Initializes the local database with a specified name.
  ///
  /// This method must be called before performing any database operations.
  ///
  /// Parameters:
  /// - [localDbName]: A unique name for the local database instance
  ///
  /// Throws an exception if initialization fails
  static Future<void> init({required String localDbName}) async {
    final response = IsOpen();

    response.when(
      ok: (isOpen) async {
        if(!isOpen){
          await _localDb.initialize(localDbName);
        }
      },
      err: (err){
        log("Error on validating Database, closing database");
        //Dispose();
      },
    );

  }

  /// Avoid to use on production.
  ///
  static Future<void> initForTesting(
      {required String localDbName, required String binaryPath}) async {
    await _localDb.initForTesting(localDbName, binaryPath);
  }

  /// Creates a new record in the database.
  ///
  /// Validates the key and data before attempting to create the record.
  ///
  /// Parameters:
  /// - [key]: A unique identifier for the record
  ///   - Must be at least 3 characters long
  ///   - Can only contain letters, numbers, hyphens, and underscores
  /// - [data]: A map containing the data to be stored
  /// - [lastUpdate]: Optional timestamp for the record (not used in this implementation)
  ///
  /// Returns:
  /// - [Ok] with the created [LocalDbRequestModel] if successful
  /// - [Err] with an error message if:
  ///   - The key is invalid
  ///   - The data cannot be serialized
  ///   - A record with the same key already exists
  // ignore: non_constant_identifier_names
  static LocalDbResult<LocalDbRequestModel, String> Post(
      String key, Map<String, dynamic> data,
      {String? lastUpdate})  {
    if (!_isValidId(key)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    if (!_isValidMap(data)) {
      return Err('The provided format data is invalid.\n$data');
    }

    final verifyId =  GetById(key);

    if (verifyId.isOk) {
      return Err(
          "Cannot create new record: ID '$key' already exists. Use PUT method to update existing records.");
    }

    final model = LocalDbRequestModel(
      id: key,
      hash: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
    );

    return _localDb.post(model);
  }

  /// Retrieves all records from the local database.
  ///
  /// Returns:
  /// - [Ok] with a list of [LocalDbRequestModel]
  ///   - Returns an empty list if no records are found
  /// - [Err] with an error message if the operation fails
  static LocalDbResult<List<LocalDbRequestModel>, String>
      // ignore: non_constant_identifier_names
      GetAll() {
    return _localDb.getAll();
  }

  /// Retrieves a single record by its unique identifier.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the record to retrieve
  ///
  /// Returns:
  /// - [Ok] with the [LocalDbRequestModel] if found
  /// - [Ok] with `null` if no record matches the ID
  /// - [Err] with an error message if the key is invalid
  // ignore: non_constant_identifier_names
  static LocalDbResult<LocalDbRequestModel?, String> GetById(String id) {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    return _localDb.getById(id);
  }

  /// Updates an existing record in the database.
  ///
  /// Parameters:
  /// - [key]: The unique identifier of the record to update
  /// - [data]: The new data to store
  ///
  /// Returns:
  /// - [Ok] with the updated [LocalDbRequestModel] if successful
  /// - [Err] with an error message if the record does not exist
  // ignore: non_constant_identifier_names
  static LocalDbResult<LocalDbRequestModel, String> Put(
      String key, Map<String, dynamic> data) {
    final verifyId =  GetById(key);

    if (verifyId.isOk) {
      final currentData = LocalDbRequestModel(
          id: key,
          data: data,
          hash: DateTime.now().millisecondsSinceEpoch.toString());

      return _localDb.put(currentData);
    }

    return Err(
        "Record '$key' not found. Use POST method to create new records.");
  }

  /// Deletes a record by its unique identifier.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the record to delete
  ///
  /// Returns:
  /// - [Ok] with `true` if the record was successfully deleted
  /// - [Err] with an error message if the key is invalid or deletion fails
  // ignore: non_constant_identifier_names
  static LocalDbResult<bool, String> Delete(String id) {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    return _localDb.delete(id);
  }

  /// Clear all data on the database.
  ///
  /// Returns:
  /// - [Ok] with `true` if the record was successfully deleted
  /// - [Err] with an error message if the key is invalid or deletion fails
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, String>> ClearData() async {
    return await _localDb.cleanDatabase();
  }

  /// Close database connection.
  // ignore: non_constant_identifier_names
  static LocalDbResult<void, String> Dispose() {
    return _localDb.dispose();
  }

  static LocalDbResult<bool, String> IsOpen() {
    return _localDb.isOpen();
  }

  // ignore: non_constant_identifier_names
  // static Future<LocalDbResult<bool, String>> ResetDatabase() async {
  //   return await LocalDbBridge.instance.clear();
  // }

  /// Validates that a map can be properly serialized to JSON.
  ///
  /// Parameters:
  /// - [map]: The map to validate
  ///
  /// Returns:
  /// `true` if the map can be successfully serialized, `false` otherwise
  static bool _isValidMap(dynamic map) {
    try {
      String jsonString = jsonEncode(map);
      jsonDecode(jsonString);
      return true;
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return false;
    }
  }

  /// Validates the format of a database record identifier.
  ///
  /// Checks that the ID:
  /// - Is at least 3 characters long
  /// - Contains only letters, numbers, hyphens, and underscores
  ///
  /// Parameters:
  /// - [text]: The ID to validate
  ///
  /// Returns:
  /// `true` if the ID is valid, `false` otherwise
  static bool _isValidId(String text) {
    RegExp regex = RegExp(r'^[a-zA-Z0-9_-]{3,}$');
    return regex.hasMatch(text);
  }
}
