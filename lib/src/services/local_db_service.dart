// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            DATABASE SERVICE                                 ║
// ║                    High-Level Database Service Interface                     ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: local_db_service.dart                                               ║
// ║  Purpose: High-level API for database operations                            ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides a high-level, user-friendly API for all database operations.   ║
// ║    Handles initialization, connection management, and provides convenient   ║
// ║    methods for common database tasks with proper error handling.           ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • High-level database API                                                 ║
// ║    • Automatic initialization                                                ║
// ║    • Connection lifecycle management                                         ║
// ║    • Batch operations support                                                ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import '../models/local_db_result.dart';
import '../models/local_db_error.dart';
import '../models/local_db_model.dart';
import '../core/ffi_bindings.dart';
import '../core/library_loader.dart';
import '../core/database_core.dart';
import '../utils/path_helper.dart';
import 'package:logger_rs/logger_rs.dart';

/// High-level database service for managing local data storage
///
/// This service provides a convenient, high-level API for all database
/// operations. It handles initialization, connection management, and
/// provides type-safe operations with comprehensive error handling.
///
/// Example usage:
/// ```dart
/// // Initialize the service
/// final result = await LocalDbService.initialize();
/// if (result.isErr) {
///   print('Failed to initialize: ${result.errOrNull}');
///   return;
/// }
///
/// final db = result.okOrNull!;
///
/// // Store some data
/// final storeResult = await db.store('user_123', {
///   'name': 'John Doe',
///   'email': 'john@example.com',
///   'age': 30,
/// });
///
/// // Retrieve the data
/// final getResult = await db.retrieve('user_123');
/// getResult.when(
///   ok: (model) => print('Name: ${model.data['name']}'),
///   err: (error) => print('Error: $error'),
/// );
///
/// // Clean up
/// db.close();
/// ```
class LocalDbService {
  final DatabaseCore _core;
  bool _isInitialized = false;

  LocalDbService._(this._core) {
    _isInitialized = true;
  }

  /// Initializes the database service with default settings
  ///
  /// Creates a new database instance using the default application data directory.
  /// This is the most common way to initialize the service for typical use cases.
  ///
  /// Returns:
  /// - [Ok] with [LocalDbService] instance on successful initialization
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await LocalDbService.initialize();
  /// result.when(
  ///   ok: (service) => print('Service ready'),
  ///   err: (error) => print('Initialization failed: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<LocalDbService, ErrorLocalDb>> initialize() async {
    Log.i('Initializing LocalDbService with default settings');

    // Get default database path
    final pathResult = await PathHelper.getDefaultDatabasePath();
    if (pathResult.isErr) {
      return Err(pathResult.errOrNull!);
    }

    final dbPath = pathResult.okOrNull!;
    return initializeWithPath(dbPath);
  }

  /// Initializes the database service with a custom path
  ///
  /// Creates a new database instance at the specified path. Use this method
  /// when you need to control exactly where the database file is stored.
  ///
  /// Parameters:
  /// - [path] - Full file system path where the database should be created
  ///
  /// Returns:
  /// - [Ok] with [LocalDbService] instance on successful initialization
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await LocalDbService.initializeWithPath('/custom/path/db');
  /// result.when(
  ///   ok: (service) => print('Service ready at custom path'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static Future<LocalDbResult<LocalDbService, ErrorLocalDb>> initializeWithPath(String path) async {
    Log.i('Initializing LocalDbService with path: $path');

    try {
      // Load the native library
      final libraryResult = LibraryLoader.loadLibrary();
      if (libraryResult.isErr) {
        Log.e('Failed to load native library');
        return Err(libraryResult.errOrNull!);
      }

      final library = libraryResult.okOrNull!;

      // Validate the library contains required functions
      final validationResult = LibraryLoader.validateLibrary(library);
      if (validationResult.isErr) {
        Log.e('Library validation failed');
        return Err(validationResult.errOrNull!);
      }

      // Create FFI bindings
      final bindings = LocalDbBindings.fromLibrary(library);

      // Ensure database directory exists
      final dirResult = await PathHelper.ensureDirectoryExists(path);
      if (dirResult.isErr) {
        return Err(dirResult.errOrNull!);
      }

      // Create database core
      final coreResult = DatabaseCore.create(bindings, path);
      if (coreResult.isErr) {
        Log.e('Failed to create database core');
        return Err(coreResult.errOrNull!);
      }

      final core = coreResult.okOrNull!;
      final service = LocalDbService._(core);

      Log.i('LocalDbService initialized successfully');
      return Ok(service);
    } catch (e, stackTrace) {
      Log.e('Unexpected error during initialization: $e');
      return Err(
        ErrorLocalDb.initialization(
          'Unexpected error during service initialization',
          context: path,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Stores data with the specified key
  ///
  /// Creates a new record or updates an existing one with the provided data.
  /// The data must be JSON serializable (Map, List, String, num, bool, null).
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the record
  /// - [data] - Data to store (must be JSON serializable)
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] containing the stored data and metadata
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await service.store('settings', {
  ///   'theme': 'dark',
  ///   'notifications': true,
  ///   'language': 'en',
  /// });
  ///
  /// result.when(
  ///   ok: (model) => print('Stored at: ${model.createdAt}'),
  ///   err: (error) => print('Storage failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> store(
    String key,
    Map<String, dynamic> data,
  ) async {
    _ensureInitialized();
    Log.d('Storing data with key: $key');

    return _core.put(key, data);
  }

  /// Retrieves data by key
  ///
  /// Looks up and returns the record with the specified key.
  /// Returns a not found error if the key doesn't exist.
  ///
  /// Parameters:
  /// - [key] - The key to retrieve
  ///
  /// Returns:
  /// - [Ok] with [LocalDbModel] if the record exists
  /// - [Err] with not found error if the key doesn't exist
  /// - [Err] with other error types for various failures
  ///
  /// Example:
  /// ```dart
  /// final result = await service.retrieve('settings');
  /// result.when(
  ///   ok: (model) => print('Theme: ${model.data['theme']}'),
  ///   err: (error) => {
  ///     if (error.type == LocalDbErrorType.notFound) {
  ///       print('Settings not found, using defaults')
  ///     } else {
  ///       print('Error: $error')
  ///     }
  ///   },
  /// );
  /// ```
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> retrieve(String key) async {
    _ensureInitialized();
    Log.d('Retrieving data for key: $key');

    return _core.get(key);
  }

  /// Updates existing data with new values
  ///
  /// Retrieves the existing record, merges it with the provided data,
  /// and stores the updated version. Creates a new record if the key doesn't exist.
  ///
  /// Parameters:
  /// - [key] - The key to update
  /// - [updates] - Data to merge with existing data
  ///
  /// Returns:
  /// - [Ok] with updated [LocalDbModel]
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await service.update('settings', {
  ///   'theme': 'light',  // This will update the theme
  ///   'newFeature': true, // This will be added
  /// });
  ///
  /// result.when(
  ///   ok: (model) => print('Updated: ${model.updatedAt}'),
  ///   err: (error) => print('Update failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> update(
    String key,
    Map<String, dynamic> updates,
  ) async {
    _ensureInitialized();
    Log.d('Updating data for key: $key');

    // Try to get existing data
    final existingResult = await retrieve(key);

    Map<String, dynamic> finalData;

    if (existingResult.isOk) {
      // Merge with existing data
      final existingData = existingResult.okOrNull!.data;
      finalData = Map<String, dynamic>.from(existingData);
      finalData.addAll(updates);
    } else if (existingResult.errOrNull!.type == LocalDbErrorType.notFound) {
      // Create new record with update data
      finalData = updates;
    } else {
      // Return the error from retrieve operation
      return Err(existingResult.errOrNull!);
    }

    return store(key, finalData);
  }

  /// Removes a record by key
  ///
  /// Deletes the record with the specified key from the database.
  /// Returns success even if the key doesn't exist.
  ///
  /// Parameters:
  /// - [key] - The key to remove
  ///
  /// Returns:
  /// - [Ok] with void on successful removal
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await service.remove('temp_data');
  /// result.when(
  ///   ok: (_) => print('Removed successfully'),
  ///   err: (error) => print('Removal failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<void, ErrorLocalDb>> remove(String key) async {
    _ensureInitialized();
    Log.d(' Removing data for key: $key');

    return _core.delete(key);
  }

  /// Retrieves all data from the database
  ///
  /// Returns a map containing all key-value pairs currently stored.
  /// For large databases, this operation may be expensive.
  ///
  /// Returns:
  /// - [Ok] with map of all data
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await service.listAll();
  /// result.when(
  ///   ok: (allData) => {
  ///     print('Found ${allData.length} records'),
  ///     allData.forEach((key, model) => {
  ///       print('$key: ${model.data}'),
  ///     }),
  ///   },
  ///   err: (error) => print('Failed to list data: $error'),
  /// );
  /// ```
  Future<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>> listAll() async {
    _ensureInitialized();
    Log.d(' Listing all data');

    return _core.getAll();
  }

  /// Clears all data from the database
  ///
  /// Removes all records from the database. This operation cannot be undone.
  /// Use with extreme caution, especially in production environments.
  ///
  /// Returns:
  /// - [Ok] with void on successful clear
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await service.clearAll();
  /// result.when(
  ///   ok: (_) => print('Database cleared completely'),
  ///   err: (error) => print('Clear failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<void, ErrorLocalDb>> clearAll() async {
    _ensureInitialized();
    Log.w(' Clearing all database data');

    return _core.clear();
  }

  /// Performs multiple store operations in sequence
  ///
  /// Stores multiple key-value pairs. If any operation fails, the remaining
  /// operations are still attempted. Returns results for all operations.
  ///
  /// Parameters:
  /// - [entries] - Map of key-value pairs to store
  ///
  /// Returns:
  /// - [Ok] with map of results for each key
  /// - [Err] should not occur at this level (individual results contain errors)
  ///
  /// Example:
  /// ```dart
  /// final result = await service.storeMultiple({
  ///   'user_1': {'name': 'Alice', 'role': 'admin'},
  ///   'user_2': {'name': 'Bob', 'role': 'user'},
  ///   'settings': {'theme': 'dark'},
  /// });
  ///
  /// result.when(
  ///   ok: (results) => {
  ///     results.forEach((key, result) => {
  ///       result.when(
  ///         ok: (model) => print('$key stored successfully'),
  ///         err: (error) => print('$key failed: $error'),
  ///       ),
  ///     }),
  ///   },
  ///   err: (error) => print('Batch operation failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<Map<String, LocalDbResult<LocalDbModel, ErrorLocalDb>>, ErrorLocalDb>>
  storeMultiple(Map<String, Map<String, dynamic>> entries) async {
    _ensureInitialized();
    Log.d(' Storing ${entries.length} entries in batch');

    final results = <String, LocalDbResult<LocalDbModel, ErrorLocalDb>>{};

    for (final entry in entries.entries) {
      final result = await store(entry.key, entry.value);
      results[entry.key] = result;
    }

    Log.d(' Batch store completed: ${entries.length} operations');
    return Ok(results);
  }

  /// Performs multiple retrieve operations in sequence
  ///
  /// Retrieves multiple records by their keys. Returns results for all
  /// requested keys, including not found errors for missing keys.
  ///
  /// Parameters:
  /// - [keys] - List of keys to retrieve
  ///
  /// Returns:
  /// - [Ok] with map of results for each key
  /// - [Err] should not occur at this level (individual results contain errors)
  ///
  /// Example:
  /// ```dart
  /// final result = await service.retrieveMultiple(['user_1', 'user_2', 'settings']);
  /// result.when(
  ///   ok: (results) => {
  ///     results.forEach((key, result) => {
  ///       result.when(
  ///         ok: (model) => print('$key: ${model.data}'),
  ///         err: (error) => print('$key not found or error'),
  ///       ),
  ///     }),
  ///   },
  ///   err: (error) => print('Batch retrieve failed: $error'),
  /// );
  /// ```
  Future<LocalDbResult<Map<String, LocalDbResult<LocalDbModel, ErrorLocalDb>>, ErrorLocalDb>>
  retrieveMultiple(List<String> keys) async {
    _ensureInitialized();
    Log.d(' Retrieving ${keys.length} entries in batch');

    final results = <String, LocalDbResult<LocalDbModel, ErrorLocalDb>>{};

    for (final key in keys) {
      final result = await retrieve(key);
      results[key] = result;
    }

    Log.d(' Batch retrieve completed: ${keys.length} operations');
    return Ok(results);
  }

  /// Closes the database service and releases all resources
  ///
  /// Properly shuts down the database connection and releases all associated
  /// resources. After calling this method, the service instance cannot be used.
  /// Always call this method when you're done with the service to prevent
  /// resource leaks.
  ///
  /// Example:
  /// ```dart
  /// // When done with the service
  /// service.close();
  /// print('Service closed and resources released');
  /// ```
  void close() {
    if (!_isInitialized) {
      Log.w(' Attempted to close non-initialized service');
      return;
    }

    Log.i(' Closing LocalDbService');
    _core.close();
    _isInitialized = false;
    Log.i(' LocalDbService closed successfully');
  }

  /// Checks if the service is properly initialized and ready for use
  bool get isInitialized => _isInitialized && !_core.isClosed;

  /// Ensures the service is initialized, throws if not
  void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError('LocalDbService is not initialized or has been closed');
    }
  }
}
