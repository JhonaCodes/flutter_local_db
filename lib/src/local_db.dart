import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:result_controller/result_controller.dart';

import 'database/database_manager.dart';
import 'model/local_db_error_model.dart';
import 'model/local_db_request_model.dart';

/// A comprehensive local database management utility.
///
/// Provides static methods for performing CRUD (Create, Read, Update, Delete)
/// operations on a local database with robust validation and error handling.
///
/// Uses a bridge pattern to abstract database interactions and provides
/// type-safe results using [LocalDbResult].
/// 
/// Automatically detects platform and uses:
/// - FFI Rust implementation for mobile/desktop platforms
/// - IndexedDB implementation for web platform
class LocalDB {
  static final Map<String, DatabaseManager> _managers = {};
  static String? _currentDbName;
  
  /// Gets the current database manager
  static Result<DatabaseManager, ErrorLocalDb> _getCurrentManager() {
    if (_currentDbName == null) {
      return Err(ErrorLocalDb.databaseError(
        'Database not initialized. Call LocalDB.init() first.'
      ));
    }
    
    final manager = _managers[_currentDbName!];
    if (manager == null) {
      return Err(ErrorLocalDb.databaseError(
        'Database manager not found for "$_currentDbName". Call LocalDB.init() first.'
      ));
    }
    
    return Ok(manager);
  }

  /// Initializes the local database with a specified name.
  ///
  /// This method must be called before performing any database operations.
  /// Automatically selects the appropriate implementation:
  /// - IndexedDB for web platforms
  /// - FFI Rust implementation for mobile/desktop platforms
  ///
  /// Parameters:
  /// - [localDbName]: A unique name for the local database instance
  ///
  /// Returns Result indicating success or failure
  static Future<Result<void, ErrorLocalDb>> init({required String localDbName}) async {
    if (!_isValidId(_normalizeDatabaseName(localDbName))) {
      return Err(ErrorLocalDb.validationError(
        'Invalid database name format. Name must be at least 3 characters long '
        'and can only contain letters, numbers, hyphens (-) and underscores (_).'
      ));
    }

    final managerResult = await DatabaseManager.create(localDbName);
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    _managers[localDbName] = managerResult.data;
    _currentDbName = localDbName;
    
    log('✅ LocalDB initialized for database: $localDbName');
    return Ok(());
  }

  /// Avoid to use on production.
  ///
  static Future<Result<void, ErrorLocalDb>> initForTesting({
    required String localDbName, 
    required String binaryPath
  }) async {
    if (kIsWeb) {
      return Err(ErrorLocalDb.validationError(
        'Testing with binary path is not supported on web platform'
      ));
    }
    
    final managerResult = await DatabaseManager.createForTesting(
      databaseName: localDbName,
      binaryPath: binaryPath
    );
    
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    _managers[localDbName] = managerResult.data;
    _currentDbName = localDbName;
    
    return Ok(());
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
  /// - [Ok] with the created [LocalDbModel] if successful
  /// - [Err] with an error message if:
  ///   - The key is invalid
  ///   - The data cannot be serialized
  ///   - A record with the same key already exists
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel, ErrorLocalDb>> Post(
      String key, Map<String, dynamic> data,
      {String? lastUpdate}) async {
    
    final validationError = _validateInput(key, data);
    if (validationError != null) {
      return validationError;
    }
    
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    final manager = managerResult.data;
    
    // Check if record already exists
    final existingRecord = await manager.getById(key);
    if (existingRecord.isErr) {
      return Err(existingRecord.errorOrNull!);
    }
    
    if (existingRecord.data != null) {
      return Err(ErrorLocalDb.databaseError(
        "Cannot create new record: ID '$key' already exists. Use PUT method to update existing records."
      ));
    }
    
    final model = LocalDbModel(
      id: key,
      hash: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
    );
    
    return await manager.post(model);
  }

  /// Retrieves all records from the local database.
  ///
  /// Returns:
  /// - [Ok] with a list of [LocalDbModel]
  ///   - Returns an empty list if no records are found
  /// - [Err] with an error message if the operation fails
  static Future<Result<List<LocalDbModel>, ErrorLocalDb>> GetAll() async {
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    return await managerResult.data.getAll();
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
  static Future<Result<LocalDbModel?, ErrorLocalDb>> GetById(String id) async {
    final validationError = _validateInput(id, null);
    if (validationError != null) {
      return Err(validationError.errorOrNull!);
    }
    
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    return await managerResult.data.getById(id);
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
      String key, Map<String, dynamic> data) async {
    
    final validationError = _validateInput(key, data);
    if (validationError != null) {
      return validationError;
    }
    
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    final manager = managerResult.data;
    
    // Check if record exists
    final existingRecord = await manager.getById(key);
    if (existingRecord.isErr) {
      return Err(existingRecord.errorOrNull!);
    }
    
    if (existingRecord.data == null) {
      return Err(ErrorLocalDb.notFound(
        "Record '$key' not found. Use POST method to create new records."
      ));
    }
    
    final model = LocalDbModel(
      id: key,
      data: data,
      hash: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    
    return await manager.put(model);
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
    final validationError = _validateInput(id, null);
    if (validationError != null) {
      return Err(validationError.errorOrNull!);
    }
    
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    return await managerResult.data.delete(id);
  }

  /// Clear all data on the database.
  ///
  /// Returns:
  /// - [Ok] with `true` if the record was successfully deleted
  /// - [Err] with an error message if the key is invalid or deletion fails
  // ignore: non_constant_identifier_names
  static Future<Result<bool, ErrorLocalDb>> ClearData() async {
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    return await managerResult.data.cleanDatabase();
  }

  /// Closes the database connection and frees all resources.
  /// This should be called during hot restart or app termination to prevent crashes.
  /// Works on both mobile/desktop (FFI) and web (IndexedDB) platforms.
  // ignore: non_constant_identifier_names
  static Future<Result<void, ErrorLocalDb>> CloseDatabase() async {
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return Err(managerResult.errorOrNull!);
    }
    
    return await managerResult.data.close();
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
    final managerResult = _getCurrentManager();
    if (managerResult.isErr) {
      return false;
    }
    
    return await managerResult.data.isConnectionValid();
  }


  /// Get the current database name
  static String? get currentDatabaseName => _currentDbName;
  
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
  
  /// Validate input parameters for database operations
  static Result<LocalDbModel, ErrorLocalDb>? _validateInput(
    String key, 
    Map<String, dynamic>? data,
  ) {
    if (!_isValidId(key)) {
      return Err(ErrorLocalDb.serializationError(
        "Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).",
      ));
    }

    if (data != null && !_isValidMap(data)) {
      return Err(ErrorLocalDb.serializationError(
        'The provided format data is invalid.\n$data',
      ));
    }

    return null; // No validation errors
  }
  
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
    } catch (error) {
      log('JSON validation failed: $error');
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
