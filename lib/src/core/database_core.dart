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
    Log.i('🔧 Creating database at: $path');

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
        Log.e('❌ Database creation returned null handle');
        return Err(
          ErrorLocalDb.initialization(
            'Failed to create database - null handle returned',
            context: path,
          ),
        );
      }

      Log.i('✅ Database created successfully with handle: $dbHandle');
      return Ok(DatabaseCore._(bindings, dbHandle));
    } catch (e, stackTrace) {
      Log.e('💥 Exception during database creation: $e');
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

  /// Stores a key-value pair in the database
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

    Log.d('💾 Storing data with key: $key');

    // Validate inputs
    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    // Create model and serialize to JSON
    final model = LocalDbModel(id: key, data: data);
    final jsonString = model.toJson();

    final keyPtr = FfiUtils.toCString(key);
    final valuePtr = FfiUtils.toCString(jsonString);

    try {
      final result = _bindings.put(_dbHandle, keyPtr, valuePtr);

      if (result == FfiConstants.success) {
        Log.d('✅ Data stored successfully for key: $key');
        return Ok(model);
      } else {
        Log.e('❌ Native put operation failed for key: $key');
        return Err(
          ErrorLocalDb.databaseError(
            'Native put operation failed',
            context: key,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during put operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during put operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
      FfiUtils.freeDartString(valuePtr);
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

    Log.d('🔍 Getting data for key: $key');

    // Validate key
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      final resultPtr = _bindings.get(_dbHandle, keyPtr);

      if (FfiUtils.isNull(resultPtr)) {
        Log.d('ℹ️ Key not found: $key');
        return Err(ErrorLocalDb.notFound('Record not found', context: key));
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null JSON string from database',
            context: key,
          ),
        );
      }

      try {
        final model = LocalDbModel.fromJson(jsonString);
        Log.d('✅ Data retrieved successfully for key: $key');
        return Ok(model);
      } catch (e) {
        Log.e('❌ JSON deserialization failed for key $key: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to deserialize JSON data',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during get operation: $e');
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

    Log.d('🗑️ Deleting data for key: $key');

    // Validate key
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      final result = _bindings.delete(_dbHandle, keyPtr);

      if (result == FfiConstants.success) {
        Log.d('✅ Data deleted successfully for key: $key');
        return const Ok(null);
      } else {
        Log.e('❌ Native delete operation failed for key: $key');
        return Err(
          ErrorLocalDb.databaseError(
            'Native delete operation failed',
            context: key,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during delete operation: $e');
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

  /// Checks if a key exists in the database
  ///
  /// Performs a fast existence check without retrieving the actual data.
  ///
  /// Parameters:
  /// - [key] - The key to check
  ///
  /// Returns:
  /// - [Ok] with true if the key exists
  /// - [Ok] with false if the key doesn't exist
  /// - [Err] with error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.exists('user_123');
  /// result.when(
  ///   ok: (exists) => print('Key exists: $exists'),
  ///   err: (error) => print('Check failed: $error'),
  /// );
  /// ```
  LocalDbResult<bool, ErrorLocalDb> exists(String key) {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('🔍 Checking existence for key: $key');

    // Validate key
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      final result = _bindings.exists(_dbHandle, keyPtr);
      final exists = result == FfiConstants.success;

      Log.d('✅ Existence check completed for key $key: $exists');
      return Ok(exists);
    } catch (e, stackTrace) {
      Log.e('💥 Exception during exists operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during exists operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  /// Retrieves all keys from the database
  ///
  /// Returns a list of all keys currently stored in the database.
  /// For large databases, this operation may be expensive.
  ///
  /// Returns:
  /// - [Ok] with list of all keys on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.getAllKeys();
  /// result.when(
  ///   ok: (keys) => print('Found ${keys.length} keys'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<List<String>, ErrorLocalDb> getAllKeys() {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('📋 Getting all keys from database');

    try {
      final resultPtr = _bindings.getAllKeys(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        Log.d('ℹ️ No keys found or operation failed');
        return const Ok([]);
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError('Received null JSON string for keys'),
        );
      }

      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final keys = jsonList.cast<String>();

        Log.d('✅ Retrieved ${keys.length} keys from database');
        return Ok(keys);
      } catch (e) {
        Log.e('❌ Failed to decode keys JSON: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to decode keys JSON',
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during getAllKeys operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during getAllKeys operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
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

    Log.d('📦 Getting all data from database');

    try {
      final resultPtr = _bindings.getAll(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        Log.d('ℹ️ No data found or operation failed');
        return const Ok({});
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null JSON string for all data',
          ),
        );
      }

      try {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final result = <String, LocalDbModel>{};

        for (final entry in jsonMap.entries) {
          try {
            final model = LocalDbModel.fromJson(jsonEncode(entry.value));
            result[entry.key] = model;
          } catch (e) {
            Log.w('⚠️ Failed to deserialize record ${entry.key}: $e');
          }
        }

        Log.d('✅ Retrieved ${result.length} records from database');
        return Ok(result);
      } catch (e) {
        Log.e('❌ Failed to decode all data JSON: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to decode all data JSON',
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during getAll operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during getAll operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Gets database statistics
  ///
  /// Returns information about the database such as number of records,
  /// file size, and other metadata.
  ///
  /// Returns:
  /// - [Ok] with statistics map on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.getStats();
  /// result.when(
  ///   ok: (stats) => print('Records: ${stats['record_count']}'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  LocalDbResult<Map<String, dynamic>, ErrorLocalDb> getStats() {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('📊 Getting database statistics');

    try {
      final resultPtr = _bindings.getStats(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        Log.e('❌ Stats operation returned null');
        return Err(ErrorLocalDb.databaseError('Stats operation returned null'));
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null JSON string for stats',
          ),
        );
      }

      try {
        final stats = jsonDecode(jsonString) as Map<String, dynamic>;
        Log.d('✅ Retrieved database statistics');
        return Ok(stats);
      } catch (e) {
        Log.e('❌ Failed to decode stats JSON: $e');
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to decode stats JSON',
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during getStats operation: $e');
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during getStats operation',
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

    Log.w('⚠️ Clearing all data from database');

    try {
      final result = _bindings.clear(_dbHandle);

      if (result == FfiConstants.success) {
        Log.i('✅ Database cleared successfully');
        return const Ok(null);
      } else {
        Log.e('❌ Native clear operation failed');
        return Err(ErrorLocalDb.databaseError('Native clear operation failed'));
      }
    } catch (e, stackTrace) {
      Log.e('💥 Exception during clear operation: $e');
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
      Log.w('⚠️ Attempted to close already closed database');
      return;
    }

    Log.i('🔒 Closing database');

    try {
      _bindings.closeDb(_dbHandle);
      _isClosed = true;
      Log.i('✅ Database closed successfully');
    } catch (e) {
      Log.e('💥 Exception during database close: $e');
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
