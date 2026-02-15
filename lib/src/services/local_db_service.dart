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

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:logger_rs/logger_rs.dart';

import '../core/initializer.dart';
import '../core/database_core.dart';

/// High-level database service for managing local data storage
///
/// This service provides a convenient, high-level API for all database
/// operations. It handles initialization, connection management, and
/// provides type-safe operations with comprehensive error handling.
class LocalDbService {
  final DatabaseCore _core;
  bool _isInitialized = false;

  LocalDbService._(this._core) {
    _isInitialized = true;
  }

  /// Initializes the database service with default settings
  static Future<LocalDbResult<LocalDbService, ErrorLocalDb>>
  initialize() async {
    Log.i('Initializing LocalDbService with default settings');

    // Get default database path (Platform agnostic)
    final pathResult = await PathHelper.getDefaultDatabasePath();
    if (pathResult.isErr) {
      return Err(pathResult.errOrNull!);
    }

    final dbPath = pathResult.okOrNull!;
    return initializeWithPath(dbPath);
  }

  /// Initializes the database service with a custom path
  static Future<LocalDbResult<LocalDbService, ErrorLocalDb>> initializeWithPath(
    String path,
  ) async {
    Log.i('Initializing LocalDbService with path: $path');

    try {
      // Initialize environment (Load library/create bindings if Native, do nothing if Web)
      final initResult = Initializer.init();
      if (initResult.isErr) {
        return Err(initResult.errOrNull!);
      }

      final bindings = initResult.okOrNull;

      // Ensure database directory exists (Handled by PathHelper agnostic)
      final dirResult = await PathHelper.ensureDirectoryExists(path);
      if (dirResult.isErr) {
        return Err(dirResult.errOrNull!);
      }

      // Create database core (Agnostic factory)
      // Note: bindings will be null on Web, which is expected/handled by Web Core.
      final coreResult = await DatabaseCore.create(bindings, path);
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
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> store(
    String key,
    LocalMethod method,
    Map<String, dynamic> data,
  ) async {
    _ensureInitialized();
    Log.d('Storing data with key: $key');

    return switch (method) {
      LocalMethod.post => await _core.post(key, data),
      LocalMethod.put => await _core.put(key, data),
      LocalMethod.update => await _core.update(key, data),
    };
  }

  /// Retrieves data by key
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> retrieve(String key) async {
    _ensureInitialized();
    Log.d('Retrieving data for key: $key');

    return await _core.get(key);
  }

  /// Updates existing data with new values
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

    return store(key, LocalMethod.update, finalData);
  }

  /// Removes a record by key
  Future<LocalDbResult<void, ErrorLocalDb>> remove(String key) async {
    _ensureInitialized();
    Log.d(' Removing data for key: $key');

    return await _core.delete(key);
  }

  /// Retrieves all data from the database
  Future<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>>
  listAll() async {
    _ensureInitialized();
    Log.d(' Listing all data');

    return await _core.getAll();
  }

  /// Clears all data from the database
  Future<LocalDbResult<void, ErrorLocalDb>> clearAll() async {
    _ensureInitialized();
    Log.w(' Clearing all database data');

    return await _core.clear();
  }

  /// Performs multiple store operations in sequence
  Future<
    LocalDbResult<
      Map<String, LocalDbResult<LocalDbModel, ErrorLocalDb>>,
      ErrorLocalDb
    >
  >
  storeMultiple(Map<String, Map<String, dynamic>> entries) async {
    _ensureInitialized();
    Log.d(' Storing ${entries.length} entries in batch');

    final results = <String, LocalDbResult<LocalDbModel, ErrorLocalDb>>{};

    for (final entry in entries.entries) {
      final result = await store(entry.key, LocalMethod.post, entry.value);
      results[entry.key] = result;
    }

    Log.d(' Batch store completed: ${entries.length} operations');
    return Ok(results);
  }

  /// Performs multiple retrieve operations in sequence
  Future<
    LocalDbResult<
      Map<String, LocalDbResult<LocalDbModel, ErrorLocalDb>>,
      ErrorLocalDb
    >
  >
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
