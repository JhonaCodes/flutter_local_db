import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/log.dart';
import '../model/local_db_error_model.dart';
import '../utils/system_utils.dart';
import 'package:result_controller/result_controller.dart';
import 'database_interface.dart';
import 'database_mock.dart';
import 'database_native.dart';
import 'database_web_import.dart';

/// Elegant database manager that handles connections on-demand
/// without singleton pattern complexity
class DatabaseManager {
  static String? _currentDatabaseName;
  
  /// Connect to or create database with given name (safe Result-based version)
  static Future<Result<DatabaseInterface, ErrorLocalDb>> _safeGetConnection(String databaseName) async {
    _currentDatabaseName = databaseName;
    
    final DatabaseInterface database = _createDatabaseInstance();
    
    // Use Result-based initialization if available
    await database.initialize(databaseName);
    
    Log.i('✅ Connected to database: $databaseName on ${database.platformName}');
    return Ok(database);
  }
  
  /// Factory method to create appropriate database instance
  static DatabaseInterface _createDatabaseInstance() {
    if (SystemUtils.isTest) {
      return DatabaseMock();
    }
    
    if (kIsWeb) {
      return DatabaseWeb();
    }
    
    return DatabaseNative.instance;
  }
  
  /// Execute a database operation with persistent connection management
  static Future<Result<T, ErrorLocalDb>> execute<T>(
    String databaseName,
    Future<Result<T, ErrorLocalDb>> Function(DatabaseInterface db) operation,
  ) async {
    final connectionResult = await _safeGetConnection(databaseName);
    
    return connectionResult.when(
      ok: (db) async {
        final operationResult = await operation(db);
        // Let RedB manage connections internally - no forced closing
        return operationResult;
      },
      err: (error) => Err(error),
    );
  }
  
  /// Get current database name (useful for debugging)
  static String? get currentDatabaseName => _currentDatabaseName;
  
  /// Check if database exists on disk
  static Future<bool> databaseExists(String databaseName) async {
    if (kIsWeb) {
      // For web, we can't check file existence, assume it exists if we have a name stored
      return _currentDatabaseName == databaseName;
    }
    
    try {
      // For native platforms, check if database file exists
      final db = DatabaseNative.instance;
      return await db.ensureConnectionValid();
    } catch (e) {
      return false;
    }
  }
}