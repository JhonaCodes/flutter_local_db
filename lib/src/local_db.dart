// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                          FLUTTER LOCAL DB                                   ║
// ║                  High-Performance Cross-Platform Database                   ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: flutter_local_db.dart                                               ║
// ║  Purpose: Main library entry point and public API                           ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    A high-performance cross-platform local database for Flutter using      ║
// ║    Rust+LMDB via FFI. Provides a clean, type-safe API with comprehensive   ║
// ║    error handling and cross-platform compatibility.                        ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • High-performance LMDB backend via Rust                                 ║
// ║    • Type-safe Result<T, E> error handling                                  ║
// ║    • Cross-platform support (Android, iOS, macOS, Windows, Linux)          ║
// ║    • Clean modular architecture                                              ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

// Legacy API compatibility layer
import 'services/local_db_service.dart';
import 'models/local_db_result.dart';
import 'models/local_db_error.dart';
import 'models/local_db_model.dart';

/// Legacy API compatibility layer
///
/// Provides backward compatibility with the original LocalDB API while
/// using the new modular architecture underneath. This allows existing
/// code to continue working without modifications.
///
/// For new projects, consider using [LocalDbService] directly for a
/// more modern and feature-rich API.

/// Legacy API compatibility class
///
/// Provides backward compatibility with the original LocalDB API.
/// This class wraps the new [LocalDbService] to maintain compatibility
/// with existing code while providing improved functionality underneath.
class LocalDB {
  static LocalDbService? _service;
  static bool _isInitialized = false;

  /// Private constructor to prevent instantiation
  LocalDB._();

  /// Initialize database with backward compatibility
  ///
  /// Parameters:
  /// - [dbName] - Optional custom database name (defaults to 'flutter_local_db')
  ///
  /// This method maintains backward compatibility while using the new
  /// [LocalDbService] underneath for improved functionality.
  static Future<void> init([String? dbName]) async {
    if (_isInitialized) {
      return;
    }

    try {
      final serviceResult = await LocalDbService.initialize();

      serviceResult.when(
        ok: (service) {
          _service = service;
          _isInitialized = true;
        },
        err: (error) {
          throw Exception('LocalDB initialization failed: ${error.message}');
        },
      );
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Create new record (backward compatible API)
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the record
  /// - [data] - Data to store
  /// - [lastUpdate] - Optional update timestamp (ignored in new implementation)
  ///
  /// Returns a [LocalDbResult] with the created model or an error.
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> Post(
    String key,
    Map<String, dynamic> data, {
    String? lastUpdate,
  }) async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    return await _service!.store(key,LocalMethod.post, data);
  }

  /// Get record by ID (backward compatible API)
  ///
  /// Parameters:
  /// - [key] - The key to retrieve
  ///
  /// Returns a [LocalDbResult] with the model or null if not found.
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> GetById(
    String key,
  ) async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    final result = await _service!.retrieve(key);
    return result.when(
      ok: (model) => Ok(model),
      err: (error) {
        // Return null for not found errors to maintain backward compatibility
        if (error.type == LocalDbErrorType.notFound) {
          return const Ok(null);
        }
        return Err(error);
      },
    );
  }

  /// Update existing record (backward compatible API)
  ///
  /// Parameters:
  /// - [key] - The key to update
  /// - [data] - New data to store
  ///
  /// Returns a [LocalDbResult] with the updated model or an error.
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> Put(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    return await _service!.store(key,LocalMethod.put, data);
  }

  /// Delete record (backward compatible API)
  ///
  /// Parameters:
  /// - [key] - The key to delete
  ///
  /// Returns a [LocalDbResult] with true on success or an error.
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, ErrorLocalDb>> Delete(String key) async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    final result = await _service!.remove(key);
    return result.when(ok: (_) => const Ok(true), err: (error) => Err(error));
  }

  /// Get all records (backward compatible API)
  ///
  /// Returns a [LocalDbResult] with a list of all models or an error.
  static Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>>
  // ignore: non_constant_identifier_names
  GetAll() async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    final result = await _service!.listAll();
    return result.when(
      ok: (allData) => Ok(allData.values.toList()),
      err: (error) => Err(error),
    );
  }

  /// Clear all data (backward compatible API)
  ///
  /// Returns a [LocalDbResult] with true on success or an error.
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, ErrorLocalDb>> ClearData() async {
    if (!_isInitialized || _service == null) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }

    final result = await _service!.clearAll();
    return result.when(ok: (_) => const Ok(true), err: (error) => Err(error));
  }

  /// Check if database is initialized
  static bool get isInitialized {
    return _isInitialized && _service != null && _service!.isInitialized;
  }

  /// Close database and release resources
  static Future<void> close() async {
    if (_service != null) {
      _service!.close();
      _service = null;
    }
    _isInitialized = false;
  }
}


enum LocalMethod {post, put, update}