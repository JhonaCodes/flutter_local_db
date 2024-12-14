import 'dart:convert';
import 'dart:developer';

import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';
import 'package:flutter_local_db/src/notifiers/queue_cache.dart';

import 'model/config_db_model.dart';

/// Main interface for the LocalDB library
/// Provides static methods for database operations with built-in validation
class LocalDB {
  /// Initializes the database with optional configuration
  /// @param config Optional database configuration (defaults to ConfigDBModel())
  static Future<void> init(
      {ConfigDBModel config = const ConfigDBModel()}) async =>
      await localDatabaseNotifier.value.init(config);

  /// Creates a new record in the database
  /// @param key Unique identifier for the record (must be alphanumeric, min 9 chars)
  /// @param data Map containing the data to store
  /// @throws Exception if key is invalid
  // ignore: non_constant_identifier_names
  static Future<void> Post(String key, Map<dynamic, dynamic> data) async {
    if (!_isValidId(key)) {
      throw Exception(
          "The provided key is invalid. Please ensure it contains only letters and numbers, with a minimum length of 9 characters.");
    }

    if (_isValidMap(data)) {
      final currentData = DataLocalDBModel(
        id: key,
        sizeKb: _mapToKb(data),
        hash: _toHash(data.values),
        data: data,
      );

      await queueCache.value.process(
              () async => await localDatabaseNotifier.value.post(currentData));
    }
  }

  /// Retrieves a list of records with pagination
  /// @param limit Maximum number of records to retrieve (default: 10)
  // ignore: non_constant_identifier_names
  static Future<List<DataLocalDBModel>> Get({int limit = 10}) async {
    return await localDatabaseNotifier.value.get(limit: limit);
  }

  /// Retrieves a single record by its ID
  /// @param id Unique identifier of the record
  // ignore: non_constant_identifier_names
  static Future<DataLocalDBModel> GetById(String id) async {
    return await localDatabaseNotifier.value.getById(id);
  }

  /// Updates an existing record
  /// @param id Unique identifier of the record to update
  /// @param data New data to store
  // ignore: non_constant_identifier_names
  static Future<DataLocalDBModel> Put(
      String id, Map<dynamic, dynamic> data) async {
    final mapData = DataLocalDBModel(
      id: id,
      sizeKb: _mapToKb(data),
      hash: data.hashCode,
      data: data,
    );

    return await localDatabaseNotifier.value.put(mapData);
  }

  /// Deletes a record by its ID
  /// @param id Unique identifier of the record to delete
  // ignore: non_constant_identifier_names
  static Future<bool> Delete(String id) async {
    return await localDatabaseNotifier.value.delete(id);
  }

  /// Removes all records from the database
  // ignore: non_constant_identifier_names
  static Future<bool> Clean() async {
    return await localDatabaseNotifier.value.clean();
  }

  /// Performs a complete reset of the database
  // ignore: non_constant_identifier_names
  static Future<bool> DeepClean() async {
    return await localDatabaseNotifier.value.deepClean();
  }

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
    RegExp regex = RegExp(r'^[a-zA-Z0-9-]{9,}$');
    return regex.hasMatch(text);
  }
}