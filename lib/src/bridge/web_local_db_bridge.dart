import 'dart:async';
import 'dart:developer';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:flutter_local_db/src/interface/local_db_request_impl.dart';
import 'package:flutter_local_db/src/model/local_db_error_model.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:flutter_local_db/src/service/local_db_result.dart';

/// Web implementation of LocalDB using native IndexedDB APIs
/// This implementation provides the same interface as the FFI bridge
/// but uses browser's IndexedDB for storage
class WebLocalDbBridge extends LocalSbRequestImpl {
  WebLocalDbBridge._();

  static final WebLocalDbBridge instance = WebLocalDbBridge._();

  web.IDBDatabase? _database;
  String? _databaseName;
  static const String _storeName = 'local_db_records';
  static const int _databaseVersion = 1;

  /// Initialize the web database with IndexedDB
  Future<void> initialize(String databaseName) async {
    try {
      log('Initializing IndexedDB database: $databaseName');
      
      if (!databaseName.endsWith('.db')) {
        databaseName = '$databaseName.db';
      }
      
      _databaseName = databaseName;
      
      final idbFactory = web.window.indexedDB;
      // IndexedDB should always be available in modern browsers

      final openRequest = idbFactory.open(databaseName, _databaseVersion);
      
      // Handle database upgrade/creation
      openRequest.addEventListener('upgradeneeded', (web.Event event) {
        final db = openRequest.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName, web.IDBObjectStoreParameters(keyPath: 'id'.toJS));
          log('Created object store: $_storeName');
        }
      }.toJS);

      // Wait for database to open
      final completer = Completer<web.IDBDatabase>();
      
      openRequest.addEventListener('success', (web.Event event) {
        _database = openRequest.result as web.IDBDatabase;
        log('IndexedDB database opened successfully');
        completer.complete(_database!);
      }.toJS);

      openRequest.addEventListener('error', (web.Event event) {
        final error = 'Failed to open IndexedDB: ${openRequest.error}';
        log(error);
        completer.completeError(Exception(error));
      }.toJS);

      await completer.future;
      
    } catch (e, stackTrace) {
      log('Error initializing IndexedDB: $e');
      log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if the database connection is valid
  bool get isConnectionValid => _database != null && _database!.objectStoreNames.length > 0;

  /// Manually close the database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      _database!.close();
      _database = null;
      log('IndexedDB database closed');
    }
  }

  /// Ensure connection is valid, reinitialize if needed
  Future<bool> ensureConnectionValid() async {
    if (!isConnectionValid && _databaseName != null) {
      try {
        await initialize(_databaseName!);
        return true;
      } catch (e) {
        log('Failed to reinitialize IndexedDB connection: $e');
        return false;
      }
    }
    return isConnectionValid;
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      
      // Check if record already exists
      final existingRequest = store.get(model.id.toJS);
      final existing = await _completeRequest(existingRequest);
      
      if (existing != null) {
        return Err(ErrorLocalDb.databaseError(
            "Cannot create new record: ID '${model.id}' already exists. Use PUT method to update existing records."));
      }

      // Create the record
      final recordData = <String, dynamic>{
        'id': model.id,
        'hash': model.hash,
        'data': model.data,
      };

      final addRequest = store.put(recordData.jsify());
      await _completeRequest(addRequest);
      
      log('Record created with ID: ${model.id}');
      return Ok(model);
      
    } catch (e, stackTrace) {
      log('Error in post operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);
      
      final request = store.get(id.toJS);
      final result = await _completeRequest(request);
      
      if (result == null) {
        return Ok(null);
      }

      final jsObject = result as JSObject;
      final recordMap = jsObject.dartify() as Map<String, dynamic>;
      final model = LocalDbModel(
        id: recordMap['id'] as String,
        hash: recordMap['hash'] as String?,
        data: Map<String, dynamic>.from(recordMap['data'] as Map),
      );

      return Ok(model);
      
    } catch (e, stackTrace) {
      log('Error in getById operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);
      
      final request = store.openCursor();
      final models = <LocalDbModel>[];
      
      final allResults = await _getAllFromCursor(request);
      for (final result in allResults) {
        final jsObject = result as JSObject;
        final recordMap = jsObject.dartify() as Map<String, dynamic>;
        final model = LocalDbModel(
          id: recordMap['id'] as String,
          hash: recordMap['hash'] as String?,
          data: Map<String, dynamic>.from(recordMap['data'] as Map),
        );
        models.add(model);
      }

      return Ok(models);
      
    } catch (e, stackTrace) {
      log('Error in getAll operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      
      // Check if record exists
      final existingRequest = store.get(model.id.toJS);
      final existing = await _completeRequest(existingRequest);
      
      if (existing == null) {
        return Err(ErrorLocalDb.notFound(
            "Record '${model.id}' not found. Use POST method to create new records."));
      }

      // Update the record
      final recordData = <String, dynamic>{
        'id': model.id,
        'hash': model.hash,
        'data': model.data,
      };

      final putRequest = store.put(recordData.jsify());
      await _completeRequest(putRequest);
      
      log('Record updated with ID: ${model.id}');
      return Ok(model);
      
    } catch (e, stackTrace) {
      log('Error in put operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      
      // Check if record exists
      final existingRequest = store.get(id.toJS);
      final existing = await _completeRequest(existingRequest);
      
      if (existing == null) {
        return Err(ErrorLocalDb.notFound("No record found with id: $id"));
      }

      // Delete the record
      final deleteRequest = store.delete(id.toJS);
      await _completeRequest(deleteRequest);
      
      log('Record deleted with ID: $id');
      return Ok(true);
      
    } catch (e, stackTrace) {
      log('Error in delete operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      
      final clearRequest = store.clear();
      await _completeRequest(clearRequest);
      
      log('Database cleared successfully');
      return Ok(true);
      
    } catch (e, stackTrace) {
      log('Error in cleanDatabase operation: $e');
      log('Stack trace: $stackTrace');
      return Err(ErrorLocalDb.fromRustError(e.toString(), 
          originalError: e, stackTrace: stackTrace));
    }
  }

  /// Helper method to complete IndexedDB requests
  Future<dynamic> _completeRequest(web.IDBRequest request) async {
    final completer = Completer<dynamic>();
    
    request.addEventListener('success', (web.Event event) {
      completer.complete(request.result);
    }.toJS);
    
    request.addEventListener('error', (web.Event event) {
      completer.completeError(Exception('IndexedDB request failed: ${request.error}'));
    }.toJS);
    
    return completer.future;
  }

  /// Helper method to get all results from cursor
  Future<List<dynamic>> _getAllFromCursor(web.IDBRequest request) async {
    final completer = Completer<List<dynamic>>();
    final results = <dynamic>[];
    
    request.addEventListener('success', (web.Event event) {
      final cursor = request.result as web.IDBCursorWithValue?;
      if (cursor != null) {
        results.add(cursor.value);
        cursor.continue_();
      } else {
        completer.complete(results);
      }
    }.toJS);
    
    request.addEventListener('error', (web.Event event) {
      completer.completeError(Exception('Cursor request failed: ${request.error}'));
    }.toJS);
    
    return completer.future;
  }
}