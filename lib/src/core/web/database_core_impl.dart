// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                         DATABASE CORE (WEB)                                  ║
// ║                   Web Implementation of Database (IndexedDB)                 ║
// ║══════════════════════════════════════════════════════════════════════════════║

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../../models/local_db_result.dart';
import '../../models/local_db_error.dart';
import '../../models/local_db_model.dart';
import 'package:logger_rs/logger_rs.dart';

/// Core database operations engine (Web IndexedDB)
class DatabaseCore {
  static const int _maxKeyLength = 511;
  static const int _maxValueSize = 10 * 1024 * 1024; // 10MB

  final web.IDBDatabase _db;
  final String _storeName;
  bool _isClosed = false;

  DatabaseCore._(this._db, this._storeName);

  /// Creates a new database instance (Web)
  static Future<LocalDbResult<DatabaseCore, ErrorLocalDb>> create(
    Object? bindings,
    String path,
  ) async {
    Log.i('Initializing Web Database (IndexedDB): $path');

    if (path.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database name cannot be empty',
          context: 'path_validation',
        ),
      );
    }

    final dbName = path.replaceAll('/', '_');
    final storeName = 'records';

    final completer = Completer<LocalDbResult<DatabaseCore, ErrorLocalDb>>();

    final request = web.window.indexedDB.open(dbName, 1);

    request.onupgradeneeded = (web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(storeName)) {
        db.createObjectStore(
          storeName,
          web.IDBObjectStoreParameters(keyPath: 'id'.toJS),
        );
      }
    }.toJS;

    request.onsuccess = (web.Event event) {
      final db = request.result as web.IDBDatabase;
      Log.i('Web Database opened successfully: $dbName');
      completer.complete(Ok(DatabaseCore._(db, storeName)));
    }.toJS;

    request.onerror = (web.Event event) {
      Log.e('Failed to open Web Database: ${request.error?.message}');
      completer.complete(
        Err(
          ErrorLocalDb.initialization(
            'Failed to open IndexedDB',
            context: path,
            cause: request.error?.message,
          ),
        ),
      );
    }.toJS;

    return completer.future;
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    try {
      final model = LocalDbModel(id: key, data: data);
      final jsData = _serializeModel(model);

      final transaction = _db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      final request = store.put(jsData);

      final completer = Completer<LocalDbResult<LocalDbModel, ErrorLocalDb>>();

      request.onsuccess = (web.Event e) {
        completer.complete(Ok(model));
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(
          Err(
            ErrorLocalDb.databaseError(
              'Failed to put record',
              context: key,
              cause: request.error?.message,
            ),
          ),
        );
      }.toJS;

      return completer.future;
    } catch (e, s) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during put',
          context: key,
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(
    String key,
    Map<String, dynamic> data,
  ) {
    return put(key, data);
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> update(
    String key,
    Map<String, dynamic> data,
  ) async {
    final exists = await get(key);
    if (exists.isErr) {
      return Err(
        ErrorLocalDb.notFound('Record not found for update', context: key),
      );
    }
    return put(key, data);
  }

  Future<LocalDbResult<void, ErrorLocalDb>> reset(String name) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    final completer = Completer<LocalDbResult<void, ErrorLocalDb>>();

    _db.close();
    _isClosed = true;

    // Fixed: removed .toDart, name is already String
    final request = web.window.indexedDB.deleteDatabase(_db.name);

    request.onsuccess = (web.Event e) {
      completer.complete(const Ok(null));
    }.toJS;

    request.onerror = (web.Event e) {
      completer.complete(
        Err(ErrorLocalDb.databaseError('Failed to delete database')),
      );
    }.toJS;

    return completer.future;
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> get(String key) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    try {
      final transaction = _db.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);
      final request = store.get(key.toJS);

      final completer = Completer<LocalDbResult<LocalDbModel, ErrorLocalDb>>();

      request.onsuccess = (web.Event e) {
        final result = request.result;
        if (result != null && !result.isUndefined && !result.isNull) {
          try {
            final dartMap = (result as JSObject).dartify() as Map;
            final model = _deserializeModel(Map<String, dynamic>.from(dartMap));
            completer.complete(Ok(model));
          } catch (e) {
            completer.complete(
              Err(
                ErrorLocalDb.serializationError(
                  'Failed to parse IDB record',
                  cause: e,
                ),
              ),
            );
          }
        } else {
          completer.complete(
            Err(ErrorLocalDb.notFound('Record not found', context: key)),
          );
        }
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(
          Err(ErrorLocalDb.databaseError('Get failed', context: key)),
        );
      }.toJS;

      return completer.future;
    } catch (e) {
      return Err(ErrorLocalDb.databaseError('Exception during get', cause: e));
    }
  }

  Future<LocalDbResult<void, ErrorLocalDb>> delete(String key) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    try {
      final transaction = _db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      final request = store.delete(key.toJS);

      final completer = Completer<LocalDbResult<void, ErrorLocalDb>>();

      request.onsuccess = (web.Event e) {
        completer.complete(const Ok(null));
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(
          Err(ErrorLocalDb.databaseError('Delete failed', context: key)),
        );
      }.toJS;

      return completer.future;
    } catch (e) {
      return Err(
        ErrorLocalDb.databaseError('Exception during delete', cause: e),
      );
    }
  }

  Future<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>>
  getAll() async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    try {
      final transaction = _db.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);
      final request = store.getAll(null);

      final completer =
          Completer<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>>();

      request.onsuccess = (web.Event e) {
        final result = request.result;
        if (result == null || result.isUndefined || result.isNull) {
          completer.complete(const Ok({}));
          return;
        }

        final dartList = (result as JSArray).toDart;
        final resultMap = <String, LocalDbModel>{};
        for (final item in dartList) {
          if (item != null && !item.isUndefined && !item.isNull) {
            try {
              final map = (item as JSObject).dartify() as Map;
              final model = _deserializeModel(Map<String, dynamic>.from(map));
              resultMap[model.id] = model;
            } catch (e) {
              Log.w('Failed to deserialize record: $e');
            }
          }
        }
        completer.complete(Ok(resultMap));
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(Err(ErrorLocalDb.databaseError('GetAll failed')));
      }.toJS;

      return completer.future;
    } catch (e) {
      return Err(
        ErrorLocalDb.databaseError('Exception during getAll', cause: e),
      );
    }
  }

  Future<LocalDbResult<void, ErrorLocalDb>> clear() async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    try {
      final transaction = _db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      final request = store.clear();

      final completer = Completer<LocalDbResult<void, ErrorLocalDb>>();

      request.onsuccess = (web.Event e) {
        completer.complete(const Ok(null));
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(Err(ErrorLocalDb.databaseError('Clear failed')));
      }.toJS;

      return completer.future;
    } catch (e) {
      return Err(
        ErrorLocalDb.databaseError('Exception during clear', cause: e),
      );
    }
  }

  void close() {
    if (!_isClosed) {
      _db.close();
      _isClosed = true;
    }
  }

  bool get isClosed => _isClosed;

  /// Custom serializer to ensure timestamps and hash are preserved
  JSAny _serializeModel(LocalDbModel model) {
    final map = {
      'id': model.id,
      'data': model.data,
      'createdAt': model.createdAt.toIso8601String(),
      'updatedAt': model.updatedAt.toIso8601String(),
      'contentHash': model.contentHash,
    };
    return map.jsify()!;
  }

  /// Custom deserializer to reconstruct model from Map
  LocalDbModel _deserializeModel(Map<String, dynamic> map) {
    return LocalDbModel(
      id: map['id'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      contentHash: map['contentHash'] as String?,
    );
  }

  LocalDbResult<void, ErrorLocalDb> _validateKey(String key) {
    if (key.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Key cannot be empty',
          context: 'key_validation',
        ),
      );
    }

    if (key.length > _maxKeyLength) {
      return Err(
        ErrorLocalDb.validationError(
          'Key exceeds maximum length ($_maxKeyLength bytes)',
          context: 'key: $key',
        ),
      );
    }

    return const Ok(null);
  }

  LocalDbResult<void, ErrorLocalDb> _validateKeyAndData(
    String key,
    Map<String, dynamic> data,
  ) {
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return keyValidation;
    }

    try {
      final jsonString = data.toString();
      if (jsonString.length > _maxValueSize) {
        return Err(
          ErrorLocalDb.validationError(
            'Data exceeds maximum size ($_maxValueSize bytes)',
            context: 'key: $key, size: ${jsonString.length}',
          ),
        );
      }
    } catch (e) {
      return Err(
        ErrorLocalDb.validationError(
          'Data is not serializable',
          context: 'key: $key',
          cause: e,
        ),
      );
    }

    return const Ok(null);
  }
}
