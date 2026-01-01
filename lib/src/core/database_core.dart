// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            DATABASE CORE                                    ║
// ║                      Core Database Operations Engine                         ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: database_core.dart                                                  ║
// ║  Purpose: Core database operations and low-level FFI interactions          ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides low-level database operations using FFI to interact with       ║
// ║    the Rust LMDB backend. Handles memory management, error handling,       ║
// ║    and type conversions between Dart and native code.                      ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Low-level database operations                                           ║
// ║    • Automatic memory management                                             ║
// ║    • Type-safe FFI interactions                                              ║
// ║    • Comprehensive error handling                                            ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'dart:convert';
import '../models/local_db_result.dart';
import '../models/local_db_error.dart';
import '../models/local_db_model.dart';
import 'ffi_bindings.dart';

import 'package:logger_rs/logger_rs.dart';

/// Parses Rust AppResponse format into normalized response map.
///
/// Rust returns responses in format: {"Ok": "data"} or {"DatabaseError": "msg"}
/// This converts them to: {"status": "ok", "data": ...} or {"status": "error", "message": ...}
Map<String, dynamic> _parseRustResponse(Map<String, dynamic> response) {
  return switch (response) {
    {'Ok': final data} => {'status': 'ok', 'data': data},
    {'NotFound': final msg} => {'status': 'not_found', 'message': msg},
    {'DatabaseError': final msg} => {'status': 'error', 'message': msg},
    {'SerializationError': final msg} => {'status': 'error', 'message': msg},
    {'ValidationError': final msg} => {
      'status': 'validation_error',
      'message': msg,
    },
    {'BadRequest': final msg} => {'status': 'bad_request', 'message': msg},
    _ => response, // Already in expected format or unknown
  };
}

/// Core database operations engine
///
/// Provides low-level database operations using FFI to interact with
/// the Rust LMDB backend. Handles all the complexity of memory management,
/// pointer safety, and type conversions.
class DatabaseCore {
  final LocalDbBindings _bindings;
  final Pointer<Void> _dbHandle;
  bool _isClosed = false;

  DatabaseCore._(this._bindings, this._dbHandle);

  /// Creates a new database instance
  ///
  /// Initializes the database at the specified path using the provided
  /// FFI bindings. The database will be created if it doesn't exist.
  ///
  /// Parameters:
  /// - [bindings] - FFI function bindings to the native library
  /// - [path] - File system path where the database should be stored
  ///
  /// Returns:
  /// - [Ok] with [DatabaseCore] instance on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = DatabaseCore.create(bindings, '/path/to/db');
  /// result.when(
  ///   ok: (db) => print('Database created successfully'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static LocalDbResult<DatabaseCore, ErrorLocalDb> create(
    LocalDbBindings bindings,
    String path,
  ) {
    Log.i('Creating database at: $path');

    if (path.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path cannot be empty',
          context: 'path_validation',
        ),
      );
    }

    final pathPtr = FfiUtils.toCString(path);

    try {
      final dbHandle = bindings.createDb(pathPtr);

      if (FfiUtils.isNull(dbHandle)) {
        Log.e('Database creation returned null handle');
        return Err(
          ErrorLocalDb.initialization(
            'Failed to create database - null handle returned',
            context: path,
          ),
        );
      }

      Log.i('Database created successfully with handle: $dbHandle');
      return Ok(DatabaseCore._(bindings, dbHandle));
    } catch (e, stackTrace) {
      Log.e('Exception during database creation: $e');
      return Err(
        ErrorLocalDb.initialization(
          'Exception during database creation',
          context: path,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(pathPtr);
    }
  }

  /// Stores a key-value pair in the database (REST: PUT)
  ///
  /// Serializes the data to JSON and stores it with the specified key.
  /// The key must be a non-empty string, and the data must be JSON serializable.
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the record
  /// - [data] - Data to store (must be JSON serializable)
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] containing the stored data on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.put('user_123', {'name': 'John', 'age': 30});
  /// result.when(
  ///   ok: (model) => print('Stored: ${model.id}'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<LocalDbModel, ErrorLocalDb> put(
    String key,
    Map<String, dynamic> data,
  ) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('Storing data with key: $key');

    // Validate inputs
    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    // Create model and serialize to JSON
    final model = LocalDbModel(id: key, data: data);
    final jsonString = model.toJson();
    final jsonPtr = FfiUtils.toCString(jsonString);

    try {
      // Call Rust's push_data function
      final resultPtr = _bindings.pushData(_dbHandle, jsonPtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e('Native put operation returned null');
        return Err(
          ErrorLocalDb.databaseError(
            'Native put operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      // Parse the response from Rust
      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          Log.d('Data stored successfully for key: $key');
          return Ok(model);
        } else {
          final errorMsg = response['message'] ?? 'Put operation failed';
          Log.e('Put operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('Exception during put operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during put operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(jsonPtr);
    }
  }

  /// Creates a new record in the database (REST: POST)
  ///
  /// Similar to put but semantically intended for creating new records.
  /// Will fail if the record already exists.
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the record
  /// - [data] - Data to store (must be JSON serializable)
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] containing the stored data on success
  /// - [Err] with error if record already exists or operation fails
  ///
  /// Example:
  /// ```dart
  /// final result = db.post('user_123', {'name': 'John', 'age': 30});
  /// result.when(
  ///   ok: (model) => print('Created: ${model.id}'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<LocalDbModel, ErrorLocalDb> post(
    String key,
    Map<String, dynamic> data,
  ) {
    // For now, post is the same as put
    // In the future, we could add existence checking
    return put(key, data);
  }

  /// Updates an existing record in the database
  ///
  /// Updates a record that must already exist in the database.
  /// Will fail if the record doesn't exist.
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the record
  /// - [data] - Updated data (must be JSON serializable)
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] containing the updated data on success
  /// - [Err] with not found error if record doesn't exist
  ///
  /// Example:
  /// ```dart
  /// final result = db.update('user_123', {'name': 'Jane', 'age': 31});
  /// result.when(
  ///   ok: (model) => print('Updated: ${model.id}'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<LocalDbModel, ErrorLocalDb> update(
    String key,
    Map<String, dynamic> data,
  ) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('Updating data with key: $key');

    // Validate inputs
    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    // Create model and serialize to JSON
    final model = LocalDbModel(id: key, data: data);
    final jsonString = model.toJson();
    final jsonPtr = FfiUtils.toCString(jsonString);

    try {
      // Call Rust's update_data function
      final resultPtr = _bindings.updateData(_dbHandle, jsonPtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e('Native update operation returned null');
        return Err(
          ErrorLocalDb.databaseError(
            'Native update operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      // Parse the response from Rust
      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          Log.d('Data updated successfully for key: $key');
          return Ok(model);
        } else if (response['status'] == 'not_found') {
          Log.e('Record not found for update: $key');
          return Err(
            ErrorLocalDb.notFound('Record not found for update', context: key),
          );
        } else {
          final errorMsg = response['message'] ?? 'Update operation failed';
          Log.e('Update operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('Exception during update operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during update operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(jsonPtr);
    }
  }

  /// Resets the database with a new name
  ///
  /// Completely resets the database, removing all data and creating
  /// a new database with the specified name.
  ///
  /// Parameters:
  /// - [name] - New name for the database
  ///
  /// Returns:
  /// - [Ok] with void on successful reset
  /// - [Err] with error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.reset('new_database');
  /// result.when(
  ///   ok: (_) => print('Database reset'),
  ///   err: (error) => print('Reset failed: $error'),
  /// );
  /// ```
  LocalDbResult<void, ErrorLocalDb> reset(String name) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.w('Resetting database with new name: $name');

    if (name.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database name cannot be empty',
          context: 'reset_operation',
        ),
      );
    }

    final namePtr = FfiUtils.toCString(name);

    try {
      // Call Rust's reset_database function
      final resultPtr = _bindings.resetDatabase(_dbHandle, namePtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e('Native reset operation returned null');
        return Err(ErrorLocalDb.databaseError('Native reset operation failed'));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(ErrorLocalDb.databaseError('Failed to convert response'));
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          Log.i('Database reset successfully');
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Reset operation failed';
          Log.e('Reset operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      Log.e(' Exception during reset operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during reset operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(namePtr);
    }
  }

  /// Retrieves a value by key from the database
  ///
  /// Looks up the record with the specified key and deserializes
  /// the stored JSON data into a [LocalDbModel].
  ///
  /// Parameters:
  /// - [key] - The key to look up
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] if the record exists
  /// - [Err] with not found error if the key doesn't exist
  /// - [Err] with other error types for various failures
  ///
  /// Example:
  /// ```dart
  /// final result = db.get('user_123');
  /// result.when(
  ///   ok: (model) => print('Found: ${model.data['name']}'),
  ///   err: (error) => print('Not found or error: $error'),
  /// );
  /// ```
  LocalDbResult<LocalDbModel, ErrorLocalDb> get(String key) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d(' Getting data for key: $key');

    // Validate key
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      // Call Rust's get_by_id function
      final resultPtr = _bindings.getById(_dbHandle, keyPtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.d(' Key not found: $key');
        return Err(ErrorLocalDb.notFound('Record not found', context: key));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);

      if (responseStr == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null response from database',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          final jsonData = response['data'];
          if (jsonData != null) {
            // Data from Rust is already a JSON string, use it directly
            final jsonString = jsonData is String
                ? jsonData
                : jsonEncode(jsonData);
            final model = LocalDbModel.fromJson(jsonString);
            Log.d(' Data retrieved successfully for key: $key');
            return Ok(model);
          } else {
            return Err(ErrorLocalDb.notFound('Record not found', context: key));
          }
        } else if (response['status'] == 'not_found') {
          Log.d(' Key not found: $key');
          return Err(ErrorLocalDb.notFound('Record not found', context: key));
        } else {
          final errorMsg = response['message'] ?? 'Get operation failed';
          Log.e(' Get operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        Log.e(' Failed to parse response for key $key: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e(' Exception during get operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during get operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  /// Deletes a record by key from the database
  ///
  /// Removes the record with the specified key from the database.
  /// Returns success even if the key doesn't exist.
  ///
  /// Parameters:
  /// - [key] - The key to delete
  ///
  /// Returns:
  /// - [Ok] with void on successful deletion
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.delete('user_123');
  /// result.when(
  ///   ok: (_) => print('Deleted successfully'),
  ///   err: (error) => print('Delete failed: $error'),
  /// );
  /// ```
  LocalDbResult<void, ErrorLocalDb> delete(String key) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d(' Deleting data for key: $key');

    // Validate key
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      // Call Rust's delete_by_id function
      final resultPtr = _bindings.deleteById(_dbHandle, keyPtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e(' Native delete operation returned null');
        return Err(
          ErrorLocalDb.databaseError(
            'Native delete operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          Log.d(' Data deleted successfully for key: $key');
          return const Ok(null);
        } else if (response['status'] == 'not_found') {
          // Still return success for delete even if not found
          Log.d(' Key not found but returning success: $key');
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Delete operation failed';
          Log.e(' Delete operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e(' Exception during delete operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during delete operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  /// Retrieves all data from the database
  ///
  /// Returns a map of all key-value pairs currently stored in the database.
  /// For large databases, this operation may be expensive.
  ///
  /// Returns:
  /// - [Ok] with map of all data on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.getAll();
  /// result.when(
  ///   ok: (data) => print('Found ${data.length} records'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb> getAll() {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d(' Getting all data from database');

    try {
      final resultPtr = _bindings.getAll(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        Log.d(' No data found or operation failed');
        return const Ok({});
      }

      final jsonString = FfiUtils.fromCString(resultPtr);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null JSON string for all data',
          ),
        );
      }

      try {
        final rawResponse = json.decode(jsonString) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          final data = response['data'];
          // Data from Rust is a JSON string containing the array
          final List<dynamic> items = data is String
              ? json.decode(data) as List<dynamic>
              : (data is List ? data : []);

          final result = <String, LocalDbModel>{};
          for (final item in items) {
            try {
              // Each item might be a Map or a JSON string
              final jsonString = item is String ? item : jsonEncode(item);
              final model = LocalDbModel.fromJson(jsonString);
              result[model.id] = model;
            } catch (e) {
              Log.w(' Failed to deserialize record: $e');
            }
          }
          Log.d(' Retrieved ${result.length} records from database');
          return Ok(result);
        } else {
          final errorMsg = response['message'] ?? 'GetAll operation failed';
          Log.e(' GetAll operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      Log.e(' Exception during getAll operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during getAll operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Clears all data from the database
  ///
  /// Removes all records from the database. This operation cannot be undone.
  /// Use with caution in production environments.
  ///
  /// Returns:
  /// - [Ok] with void on successful clear
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.clear();
  /// result.when(
  ///   ok: (_) => print('Database cleared'),
  ///   err: (error) => print('Clear failed: $error'),
  /// );
  /// ```
  LocalDbResult<void, ErrorLocalDb> clear() {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.w(' Clearing all data from database');

    try {
      // Call Rust's clear_all_records function
      final resultPtr = _bindings.clearAllRecords(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e(' Native clear operation returned null');
        return Err(ErrorLocalDb.databaseError('Native clear operation failed'));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(ErrorLocalDb.databaseError('Failed to convert response'));
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          Log.i(' Database cleared successfully');
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Clear operation failed';
          Log.e(' Clear operation failed: $errorMsg');
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        Log.e('Failed to parse response: $e');
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      Log.e(' Exception during clear operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during clear operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Closes the database and releases resources
  ///
  /// Properly closes the database connection and releases all associated
  /// resources. After calling this method, the database instance cannot be used.
  ///
  /// Example:
  /// ```dart
  /// db.close();
  /// print('Database closed');
  /// ```
  void close() {
    if (_isClosed) {
      Log.w(' Attempted to close already closed database');
      return;
    }

    Log.i(' Closing database');

    try {
      // Call Rust's close_database function
      final resultPtr = _bindings.closeDatabase(_dbHandle);

      if (FfiUtils.isNotNull(resultPtr)) {
        final responseStr = FfiUtils.fromCString(resultPtr);
        if (responseStr != null) {
          try {
            final rawResponse =
                json.decode(responseStr) as Map<String, dynamic>;
            final response = _parseRustResponse(rawResponse);
            if (response['status'] == 'ok') {
              Log.i(' Database closed successfully');
            } else {
              Log.w(' Database close had issues: ${response['message']}');
            }
          } catch (e) {
            Log.w(' Failed to parse close response: $e');
          }
        }
      }

      _isClosed = true;
    } catch (e) {
      Log.e(' Exception during database close: $e');
    }
  }

  /// Checks if the database is closed
  bool get isClosed => _isClosed;

  /// Validates a key for database operations
  LocalDbResult<void, ErrorLocalDb> _validateKey(String key) {
    if (key.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Key cannot be empty',
          context: 'key_validation',
        ),
      );
    }

    if (key.length > FfiConstants.maxKeyLength) {
      return Err(
        ErrorLocalDb.validationError(
          'Key exceeds maximum length (${FfiConstants.maxKeyLength} bytes)',
          context: 'key: $key',
        ),
      );
    }

    return const Ok(null);
  }

  /// Validates key and data for storage operations
  LocalDbResult<void, ErrorLocalDb> _validateKeyAndData(
    String key,
    Map<String, dynamic> data,
  ) {
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return keyValidation;
    }

    try {
      final jsonString = jsonEncode(data);
      if (jsonString.length > FfiConstants.maxValueSize) {
        return Err(
          ErrorLocalDb.validationError(
            'Data exceeds maximum size (${FfiConstants.maxValueSize} bytes)',
            context: 'key: $key, size: ${jsonString.length}',
          ),
        );
      }
    } catch (e) {
      return Err(
        ErrorLocalDb.validationError(
          'Data is not JSON serializable',
          context: 'key: $key',
          cause: e,
        ),
      );
    }

    return const Ok(null);
  }
}
