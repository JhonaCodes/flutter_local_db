// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                         DATABASE CORE (NATIVE)                               ║
// ║                    Native FFI Implementation of Database                     ║
// ║══════════════════════════════════════════════════════════════════════════════║

import 'dart:ffi';
import 'dart:convert';
import '../../models/local_db_result.dart';
import '../../models/local_db_error.dart';
import '../../models/local_db_model.dart';
import '../ffi_bindings.dart';
import '../ffi_functions.dart';

import 'package:logger_rs/logger_rs.dart';

/// Parses Rust AppResponse format into normalized response map.
Map<String, dynamic> _parseRustResponse(Map<String, dynamic> response) {
  return switch (response) {
    {'Ok': final data} => {'status': 'ok', 'data': data},
    {'NotFound': final msg} => {'status': 'not_found', 'message': msg},
    {'DatabaseError': final msg} => {'status': 'error', 'message': msg},
    {'SerializationError': final msg} => {'status': 'error', 'message': msg},
    {'ValidationError': final msg} => {
      'status': 'validation_error',
      'message': msg,
    },
    {'BadRequest': final msg} => {'status': 'bad_request', 'message': msg},
    _ => response,
  };
}

/// Core database operations engine (Native FFI)
class DatabaseCore {
  final LocalDbBindings _bindings;
  final Pointer<Void> _dbHandle;
  bool _isClosed = false;

  DatabaseCore._(this._bindings, this._dbHandle);

  /// Creates a new database instance (Native)
  static Future<LocalDbResult<DatabaseCore, ErrorLocalDb>> create(
    Object? bindings,
    String path,
  ) async {
    Log.i('Creating native database at: $path');

    if (bindings == null || bindings is! LocalDbBindings) {
      return Err(
        ErrorLocalDb.initialization(
          'Invalid bindings provided for native implementation',
          context: path,
        ),
      );
    }

    if (path.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database path cannot be empty',
          context: 'path_validation',
        ),
      );
    }

    final pathPtr = FfiUtils.toCString(path);

    try {
      final dbHandle = bindings.createDb(pathPtr);

      if (FfiUtils.isNull(dbHandle)) {
        Log.e('Database creation returned null handle');
        return Err(
          ErrorLocalDb.initialization(
            'Failed to create database - null handle returned',
            context: path,
          ),
        );
      }

      Log.i('Database created successfully with handle: $dbHandle');
      return Ok(DatabaseCore._(bindings, dbHandle));
    } catch (e, stackTrace) {
      Log.e('Exception during database creation: $e');
      return Err(
        ErrorLocalDb.initialization(
          'Exception during database creation',
          context: path,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(pathPtr);
    }
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('Storing data with key: $key');

    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    final model = LocalDbModel(id: key, data: data);
    final jsonString = model.toJson();
    final jsonPtr = FfiUtils.toCString(jsonString);

    try {
      final resultPtr = _bindings.pushData(_dbHandle, jsonPtr);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(
          ErrorLocalDb.databaseError(
            'Native put operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          return Ok(model);
        } else {
          final errorMsg = response['message'] ?? 'Put operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during put operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(jsonPtr);
    }
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(
    String key,
    Map<String, dynamic> data,
  ) async {
    return put(key, data);
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> update(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    Log.d('Updating data with key: $key');

    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    final model = LocalDbModel(id: key, data: data);
    final jsonString = model.toJson();
    final jsonPtr = FfiUtils.toCString(jsonString);

    try {
      final resultPtr = _bindings.updateData(_dbHandle, jsonPtr);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(
          ErrorLocalDb.databaseError(
            'Native update operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          return Ok(model);
        } else if (response['status'] == 'not_found') {
          return Err(
            ErrorLocalDb.notFound('Record not found for update', context: key),
          );
        } else {
          final errorMsg = response['message'] ?? 'Update operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during update operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(jsonPtr);
    }
  }

  Future<LocalDbResult<void, ErrorLocalDb>> reset(String name) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    if (name.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Database name cannot be empty',
          context: 'reset_operation',
        ),
      );
    }

    final namePtr = FfiUtils.toCString(name);

    try {
      final resultPtr = _bindings.resetDatabase(_dbHandle, namePtr);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(ErrorLocalDb.databaseError('Native reset operation failed'));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(ErrorLocalDb.databaseError('Failed to convert response'));
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Reset operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during reset operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(namePtr);
    }
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> get(String key) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return Err(keyValidation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      final resultPtr = _bindings.getById(_dbHandle, keyPtr);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(ErrorLocalDb.notFound('Record not found', context: key));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);

      if (responseStr == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null response from database',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          final jsonData = response['data'];
          if (jsonData != null) {
            final jsonString = jsonData is String
                ? jsonData
                : jsonEncode(jsonData);
            final model = LocalDbModel.fromJson(jsonString);
            return Ok(model);
          } else {
            return Err(ErrorLocalDb.notFound('Record not found', context: key));
          }
        } else if (response['status'] == 'not_found') {
          return Err(ErrorLocalDb.notFound('Record not found', context: key));
        } else {
          final errorMsg = response['message'] ?? 'Get operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during get operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
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

    final keyPtr = FfiUtils.toCString(key);

    try {
      final resultPtr = _bindings.deleteById(_dbHandle, keyPtr);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(
          ErrorLocalDb.databaseError(
            'Native delete operation failed',
            context: key,
          ),
        );
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(
          ErrorLocalDb.databaseError(
            'Failed to convert response',
            context: key,
          ),
        );
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          return const Ok(null);
        } else if (response['status'] == 'not_found') {
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Delete operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg, context: key));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError(
            'Failed to parse response',
            context: key,
            cause: e,
          ),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during delete operation',
          context: key,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  Future<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>>
  getAll() async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    try {
      final resultPtr = _bindings.getAll(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        return const Ok({});
      }

      final jsonString = FfiUtils.fromCString(resultPtr);

      if (jsonString == null) {
        return Err(
          ErrorLocalDb.serializationError(
            'Received null JSON string for all data',
          ),
        );
      }

      try {
        final rawResponse = json.decode(jsonString) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          final data = response['data'];
          final List<dynamic> items = data is String
              ? json.decode(data) as List<dynamic>
              : (data is List ? data : []);

          final result = <String, LocalDbModel>{};
          for (final item in items) {
            try {
              final jsonString = item is String ? item : jsonEncode(item);
              final model = LocalDbModel.fromJson(jsonString);
              result[model.id] = model;
            } catch (e) {
              Log.w(' Failed to deserialize record: $e');
            }
          }
          return Ok(result);
        } else {
          final errorMsg = response['message'] ?? 'GetAll operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during getAll operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<LocalDbResult<void, ErrorLocalDb>> clear() async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    try {
      final resultPtr = _bindings.clearAllRecords(_dbHandle);

      if (FfiUtils.isNull(resultPtr)) {
        return Err(ErrorLocalDb.databaseError('Native clear operation failed'));
      }

      final responseStr = FfiUtils.fromCString(resultPtr);
      if (responseStr == null) {
        return Err(ErrorLocalDb.databaseError('Failed to convert response'));
      }

      try {
        final rawResponse = json.decode(responseStr) as Map<String, dynamic>;
        final response = _parseRustResponse(rawResponse);

        if (response['status'] == 'ok') {
          return const Ok(null);
        } else {
          final errorMsg = response['message'] ?? 'Clear operation failed';
          return Err(ErrorLocalDb.databaseError(errorMsg));
        }
      } catch (e) {
        return Err(
          ErrorLocalDb.serializationError('Failed to parse response', cause: e),
        );
      }
    } catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.databaseError(
          'Exception during clear operation',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void close() {
    if (_isClosed) {
      return;
    }

    try {
      final resultPtr = _bindings.closeDatabase(_dbHandle);

      if (FfiUtils.isNotNull(resultPtr)) {
        // Optionally parse response
      }

      _isClosed = true;
    } catch (e) {
      Log.e(' Exception during database close: $e');
    }
  }

  bool get isClosed => _isClosed;

  LocalDbResult<void, ErrorLocalDb> _validateKey(String key) {
    if (key.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'Key cannot be empty',
          context: 'key_validation',
        ),
      );
    }

    if (key.length > FfiConstants.maxKeyLength) {
      return Err(
        ErrorLocalDb.validationError(
          'Key exceeds maximum length (${FfiConstants.maxKeyLength} bytes)',
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
      final jsonString = jsonEncode(data);
      if (jsonString.length > FfiConstants.maxValueSize) {
        return Err(
          ErrorLocalDb.validationError(
            'Data exceeds maximum size (${FfiConstants.maxValueSize} bytes)',
            context: 'key: $key, size: ${jsonString.length}',
          ),
        );
      }
    } catch (e) {
      return Err(
        ErrorLocalDb.validationError(
          'Data is not JSON serializable',
          context: 'key: $key',
          cause: e,
        ),
      );
    }

    return const Ok(null);
  }
}
