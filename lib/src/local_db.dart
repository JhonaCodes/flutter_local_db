import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
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
  /// Initializes the local database with a specified name.
  ///
  /// This method must be called before performing any database operations.
  ///
  /// Parameters:
  /// - [localDbName]: A unique name for the local database instance
  ///
  /// Throws an exception if initialization fails
  static Future<void> init({required String localDbName}) async {
    await LocalDbBridge.instance.initialize(localDbName);
  }

  /// Avoid to use on production.
  ///
  static Future<void> initForTesting(
      {required String localDbName, required String binaryPath}) async {
    await LocalDbBridge.instance.initForTesting(localDbName, binaryPath);
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
  static Future<LocalDbResult<LocalDbRequestModel, String>> Post(
      String key, Map<String, dynamic> data,
      {String? lastUpdate, bool withIsolate = false}) async {
    if (!_isValidId(key)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    if (!_isValidMap(data)) {
      return Err('The provided format data is invalid.\n$data');
    }

    final verifyId = await GetById(key);

    if (verifyId.isOk) {
      return Err(
          "Cannot create new record: ID '$key' already exists. Use PUT method to update existing records.");
    }

    final model = LocalDbRequestModel(
      id: key,
      hash: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
    );

    if (withIsolate) return await compute(LocalDbBridge.instance.post, model);

    return await LocalDbBridge.instance.post(model);
  }

  /// Retrieves all records from the local database.
  ///
  /// Returns:
  /// - [Ok] with a list of [LocalDbRequestModel]
  ///   - Returns an empty list if no records are found
  /// - [Err] with an error message if the operation fails
  static Future<LocalDbResult<List<LocalDbRequestModel>, String>>
      // ignore: non_constant_identifier_names
      GetAll({bool withIsolate = false}) async {
    if (withIsolate) {
      return await compute((msm) => LocalDbBridge.instance.getAll(), null);
    }

    return await LocalDbBridge.instance.getAll();
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
  static Future<LocalDbResult<LocalDbRequestModel?, String>> GetById(String id,
      {bool withIsolate = false}) async {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    if (withIsolate) {
      return await compute(LocalDbBridge.instance.getById, id);
    }

    return await LocalDbBridge.instance.getById(id);
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
  static Future<LocalDbResult<LocalDbRequestModel, String>> Put(
      String key, Map<String, dynamic> data,
      {bool withIsolate = false}) async {
    final verifyId = await GetById(key);

    if (verifyId.isOk) {
      final currentData = LocalDbRequestModel(
          id: key,
          data: data,
          hash: DateTime.now().millisecondsSinceEpoch.toString());

      if (withIsolate) {
        return await compute(LocalDbBridge.instance.put, currentData);
      }

      return await LocalDbBridge.instance.put(currentData);
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
  static Future<LocalDbResult<bool, String>> Delete(String id,
      {bool withIsolate = false}) async {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    if (withIsolate) {
      return await compute(LocalDbBridge.instance.delete, id);
    }
    return await LocalDbBridge.instance.delete(id);
  }

  /// Clear all data on the database.
  ///
  /// Returns:
  /// - [Ok] with `true` if the record was successfully deleted
  /// - [Err] with an error message if the key is invalid or deletion fails
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, String>> ClearData() async {
    return await LocalDbBridge.instance.cleanDatabase();
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
