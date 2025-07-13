import 'dart:convert';
import 'result.dart';
import 'models.dart';

/// Abstract interface for local database operations
/// 
/// Provides a unified API for database operations across all platforms.
/// Implementations handle platform-specific details (FFI for native, IndexedDB for web).
/// 
/// All operations return [DbResult] for consistent error handling.
/// 
/// Example:
/// ```dart
/// abstract class MyDatabase implements Database {
///   @override
///   Future<DbResult<void>> initialize(DbConfig config) async {
///     // Platform-specific initialization
///   }
/// 
///   @override
///   Future<DbResult<DbEntry>> insert(String key, Map<String, dynamic> data) async {
///     // Platform-specific insert logic
///   }
/// }
/// ```
abstract class Database {
  /// Initializes the database with the given configuration
  /// 
  /// Must be called before any other operations. Sets up the database
  /// file/store and prepares for data operations.
  /// 
  /// Example:
  /// ```dart
  /// final config = DbConfig(name: 'my_app_db');
  /// final result = await database.initialize(config);
  /// 
  /// result.when(
  ///   ok: (_) => print('Database ready'),
  ///   err: (error) => print('Init failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<void>> initialize(DbConfig config);

  /// Inserts a new record into the database
  /// 
  /// Creates a new entry with the given key and data. Fails if a record
  /// with the same key already exists.
  /// 
  /// Parameters:
  /// - [key]: Unique identifier (3+ chars, alphanumeric/hyphens/underscores only)
  /// - [data]: JSON-serializable data to store
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.insert('user-123', {
  ///   'name': 'John Doe',
  ///   'email': 'john@example.com'
  /// });
  /// 
  /// result.when(
  ///   ok: (entry) => print('Created: ${entry.id}'),
  ///   err: (error) => print('Insert failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<DbEntry>> insert(String key, Map<String, dynamic> data);

  /// Retrieves a record by its unique identifier
  /// 
  /// Returns the record if found, or a not-found error if it doesn't exist.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.get('user-123');
  /// 
  /// result.when(
  ///   ok: (entry) => print('Found: ${entry.data}'),
  ///   err: (error) => print('Not found: ${error.message}')
  /// );
  /// ```
  Future<DbResult<DbEntry>> get(String key);

  /// Updates an existing record in the database
  /// 
  /// Replaces the data for an existing key. Fails if the record doesn't exist.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.update('user-123', {
  ///   'name': 'John Smith',
  ///   'email': 'john.smith@example.com'
  /// });
  /// 
  /// result.when(
  ///   ok: (entry) => print('Updated: ${entry.id}'),
  ///   err: (error) => print('Update failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<DbEntry>> update(String key, Map<String, dynamic> data);

  /// Deletes a record by its unique identifier
  /// 
  /// Removes the record from the database. Returns success even if the
  /// record didn't exist.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.delete('user-123');
  /// 
  /// result.when(
  ///   ok: (_) => print('Deleted successfully'),
  ///   err: (error) => print('Delete failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<void>> delete(String key);

  /// Retrieves all records from the database
  /// 
  /// Returns a list of all stored entries. Returns an empty list if
  /// no records exist.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.getAll();
  /// 
  /// result.when(
  ///   ok: (entries) => print('Found ${entries.length} records'),
  ///   err: (error) => print('Query failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<List<DbEntry>>> getAll();

  /// Retrieves all keys from the database
  /// 
  /// Returns a list of all record identifiers without loading the full data.
  /// Useful for checking what records exist or for batch operations.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.getAllKeys();
  /// 
  /// result.when(
  ///   ok: (keys) => print('Keys: ${keys.join(', ')}'),
  ///   err: (error) => print('Query failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<List<String>>> getAllKeys();

  /// Clears all data from the database
  /// 
  /// Removes all records but keeps the database structure intact.
  /// This operation cannot be undone.
  /// 
  /// Example:
  /// ```dart
  /// final result = await database.clear();
  /// 
  /// result.when(
  ///   ok: (_) => print('Database cleared'),
  ///   err: (error) => print('Clear failed: ${error.message}')
  /// );
  /// ```
  Future<DbResult<void>> clear();

  /// Checks if the database connection is valid
  /// 
  /// Useful for detecting connection issues or hot restart scenarios
  /// where the database state may need to be reestablished.
  /// 
  /// Example:
  /// ```dart
  /// final isValid = await database.isConnectionValid();
  /// if (!isValid) {
  ///   await database.initialize(config); // Reinitialize if needed
  /// }
  /// ```
  Future<bool> isConnectionValid();

  /// Closes the database connection
  /// 
  /// Properly closes the database and releases resources. Should be called
  /// when the database is no longer needed.
  /// 
  /// Example:
  /// ```dart
  /// await database.close();
  /// ```
  Future<void> close();
}

/// Utility class for validating database inputs
/// 
/// Contains static methods for validating keys, data, and other inputs
/// according to database requirements.
/// 
/// Example:
/// ```dart
/// if (!DatabaseValidator.isValidKey('user-123')) {
///   return Err(DbError.validationError('Invalid key format'));
/// }
/// 
/// if (!DatabaseValidator.isValidData({'key': 'value'})) {
///   return Err(DbError.validationError('Data is not JSON-serializable'));
/// }
/// ```
class DatabaseValidator {
  DatabaseValidator._();

  /// Validates that a key meets database requirements
  /// 
  /// Keys must be:
  /// - At least 3 characters long
  /// - Contain only letters, numbers, hyphens, and underscores
  /// 
  /// Example:
  /// ```dart
  /// DatabaseValidator.isValidKey('user-123')  // true
  /// DatabaseValidator.isValidKey('ab')        // false (too short)
  /// DatabaseValidator.isValidKey('user@123')  // false (invalid character)
  /// ```
  static bool isValidKey(String key) {
    if (key.length < 3) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key);
  }

  /// Validates that data can be JSON-serialized
  /// 
  /// Attempts to encode and decode the data to ensure it's valid JSON.
  /// 
  /// Example:
  /// ```dart
  /// DatabaseValidator.isValidData({'key': 'value'})           // true
  /// DatabaseValidator.isValidData({'key': DateTime.now()})    // false
  /// ```
  static bool isValidData(Map<String, dynamic> data) {
    try {
      final encoded = jsonEncode(data);
      jsonDecode(encoded);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates a database name
  /// 
  /// Database names should be valid filenames and contain only
  /// safe characters.
  /// 
  /// Example:
  /// ```dart
  /// DatabaseValidator.isValidDatabaseName('my_app_db')     // true
  /// DatabaseValidator.isValidDatabaseName('my/app/db')     // false
  /// ```
  static bool isValidDatabaseName(String name) {
    if (name.isEmpty) return false;
    // Check for invalid filename characters and special characters
    return !RegExp(r'[<>:"/\\|?*@#$ &]').hasMatch(name);
  }

  /// Gets a validation error message for an invalid key
  /// 
  /// Example:
  /// ```dart
  /// final error = DatabaseValidator.getKeyValidationError('ab');
  /// // Returns: "Invalid key format. Key must be at least 3 characters long..."
  /// ```
  static String getKeyValidationError(String key) {
    if (key.length < 3) {
      return 'Invalid key format. Key must be at least 3 characters long and can only contain letters, numbers, hyphens (-) and underscores (_).';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key)) {
      return 'Invalid key format. Key can only contain letters, numbers, hyphens (-) and underscores (_).';
    }
    return 'Key is valid';
  }
}