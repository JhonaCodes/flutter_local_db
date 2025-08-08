import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../../core/result.dart';
import '../../../core/models.dart';
import '../../../core/log.dart';
import 'indexed_db_transaction_manager.dart';
import 'js_object_converter.dart';

/// Core service for IndexedDB operations
/// 
/// Provides high-level database operations built on top of IndexedDB.
/// Handles connection management, data conversion, and error handling
/// while maintaining a clean separation of concerns.
class IndexedDBService {
  web.IDBDatabase? _database;
  IndexedDBTransactionManager? _transactionManager;
  String _dbName = '';
  static const String _storeName = 'flutter_local_db_store';

  bool get isInitialized => _database != null && _transactionManager != null;

  /// Initializes the IndexedDB connection
  /// 
  /// Opens the database, creates object stores if needed, and sets up
  /// the transaction manager for subsequent operations.
  Future<DbResult<void>> initialize(String dbName) async {
    try {
      Log.i('IndexedDBService.initialize started: $dbName');
      _dbName = dbName;

      final databaseResult = await _openDatabase();
      return databaseResult.when(
        ok: (db) {
          _database = db;
          _transactionManager = IndexedDBTransactionManager(db, _storeName);
          Log.i('IndexedDBService initialized successfully');
          return const Ok(null);
        },
        err: (error) => Err(error),
      );
    } catch (e, stackTrace) {
      Log.e('IndexedDBService initialization failed', error: e, stackTrace: stackTrace);
      return Err(DbError.connectionError('Service initialization failed: $e'));
    }
  }

  /// Inserts a new record into the database
  /// 
  /// Checks for key existence to prevent duplicates and stores the entry
  /// with proper conversion to JavaScript objects.
  Future<DbResult<DbEntry>> insert(String key, Map<String, dynamic> data) async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.insert: $key');

      // Check if key already exists
      final existingResult = await get(key);
      if (existingResult.isOk) {
        return Err(DbError.validationError(
          "❌ Record creation failed: ID '$key' already exists.\n" +
          "💡 Solution: Use LocalDB.Put('$key', data) to UPDATE the existing record, " +
          "or choose a different ID for LocalDB.Post().",
        ));
      }

      // Create entry with timestamp hash
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Store in IndexedDB
      return await _storeEntry(entry);
    } catch (e, stackTrace) {
      Log.e('Insert operation failed: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Insert failed: $e'));
    }
  }

  /// Retrieves a record by key
  /// 
  /// Returns the record if found, or a not found error if it doesn't exist.
  Future<DbResult<DbEntry>> get(String key) async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.get: $key');

      return await _transactionManager!.executeReadOperation((store) async {
        final request = store.get(key.toJS);
        
        return await _transactionManager!.createRequestOperation<DbEntry>(
          request,
          (result) {
            if (result == null) {
              throw DbError.notFound("No record found with key: $key");
            }
            
            final record = JSObjectConverter.jsObjectToMap(result);
            final entry = JSObjectConverter.mapToDbEntry(record);
            Log.d('Record retrieved successfully: $key');
            return entry;
          },
          operationName: 'get($key)',
        );
      });
    } catch (e, stackTrace) {
      Log.e('Get operation failed: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Get failed: $e'));
    }
  }

  /// Updates an existing record
  /// 
  /// Verifies the record exists before updating to maintain data integrity.
  Future<DbResult<DbEntry>> update(String key, Map<String, dynamic> data) async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.update: $key');

      // Verify record exists
      final existingResult = await get(key);
      if (existingResult.isErr) {
        return Err(DbError.notFound(
          "❌ Record update failed: ID '$key' does not exist.\n" +
          "💡 Solution: Use LocalDB.Post('$key', data) to CREATE a new record, " +
          "or verify the ID exists with LocalDB.GetById('$key').",
        ));
      }

      // Create updated entry
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      return await _storeEntry(entry);
    } catch (e, stackTrace) {
      Log.e('Update operation failed: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Update failed: $e'));
    }
  }

  /// Deletes a record by key
  /// 
  /// Removes the record from the database if it exists.
  Future<DbResult<void>> delete(String key) async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.delete: $key');

      return await _transactionManager!.executeWriteOperation((store) async {
        final request = store.delete(key.toJS);
        
        final result = await _transactionManager!.createVoidRequestOperation(
          request,
          operationName: 'delete($key)',
        );

        if (result.isOk) {
          Log.i('Record deleted successfully: $key');
        }

        return result;
      });
    } catch (e, stackTrace) {
      Log.e('Delete operation failed: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Delete failed: $e'));
    }
  }

  /// Retrieves all records from the database
  /// 
  /// Returns a list of all stored entries.
  Future<DbResult<List<DbEntry>>> getAll() async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.getAll');

      return await _transactionManager!.executeReadOperation((store) async {
        final request = store.getAll();
        
        return await _transactionManager!.createRequestOperation<List<DbEntry>>(
          request,
          (result) {
            final resultList = result as List;
            final entries = <DbEntry>[];
            
            for (final item in resultList) {
              final record = JSObjectConverter.jsObjectToMap(item);
              entries.add(JSObjectConverter.mapToDbEntry(record));
            }
            
            Log.i('Retrieved ${entries.length} records from IndexedDB');
            return entries;
          },
          operationName: 'getAll',
        );
      });
    } catch (e, stackTrace) {
      Log.e('GetAll operation failed', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('GetAll failed: $e'));
    }
  }

  /// Retrieves all keys from the database
  /// 
  /// Returns a list of all stored keys without loading the full records.
  Future<DbResult<List<String>>> getAllKeys() async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.getAllKeys');

      return await _transactionManager!.executeReadOperation((store) async {
        final request = store.getAllKeys();
        
        return await _transactionManager!.createRequestOperation<List<String>>(
          request,
          (result) {
            final resultList = result as List;
            final keys = resultList.map((key) => key.toString()).toList();
            
            Log.i('Retrieved ${keys.length} keys from IndexedDB');
            return keys;
          },
          operationName: 'getAllKeys',
        );
      });
    } catch (e, stackTrace) {
      Log.e('GetAllKeys operation failed', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('GetAllKeys failed: $e'));
    }
  }

  /// Clears all records from the database
  /// 
  /// Removes all stored data while keeping the database structure intact.
  Future<DbResult<void>> clear() async {
    if (!isInitialized) {
      return Err(DbError.connectionError('Service not initialized'));
    }

    try {
      Log.d('IndexedDBService.clear');

      return await _transactionManager!.executeWriteOperation((store) async {
        final request = store.clear();
        
        final result = await _transactionManager!.createVoidRequestOperation(
          request,
          operationName: 'clear',
        );

        if (result.isOk) {
          Log.i('IndexedDB cleared successfully');
        }

        return result;
      });
    } catch (e, stackTrace) {
      Log.e('Clear operation failed', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError('Clear failed: $e'));
    }
  }

  /// Closes the database connection
  /// 
  /// Releases resources and cleans up the connection.
  Future<void> close() async {
    Log.i('IndexedDBService.close');
    
    try {
      _database?.close();
    } catch (e) {
      Log.e('Error closing database: $e');
    }
    
    _database = null;
    _transactionManager = null;
  }

  /// Checks if the connection is valid and ready for operations
  /// 
  /// Validates that the database and transaction manager are properly initialized.
  bool isConnectionValid() {
    return isInitialized && (_transactionManager?.isValid() ?? false);
  }

  /// Opens the IndexedDB database with proper error handling
  Future<DbResult<web.IDBDatabase>> _openDatabase() async {
    final completer = Completer<DbResult<web.IDBDatabase>>();

    try {
      // Check IndexedDB support
      if (!web.window.indexedDB.isDefinedAndNotNull) {
        return Err(DbError.connectionError('IndexedDB is not supported in this browser'));
      }

      final request = web.window.indexedDB.open(_dbName, 1);

      request.onupgradeneeded = ((web.IDBVersionChangeEvent event) {
        try {
          final db = (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
          
          if (!db.objectStoreNames.contains(_storeName)) {
            db.createObjectStore(_storeName, web.IDBObjectStoreParameters(keyPath: 'id'.toJS));
            Log.d('Created IndexedDB object store: $_storeName');
          }
        } catch (e) {
          Log.e('Error during IndexedDB upgrade: $e');
          completer.complete(Err(DbError.connectionError('Database upgrade failed: $e')));
        }
      }).toJS;

      request.onsuccess = ((web.Event event) {
        try {
          final db = (event.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
          Log.i('IndexedDB opened successfully');
          completer.complete(Ok(db));
        } catch (e) {
          Log.e('Error accessing IndexedDB result: $e');
          completer.complete(Err(DbError.connectionError('Failed to access database: $e')));
        }
      }).toJS;

      request.onerror = ((web.Event event) {
        final error = (event.target as web.IDBOpenDBRequest).error;
        Log.e('IndexedDB open failed: $error');
        completer.complete(Err(DbError.connectionError('Failed to open IndexedDB: $error')));
      }).toJS;

      request.onblocked = ((web.Event event) {
        Log.w('IndexedDB open blocked - another connection might be open');
        completer.complete(Err(DbError.connectionError('Database connection blocked')));
      }).toJS;

    } catch (e, stackTrace) {
      Log.e('Exception opening IndexedDB', error: e, stackTrace: stackTrace);
      return Err(DbError.connectionError('IndexedDB not supported or failed: $e'));
    }

    return completer.future;
  }

  /// Stores an entry in IndexedDB using the transaction manager
  Future<DbResult<DbEntry>> _storeEntry(DbEntry entry) async {
    return await _transactionManager!.executeWriteOperation((store) async {
      final record = JSObjectConverter.entryToJSObject(entry);
      final request = store.put(record.jsify()!);
      
      final result = await _transactionManager!.createVoidRequestOperation(
        request,
        operationName: 'store(${entry.id})',
      );

      return result.when(
        ok: (_) {
          Log.i('Record stored successfully: ${entry.id}');
          return Ok(entry);
        },
        err: (error) => Err(error),
      );
    });
  }
}