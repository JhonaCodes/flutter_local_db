import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:web/web.dart' as web;
import 'db_interface.dart';

/// Web-specific implementation of DataBaseServiceInterface
/// Uses IndexedDB for browser-based storage operations
class DataBaseVM implements DataBaseServiceInterface {
  /// Initializes the web database using IndexedDB
  /// @param config Database configuration settings
  /// @return Future<bool> Success status of initialization
  @override
  Future<bool> init(ConfigDBModel config) async {
    // Sets default database name
    _databaseName.updateState("de");

    // Opens IndexedDB database with configured name
    web.window.indexedDB.open("${_databaseName.value}.dex");

    return false;
  }

  /// Gets paginated records from IndexedDB
  /// Not implemented yet
  @override
  Future<List<DataLocalDBModel>> get(
      {int limit = 20, int offset = 0, bool secure = false}) {
    throw UnimplementedError();
  }

  /// Creates a new record in IndexedDB
  /// Not implemented yet
  @override
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false}) {
    throw UnimplementedError();
  }

  /// Cleans the database
  /// Not implemented yet
  @override
  Future<bool> clean({bool secure = false}) {
    throw UnimplementedError();
  }

  /// Deletes the entire IndexedDB database
  /// @param id Identifier (not used in this implementation)
  /// @param secure Flag for secure operations (not used in this implementation)
  /// @return Future<bool> Always returns true after deletion
  @override
  Future<bool> delete(String id, {bool secure = false}) async {
    web.window.indexedDB.deleteDatabase(_databaseName.value);
    return true;
  }

  /// Gets a record by ID from IndexedDB
  /// Not implemented yet
  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) {
    throw UnimplementedError();
  }

  /// Updates a record in IndexedDB
  /// Not implemented yet
  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false}) {
    throw UnimplementedError();
  }

  /// Performs deep clean of IndexedDB
  /// Not implemented yet
  @override
  Future<bool> deepClean({bool secure = false}) {
    throw UnimplementedError();
  }
}

final _databaseName = ReactiveNotifier<String>(() => "");
