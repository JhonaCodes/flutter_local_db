import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../../core/result.dart';
import '../../../core/models.dart';
import '../../../core/log.dart';

/// Manages IndexedDB transactions and provides type-safe operations
///
/// Encapsulates the complexity of IndexedDB transaction management,
/// providing a clean interface for database operations with proper
/// error handling and resource management.
class IndexedDBTransactionManager {
  final web.IDBDatabase _database;
  final String _storeName;

  const IndexedDBTransactionManager(this._database, this._storeName);

  /// Executes a read operation within a readonly transaction
  ///
  /// Automatically handles transaction creation and cleanup.
  /// Returns a Future that completes when the operation finishes.
  Future<DbResult<T>> executeReadOperation<T>(
    Future<DbResult<T>> Function(web.IDBObjectStore store) operation,
  ) async {
    try {
      final transaction = _database.transaction(
        [_storeName].map((e) => e.toJS).toList().toJS,
        'readonly',
      );
      final store = transaction.objectStore(_storeName);

      return await operation(store);
    } catch (e, stackTrace) {
      Log.e('Read operation failed', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Read transaction failed: $e'));
    }
  }

  /// Executes a write operation within a readwrite transaction
  ///
  /// Automatically handles transaction creation and cleanup.
  /// Returns a Future that completes when the operation finishes.
  Future<DbResult<T>> executeWriteOperation<T>(
    Future<DbResult<T>> Function(web.IDBObjectStore store) operation,
  ) async {
    try {
      final transaction = _database.transaction(
        [_storeName].map((e) => e.toJS).toList().toJS,
        'readwrite',
      );
      final store = transaction.objectStore(_storeName);

      return await operation(store);
    } catch (e, stackTrace) {
      Log.e('Write operation failed', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Write transaction failed: $e'));
    }
  }

  /// Creates a request-based operation that returns a Future
  ///
  /// Wraps IndexedDB's event-based API into a Future-based API
  /// for easier async/await usage.
  Future<DbResult<T>> createRequestOperation<T>(
    web.IDBRequest request,
    T Function(dynamic result) onSuccess, {
    String? operationName,
  }) {
    final completer = Completer<DbResult<T>>();
    final operation = operationName ?? 'IndexedDB operation';

    request.onsuccess = ((web.Event event) {
      try {
        final result = (event.target as web.IDBRequest).result;
        final mappedResult = onSuccess(result);
        completer.complete(Ok(mappedResult));
      } catch (e) {
        Log.e('$operation success handler failed: $e');
        completer.complete(
          Err(DbError.databaseError('$operation parsing failed: $e')),
        );
      }
    }).toJS;

    request.onerror = ((web.Event event) {
      final error = (event.target as web.IDBRequest).error;
      Log.e('$operation failed: $error');
      completer.complete(
        Err(DbError.databaseError('$operation failed: $error')),
      );
    }).toJS;

    return completer.future;
  }

  /// Creates a void request operation (for operations that don't return data)
  ///
  /// Specialized version for operations like put, delete, clear that
  /// only need to confirm success without returning data.
  Future<DbResult<void>> createVoidRequestOperation(
    web.IDBRequest request, {
    String? operationName,
  }) {
    return createRequestOperation<void>(
      request,
      (_) => null,
      operationName: operationName,
    );
  }

  /// Validates that the database and store are properly initialized
  ///
  /// Checks that all required resources are available before operations.
  bool isValid() {
    try {
      return _database.objectStoreNames.contains(_storeName);
    } catch (e) {
      Log.e('Transaction manager validation failed: $e');
      return false;
    }
  }

  /// Gets store information for debugging purposes
  ///
  /// Returns details about the object store configuration.
  Map<String, dynamic> getStoreInfo() {
    try {
      final transaction = _database.transaction(
        [_storeName].map((e) => e.toJS).toList().toJS,
        'readonly',
      );
      final store = transaction.objectStore(_storeName);

      return {
        'name': store.name,
        'keyPath': store.keyPath,
        'autoIncrement': store.autoIncrement,
      };
    } catch (e) {
      Log.e('Failed to get store info: $e');
      return {'error': e.toString()};
    }
  }
}
