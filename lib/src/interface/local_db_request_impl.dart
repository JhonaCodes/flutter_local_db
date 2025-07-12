import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/local_db_error_model.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';

/// Abstract class that defines the core database operations interface.
/// This implementation serves as a bridge between the Dart layer and the Rust backend.
@protected
abstract class LocalSbRequestImpl {
  /// Creates a new record in the database.
  ///
  /// Takes a [LocalDbModel] containing the data to be stored.
  /// Returns a [Result] that either contains the created record
  /// or an error message if the operation fails.
  ///
  /// Note: Implemented as Future for upcoming async Rust implementation.
  Future<Result<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model);

  /// Updates an existing record in the database.
  ///
  /// Takes a [LocalDbModel] containing the updated data.
  /// Returns a [Result] that either contains the updated record
  /// or an error message if the operation fails.
  Future<Result<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model);

  /// Retrieves all records from the database.
  ///
  /// Returns a [Result] that either contains a list of all records
  /// or an error message if the operation fails.
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll();

  /// Retrieves a single record by its ID.
  ///
  /// Takes an [id] string to identify the record.
  /// Returns a [Result] that either contains the requested record
  /// (or null if not found) or an error message if the operation fails.
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id);

  /// Deletes a record from the database.
  ///
  /// Takes an [id] string to identify the record to delete.
  /// Returns a [Result] that either contains a boolean indicating
  /// success (true) or failure (false), or an error message if the operation fails.
  Future<Result<bool, ErrorLocalDb>> delete(String id);

  /// Cleans the entire database.
  ///
  Future<Result<bool, ErrorLocalDb>> cleanDatabase();
}
