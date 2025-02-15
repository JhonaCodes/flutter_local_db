import 'dart:convert';
import 'dart:developer';

import 'package:flutter_local_db/src/service/local_db_result.dart';

import 'bridge/local_db_bridge.dart';
import 'model/local_db_request_model.dart';

/// Main interface for the LocalDB library
/// Provides static methods for database operations with built-in validation
class LocalDB {
  /// Initializes the database with optional configuration
  /// @param config Optional database configuration (defaults to ConfigDBModel())
  static Future<void> init({required String localDbName}) async {
    await LocalDbBridge.instance.initialize(localDbName);
  }

  /// Creates a new record in the database
  /// @param key Unique identifier for the record (must be alphanumeric, min 9 chars)
  /// @param data Map containing the data to store
  /// @throws Exception if key is invalid
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbRequestModel, String>> Post(
      String key, Map<String, dynamic> data,
      {String? lastUpdate}) async {
    if (!_isValidId(key)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    if (!_isValidMap(data))
      return Err('The provided format data is invalid.\n$data');

    final verifyId = await GetById(key);

    if (verifyId.isOk) {
      return Err(
          "Cannot create new record: ID '$key' already exists. Use PUT method to update existing records.");
      ;
    }

    final model = LocalDbRequestModel(
      id: key,
      hash: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
    );

    return await LocalDbBridge.instance.post(model);
  }

  /// Retrieves all records from the local database
  ///
  /// Returns:
  ///   - Ok(List<LocalDbRequestModel>): List of records if successful. Empty list if no records found
  ///   - Err(String): Error message if the operation fails, particularly if a null pointer is returned from FFI
// ignore: non_constant_identifier_names
  static Future<LocalDbResult<List<LocalDbRequestModel>, String>>
      GetAll() async {
    return await LocalDbBridge.instance.getAll();
  }

  /// Retrieves a single record by its ID
  /// @param id Unique identifier of the record
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbRequestModel?, String>> GetById(
      String id) async {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }

    return await LocalDbBridge.instance.getById(id);
  }

  /// Updates an existing record
  /// @param id Unique identifier of the record to update
  /// @param data New data to store
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbRequestModel, String>> Put(
      String key, Map<String, dynamic> data) async {
    final verifyId = await GetById(key);

    if (verifyId.isOk) {
      final currentData = LocalDbRequestModel(
          id: key,
          data: data,
          hash: DateTime.now().millisecondsSinceEpoch.toString());

      return await LocalDbBridge.instance.put(currentData);
    }

    return Err(
        "Record '$key' not found. Use POST method to create new records.");
  }

  /// Deletes a record by its ID
  /// @param id Unique identifier of the record to delete
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, String>> Delete(String id) async {
    if (!_isValidId(id)) {
      return const Err(
          "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).");
    }
    return await LocalDbBridge.instance.delete(id);
  }

  //
  // /// Removes all records from the database
  // // ignore: non_constant_identifier_names
  // static Future<bool> Clean() async {
  //   return await LocalDataBaseNotifier.instanceDatabase.notifier.clean();
  // }
  //
  // /// Performs a complete reset of the database
  // // ignore: non_constant_identifier_names
  // static Future<bool> DeepClean() async {
  //   return await LocalDataBaseNotifier.instanceDatabase.notifier.deepClean();
  // }

  /// Calculates the size of a map in kilobytes
  /// @param map Map to calculate size for
  /// @return Size in KB with 3 decimal places
  static double _mapToKb(Map map) => double.parse(
      (utf8.encode(jsonEncode(map)).length / 1024).toStringAsFixed(3));

  /// Generates a hash from map values
  /// @param values Iterable of values to hash
  /// @return Hash code for the values
  static int _toHash(Iterable<dynamic> values) => Object.hashAll(values);

  /// Validates that a map can be properly serialized to JSON
  /// @param map Map to validate
  /// @return true if map can be serialized, false otherwise
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

  /// Validates ID format using regex
  /// Ensures ID is alphanumeric and at least 9 characters long
  /// @param text ID to validate
  /// @return true if ID is valid, false otherwise
  static bool _isValidId(String text) {
    RegExp regex = RegExp(r'^[a-zA-Z0-9_-]{3,}$');
    return regex.hasMatch(text);
  }
}
