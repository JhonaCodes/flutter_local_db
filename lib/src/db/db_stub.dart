import 'dart:developer';

import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

import 'db_interface.dart';

/// Stub implementation of DataBaseServiceInterface that serves as a placeholder
/// to prevent web-specific code from being imported in device environments.
/// All methods throw UnimplementedError to ensure proper implementation is used.
class DataBaseVM implements DataBaseServiceInterface {
  /// Stub for database initialization
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<bool> init(ConfigDBModel config) {
    throw UnimplementedError();
  }

  /// Stub for cleaning database
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<bool> clean({bool secure = false}) {
    throw UnimplementedError();
  }

  /// Stub for deleting records
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<bool> delete(String id, {bool secure = false}) {
    throw UnimplementedError();
  }

  /// Stub for retrieving records
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<List<DataLocalDBModel>> get(
      {int limit = 20, int offset = 0, bool secure = false}) {
    throw UnimplementedError();
  }

  /// Stub for creating records
  /// Logs "From db_stub" for debugging purposes
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false}) {
    log("From db_stub");
    throw UnimplementedError();
  }

  /// Stub for retrieving single record
  /// Logs "Error" for debugging purposes
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) {
    log("Error");
    throw UnimplementedError();
  }

  /// Stub for updating records
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false}) {
    throw UnimplementedError();
  }

  /// Stub for deep cleaning database
  /// Throws UnimplementedError as this is a bypass class
  @override
  Future<bool> deepClean({bool secure = false}) {
    throw UnimplementedError();
  }
}
