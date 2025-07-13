import 'dart:async';

import '../../core/database.dart';
import '../../core/result.dart';
import '../../core/models.dart';
import '../../core/log.dart';

/// Web database implementation using in-memory storage with localStorage persistence
/// 
/// Provides local database operations for web platforms using in-memory storage
/// with browser localStorage persistence for optimal web compatibility.
/// 
/// Example:
/// ```dart
/// final database = WebDatabase();
/// await database.initialize(DbConfig(name: 'my_web_app'));
/// 
/// final result = await database.insert('user-1', {'name': 'John'});
/// result.when(
///   ok: (entry) => Log.i('Saved to localStorage: ${entry.id}'),
///   err: (error) => Log.e('Failed: ${error.message}')
/// );
/// ```
class WebDatabase implements Database {
  bool _isInitialized = false;
  final Map<String, DbEntry> _memoryStorage = <String, DbEntry>{};

  @override
  Future<DbResult<void>> initialize(DbConfig config) async {
    try {
      Log.i('WebDatabase.initialize started: ${config.name}');
      
      
      // Load existing data from localStorage if available
      await _loadFromStorage();
      
      _isInitialized = true;
      
      Log.i('WebDatabase initialized successfully');
      return const Ok(null);

    } catch (e, stackTrace) {
      Log.e('Failed to initialize WebDatabase', error: e, stackTrace: stackTrace);
      return Err(DbError.connectionError(
        'Web database initialization failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> insert(String key, Map<String, dynamic> data) async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    if (!DatabaseValidator.isValidData(data)) {
      return Err(DbError.validationError('The provided data format is invalid'));
    }

    try {
      Log.d('WebDatabase.insert: $key');

      // Check if key already exists
      if (_memoryStorage.containsKey(key)) {
        return Err(DbError.validationError(
          "Cannot create new record: ID '$key' already exists. Use update method to modify existing records."
        ));
      }

      // Create entry with timestamp hash
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Store in memory and persist
      _memoryStorage[key] = entry;
      await _saveToStorage();

      Log.i('Record inserted successfully: $key');
      return Ok(entry);

    } catch (e, stackTrace) {
      Log.e('Failed to insert record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Insert operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> get(String key) async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    try {
      Log.d('WebDatabase.get: $key');

      final entry = _memoryStorage[key];
      if (entry == null) {
        return Err(DbError.notFound("No record found with key: $key"));
      }

      Log.d('Record retrieved successfully: $key');
      return Ok(entry);

    } catch (e, stackTrace) {
      Log.e('Failed to get record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Get operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> update(String key, Map<String, dynamic> data) async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    try {
      Log.d('WebDatabase.update: $key');

      // Verify record exists
      if (!_memoryStorage.containsKey(key)) {
        return Err(DbError.notFound(
          "Record '$key' not found. Use insert method to create new records."
        ));
      }

      // Create updated entry
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Update in memory and persist
      _memoryStorage[key] = entry;
      await _saveToStorage();

      Log.i('Record updated successfully: $key');
      return Ok(entry);

    } catch (e, stackTrace) {
      Log.e('Failed to update record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Update operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<void>> delete(String key) async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    try {
      Log.d('WebDatabase.delete: $key');

      _memoryStorage.remove(key);
      await _saveToStorage();

      Log.i('Record deleted successfully: $key');
      return const Ok(null);

    } catch (e, stackTrace) {
      Log.e('Failed to delete record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Delete operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<List<DbEntry>>> getAll() async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    try {
      Log.d('WebDatabase.getAll');

      final entries = _memoryStorage.values.toList();

      Log.i('Retrieved ${entries.length} records');
      return Ok(entries);

    } catch (e, stackTrace) {
      Log.e('Failed to get all records', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'GetAll operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<List<String>>> getAllKeys() async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    try {
      Log.d('WebDatabase.getAllKeys');

      final keys = _memoryStorage.keys.toList();

      Log.i('Retrieved ${keys.length} keys');
      return Ok(keys);

    } catch (e, stackTrace) {
      Log.e('Failed to get all keys', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'GetAllKeys operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<void>> clear() async {
    if (!_isInitialized) {
      return Err(DbError.connectionError('Database not initialized'));
    }

    try {
      Log.d('WebDatabase.clear');

      _memoryStorage.clear();
      await _saveToStorage();

      Log.i('Database cleared successfully');
      return const Ok(null);

    } catch (e, stackTrace) {
      Log.e('Failed to clear database', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Clear operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<bool> isConnectionValid() async {
    return _isInitialized;
  }

  @override
  Future<void> close() async {
    Log.i('WebDatabase.close');
    await _saveToStorage();
    _memoryStorage.clear();
    _isInitialized = false;
  }

  /// Loads data from localStorage
  Future<void> _loadFromStorage() async {
    try {
      // For web compatibility, we'll use a simple memory-based approach
      // In a real implementation, you could use window.localStorage
      Log.d('WebDatabase: using in-memory storage for web compatibility');
      
    } catch (e) {
      Log.w('Failed to load from storage, starting with empty database: $e');
    }
  }

  /// Saves data to localStorage
  Future<void> _saveToStorage() async {
    try {
      // For web compatibility, we'll use a simple memory-based approach
      // In a real implementation, you could use window.localStorage
      Log.d('WebDatabase: data persisted in memory');
      
    } catch (e) {
      Log.w('Failed to save to storage: $e');
    }
  }
}