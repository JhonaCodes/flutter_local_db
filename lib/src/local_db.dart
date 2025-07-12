import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/log.dart';
import 'database/database_interface.dart';
import 'database/database_manager.dart';
import 'database/database_native.dart';
import 'model/local_db_error_model.dart';
import 'model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';
/// A comprehensive local database management utility.
///
/// Provides static methods for performing CRUD (Create, Read, Update, Delete)
/// operations on a local database with robust validation and error handling.
///
/// Uses on-demand connections without singleton complexity for better
/// hot restart resilience and cleaner architecture.
///
/// Automatically detects platform and uses:
/// - FFI Rust implementation for mobile/desktop platforms
/// - IndexedDB implementation for web platform
class LocalDB {
  static String? _databaseName;

  /// Get the current database name
  static String? get currentDatabaseName => DatabaseManager.currentDatabaseName;

  /// Normalize database name for validation (handle .db extension and paths)
  static String _normalizeDatabaseName(String dbName) {
    // Extract just the filename if it's a path
    String normalized = dbName.split('/').last.split('\\').last;
    
    // Remove .db extension for validation
    if (normalized.endsWith('.db')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }
    
    return normalized.toLowerCase();
  }

  /// Ensure database is configured and execute operation with Result types
  static Future<Result<T, ErrorLocalDb>> _ensureDatabaseAndExecute<T>(
    Future<Result<T, ErrorLocalDb>> Function(DatabaseInterface db) operation,
  ) async {
    if (_databaseName == null) {
      return Err(ErrorLocalDb.databaseError(
        'Database not initialized. Call LocalDB.init() first.',
      ));
    }

    return await DatabaseManager.execute(_databaseName!, operation);
  }

  /// Validate input parameters for database operations
  static Result<LocalDbModel, ErrorLocalDb>? _validateInput(
    String key, 
    Map<String, dynamic>? data,
  ) {
    Log.d('LocalDB._validateInput: Validating key: "$key", data keys: ${data?.keys.toList()}');
    
    if (!_isValidId(key)) {
      Log.e('LocalDB._validateInput: Invalid key format: "$key"');
      return Err(ErrorLocalDb.serializationError(
        "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).",
      ));
    }

    if (data != null && !_isValidMap(data)) {
      Log.e('LocalDB._validateInput: Invalid data format, failed JSON serialization');
      return Err(ErrorLocalDb.serializationError(
        'The provided format data is invalid.\n$data',
      ));
    }

    Log.d('LocalDB._validateInput: Validation successful');
    return null; // No validation errors
  }

  /// Initializes the local database with a specified name.
  ///
  /// This method sets the database name for subsequent operations.
  /// The actual connection is established on-demand for each operation.
  ///
  /// Parameters:
  /// - [localDbName]: A unique name for the local database instance
  static Future<void> init({required String localDbName}) async {
    if (!_isValidId(_normalizeDatabaseName(localDbName))) {
      throw ArgumentError(
        'Invalid database name format. Name must be at least 3 characters long '
        'and can only contain letters, numbers, hyphens (-) and underscores (_).',
      );
    }

    _databaseName = localDbName;
    Log.i('✅ LocalDB configured for database: $localDbName');
    
    // Test connection to verify database can be accessed
    final result = await DatabaseManager.execute(_databaseName!, (db) async {
      Log.i('🔍 Verified database connectivity on platform: ${db.platformName}');
      return Ok(true);
    });
    
    result.when(
      ok: (_) => Log.i('Database initialization completed successfully'),
      err: (error) => throw Exception('Failed to initialize database: $error'),
    );
  }

  /// Avoid to use on production.
  ///
  static Future<void> initForTesting({
    required String localDbName,
    required String binaryPath,
  }) async {
    if (!kIsWeb) {
      final db = DatabaseNative.instance;
      await db.initForTesting(localDbName, binaryPath);
    }
  }

  /// Creates a new record in the database.
  ///
  /// Validates the key and data before attempting to create the record.
  /// Uses on-demand connection for better hot restart resilience.
  ///
  /// Parameters:
  /// - [key]: A unique identifier for the record
  /// - [data]: A map containing the data to be stored
  /// - [lastUpdate]: Optional timestamp for the record (not used in this implementation)
  ///
  /// Returns:
  /// - [Ok] with the created [LocalDbModel] if successful
  /// - [Err] with an error message if validation or creation fails
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel, ErrorLocalDb>> Post(
    String key,
    Map<String, dynamic> data, {
    String? lastUpdate,
  }) async {
    if (!_isValidId(key)) {
      return Err(ErrorLocalDb.serializationError(
        "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).",
      ));
    }

    if (!_isValidMap(data)) {
      return Err(ErrorLocalDb.serializationError(
        'The provided format data is invalid.\n$data',
      ));
    }

    final verifyId = await GetById(key);

    return verifyId.when(
      ok: (existingModel) async {
        if (existingModel != null) {
          return Err(ErrorLocalDb.databaseError(
            "Cannot create new record: ID '$key' already exists. Use PUT method to update existing records.",
          ));
        }

        final model = LocalDbModel(
          id: key,
          hash: DateTime.now().millisecondsSinceEpoch.toString(),
          data: data,
        );

        return await DatabaseManager.execute(_databaseName!, (db) => db.post(model));
      },
      err: (error) => Err(error),
    );
  }

  /// Retrieves all records from the local database.
  ///
  /// Returns:
  /// - [Ok] with a list of [LocalDbModel]
  ///   - Returns an empty list if no records are found
  /// - [Err] with an error message if the operation fails
  static Future<Result<List<LocalDbModel>, ErrorLocalDb>>
  // ignore: non_constant_identifier_names
  GetAll() async {
    return await DatabaseManager.execute(_databaseName!, (db) => db.getAll());
  }

  /// Retrieves a single record by its unique identifier.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the record to retrieve
  ///
  /// Returns:
  /// - [Ok] with the [LocalDbModel] if found
  /// - [Ok] with `null` if no record matches the ID
  /// - [Err] with an error message if the key is invalid
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel?, ErrorLocalDb>> GetById(
    String id,
  ) async {
    if (!_isValidId(id)) {
      return Err(ErrorLocalDb.validationError(
        "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).",
      ));
    }

    return await DatabaseManager.execute(_databaseName!, (db) => db.getById(id));
  }

  /// Updates an existing record in the database.
  ///
  /// Parameters:
  /// - [key]: The unique identifier of the record to update
  /// - [data]: The new data to store
  ///
  /// Returns:
  /// - [Ok] with the updated [LocalDbModel] if successful
  /// - [Err] with an error message if the record does not exist
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel, ErrorLocalDb>> Put(
    String key,
    Map<String, dynamic> data,
  ) async {
    final verifyId = await GetById(key);

    return verifyId.when(
      ok: (existingModel) async {
        if (existingModel == null) {
          return Err(ErrorLocalDb.notFound(
            "Record '$key' not found. Use POST method to create new records.",
          ));
        }

        final model = LocalDbModel(
          id: key,
          data: data,
          hash: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        return await DatabaseManager.execute(_databaseName!, (db) => db.put(model));
      },
      err: (error) => Err(error),
    );
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
  static Future<Result<bool, ErrorLocalDb>> Delete(String id) async {
    if (!_isValidId(id)) {
      return Err(ErrorLocalDb.serializationError(
        "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).",
      ));
    }

    return await DatabaseManager.execute(_databaseName!, (db) => db.delete(id));
  }

  /// Clear all data on the database.
  ///
  /// Returns:
  /// - [Ok] with `true` if all data was successfully cleared
  /// - [Err] with an error message if clearing fails
  // ignore: non_constant_identifier_names
  static Future<Result<bool, ErrorLocalDb>> ClearData() async {
    return await DatabaseManager.execute(_databaseName!, (db) => db.cleanDatabase());
  }

  /// Closes the database connection and frees all resources.
  /// This should be called during hot restart or app termination to prevent crashes.
  /// Works on both mobile/desktop (FFI) and web (IndexedDB) platforms.
  ///
  /// Note: With the new on-demand connection model, this method is less critical
  /// as connections are automatically closed after each operation.
  // ignore: non_constant_identifier_names
  static Future<void> CloseDatabase() async {
    if (_databaseName != null) {
      final result = await DatabaseManager.execute(_databaseName!, (db) async {
        await db.closeDatabase();
        return Ok(true);
      });
      result.when(
        ok: (_) => Log.i('Database closed successfully'),
        err: (error) => Log.e('Failed to close database: $error'),
      );
    }
  }

  /// Validates if the current database connection is still valid.
  /// Useful for debugging connection issues.
  /// Works on both mobile/desktop (FFI) and web (IndexedDB) platforms.
  ///
  /// Returns:
  /// - `true` if the connection is valid
  /// - `false` if the connection is invalid or null
  // ignore: non_constant_identifier_names
  static Future<bool> IsConnectionValid() async {
    if (_databaseName == null) return false;
    
    final result = await DatabaseManager.execute(_databaseName!, (db) async {
      return Ok(await db.ensureConnectionValid());
    });
    
    return result.when(
      ok: (isValid) => isValid,
      err: (error) {
        Log.e('Connection validation failed: $error');
        return false;
      },
    );
  }

  // ignore: non_constant_identifier_names
  // static Future<Result<bool, String>> ResetDatabase() async {
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
      Log.d('LocalDB._isValidMap: Attempting to serialize map with ${map is Map ? map.keys.length : 0} entries');
      String jsonString = jsonEncode(map);
      jsonDecode(jsonString);
      Log.d('LocalDB._isValidMap: JSON serialization successful, length: ${jsonString.length}');
      return true;
    } catch (error, stackTrace) {
      Log.e(
        'LocalDB._isValidMap: JSON validation failed - $error',
        error: error,
        stackTrace: stackTrace,
      );
      Log.e('LocalDB._isValidMap: Problematic data: $map');
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
