import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/log.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';
import 'database_interface.dart';

/// JavaScript interop types for IndexedDB using web package types

/// Web database implementation using IndexedDB with dart:js_interop
/// This implementation is used for web platforms
class DatabaseWeb implements DatabaseInterface {
  static DatabaseWeb? _instance;
  
  web.IDBDatabase? _database;
  String? _databaseName;
  static const String _storeName = 'local_db_records';
  static const int _databaseVersion = 1;

  DatabaseWeb._();

  static DatabaseWeb get instance {
    _instance ??= DatabaseWeb._();
    return _instance!;
  }

  @override
  bool get isSupported => true; // IndexedDB is always available in modern browsers

  @override
  String get platformName => 'web';

  @override
  String? get currentDatabaseName => _databaseName;

  @override
  Future<void> initialize(String databaseName) async {
    try {
      Log.i('Initializing IndexedDB database: $databaseName');

      if (!databaseName.endsWith('.db')) {
        databaseName = '$databaseName.db';
      }

      _databaseName = databaseName;

      if (!isSupported) {
        throw Exception('IndexedDB is not supported in this browser');
      }

      final idbFactory = web.window.indexedDB;
      final openRequest = idbFactory.open(databaseName, _databaseVersion);

      // Setup upgrade handler
      openRequest.onupgradeneeded = ((web.Event event) {
        final db = openRequest.result as web.IDBDatabase;
        final storeNames = db.objectStoreNames;
        final containsStore = storeNames.toString().contains(_storeName);
        if (!containsStore) {
          db.createObjectStore(_storeName);
          Log.i('Created object store: $_storeName');
        }
      }).toJS;

      _database = await _completeRequest<web.IDBDatabase>(openRequest);
      Log.i('IndexedDB database opened successfully');
    } catch (e, stackTrace) {
      Log.e('Error initializing IndexedDB', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> ensureConnectionValid() async {
    if (_database == null && _databaseName != null) {
      try {
        await initialize(_databaseName!);
        return true;
      } catch (e) {
        Log.e('Failed to reinitialize IndexedDB connection', error: e);
        return false;
      }
    }
    return _database != null;
  }

  @override
  Future<void> closeDatabase() async {
    if (_database != null) {
      _database!.close();
      _database = null;
      Log.i('IndexedDB database closed');
    }
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> post(
    LocalDbModel model,
  ) async {
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
        return Err(
          ErrorLocalDb.databaseError(
            "Cannot create new record: ID '${model.id}' already exists. Use PUT method to update existing records.",
          ),
        );
      }

      // Create the record
      final recordData = _modelToJSObject(model);
      final addRequest = store.put(recordData);
      await _completeRequest(addRequest);

      Log.i('Record created with ID: ${model.id}');
      return Ok(model);
    } catch (e, stackTrace) {
      Log.e('Error in post operation', error: e, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
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

      final model = _jsObjectToModel(result);
      return Ok(model);
    } catch (e, stackTrace) {
      Log.e('Error in getById operation', error: e, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);

      final request = store.openCursor();
      final models = <LocalDbModel>[];

      await for (final cursor in _streamCursor(request)) {
        if (cursor == null) break;

        // For now, skip cursor iteration - will be fixed in next iteration
        break;
        // models.add(model);
        // cursor.continue_();
      }

      return Ok(models);
    } catch (e, stackTrace) {
      Log.e('Error in getAll operation', error: e, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> put(
    LocalDbModel model,
  ) async {
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
        return Err(
          ErrorLocalDb.notFound(
            "Record '${model.id}' not found. Use POST method to create new records.",
          ),
        );
      }

      // Update the record
      final recordData = _modelToJSObject(model);
      final putRequest = store.put(recordData);
      await _completeRequest(putRequest);

      Log.i('Record updated with ID: ${model.id}');
      return Ok(model);
    } catch (e, stackTrace) {
      Log.e('Error in put operation', error: e, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
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

      Log.i('Record deleted with ID: $id');
      return Ok(true);
    } catch (e, stackTrace) {
      Log.e('Error in delete operation', error: e, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final transaction = _database!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);

      final clearRequest = store.clear();
      await _completeRequest(clearRequest);

      Log.i('Database cleared successfully');
      return Ok(true);
    } catch (e, stackTrace) {
      Log.e(
        'Error in cleanDatabase operation',
        error: e,
        stackTrace: stackTrace,
      );
      return Err(
        ErrorLocalDb.fromRustError(
          e.toString(),
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Helper method to complete IndexedDB requests
  Future<T?> _completeRequest<T>(web.IDBRequest request) async {
    final completer = Completer<T?>();

    request.onsuccess = ((JSObject event) {
      completer.complete(request.result as T?);
    }).toJS;

    request.onerror = ((JSObject event) {
      final error = request.error;
      completer.completeError(
        Exception('IndexedDB request failed: ${error?.name}'),
      );
    }).toJS;

    return completer.future;
  }

  /// Helper method to stream cursor results
  Stream<web.IDBCursor?> _streamCursor(web.IDBRequest request) async* {
    final completer = Completer<web.IDBCursor?>();

    request.onsuccess = ((JSObject event) {
      completer.complete(request.result as web.IDBCursor?);
    }).toJS;

    request.onerror = ((JSObject event) {
      completer.completeError(
        Exception('Cursor request failed: ${request.error?.name}'),
      );
    }).toJS;

    web.IDBCursor? cursor = await completer.future;

    while (cursor != null) {
      yield cursor;

      final nextCompleter = Completer<web.IDBCursor?>();
      request.onsuccess = ((JSObject event) {
        nextCompleter.complete(request.result as web.IDBCursor?);
      }).toJS;

      request.onerror = ((JSObject event) {
        nextCompleter.completeError(Exception('Cursor continuation failed'));
      }).toJS;

      cursor = await nextCompleter.future;
    }
  }

  /// Convert LocalDbModel to JavaScript object
  JSAny _modelToJSObject(LocalDbModel model) {
    // Simple object creation using JSON string conversion
    final jsonString = jsonEncode({
      'id': model.id,
      'hash': model.hash,
      'data': jsonEncode(model.data),
    });
    return jsonString.toJS;
  }

  /// Convert JavaScript object to LocalDbModel
  LocalDbModel _jsObjectToModel(JSAny jsObject) {
    final obj = jsObject.dartify() as Map<String, dynamic>;
    final id = obj['id'] as String;
    final hash = obj['hash'] as String?;
    final dataJson = obj['data'] as String;
    final data = Map<String, dynamic>.from(jsonDecode(dataJson));

    return LocalDbModel(id: id, hash: hash, data: data);
  }
}
