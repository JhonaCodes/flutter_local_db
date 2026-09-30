import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';

import '../../models/local_db_error.dart';
import '../../models/local_db_model.dart';
import '../../models/local_db_result.dart';
import '../../native/native_worker.dart';

/// The key-value storage of [LocalDB] on native platforms.
///
/// Every call runs in the database worker isolate (see [NativeWorker]), so it
/// never blocks the UI isolate, and every response is released by the native
/// library. Records keep the layout of 1.x: one JSON document per key.
class DatabaseCore {
  DatabaseCore._(this._worker, this._handle);

  final NativeWorker _worker;
  final int _handle;
  bool _isClosed = false;

  /// Opens the database at `<path>.lmdb`.
  ///
  /// Fails with [LocalDbErrorType.legacyFormat] for a database written by
  /// flutter_local_db 1.x, which LMDB 1.0 cannot read (the files are left
  /// untouched).
  static Future<LocalDbResult<DatabaseCore, ErrorLocalDb>> create(
    String path,
  ) async {
    try {
      final worker = await NativeWorker.shared();
      final (handle, response) = await worker.open(path, null);
      if (handle == 0) {
        final error =
            (jsonDecode(response) as Map<String, dynamic>)['error']
                as Map<String, dynamic>?;
        final code = error?['code'] as String?;
        final message = error?['message'] as String? ?? response;
        return Err(
          code == 'LegacyFormat'
              ? ErrorLocalDb.legacyFormat(message, context: path)
              : ErrorLocalDb.initialization(message, context: path),
        );
      }
      Log.i('Database opened at $path');
      return Ok(DatabaseCore._(worker, handle));
    } on Object catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.ffiError(
          'Cannot open the database',
          context: path,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Calls a function of the key-value C API and splits its envelope
  /// `{"<Variant>": "<payload>"}`.
  Future<LocalDbResult<(String, String), ErrorLocalDb>> _call(
    String function,
    String? argument,
    String context,
  ) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }
    try {
      final response = await _worker.legacy(_handle, function, argument);
      final envelope = jsonDecode(response) as Map<String, dynamic>;
      final MapEntry(:key, :value) = envelope.entries.single;
      return Ok((key, value.toString()));
    } on Object catch (e, stackTrace) {
      return Err(
        ErrorLocalDb.ffiError(
          'Native call $function failed',
          context: context,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  ErrorLocalDb _failure(String variant, String payload, String context) {
    return switch (variant) {
      'NotFound' => ErrorLocalDb.notFound(payload, context: context),
      'SerializationError' => ErrorLocalDb.serializationError(
        payload,
        context: context,
      ),
      'ValidationError' ||
      'BadRequest' => ErrorLocalDb.validationError(payload, context: context),
      _ => ErrorLocalDb.databaseError(payload, context: context),
    };
  }

  LocalDbResult<void, ErrorLocalDb> _validate(String key) {
    if (key.isEmpty || utf8.encode(key).length > 511) {
      return Err(
        ErrorLocalDb.validationError(
          'Keys must be 1 to 511 bytes long',
          context: key,
        ),
      );
    }
    return const Ok(null);
  }

  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> _write(
    String function,
    String key,
    Map<String, dynamic> data,
  ) async {
    final validation = _validate(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }
    final model = LocalDbModel(id: key, data: data);
    final result = await _call(function, model.toJson(), key);
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        return variant == 'Ok'
            ? Ok(model)
            : Err(_failure(variant, payload, key));
      },
      err: Err.new,
    );
  }

  /// Stores [data] under [key], replacing an existing record.
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(
    String key,
    Map<String, dynamic> data,
  ) => _write('push_data', key, data);

  /// Same as [put] (1.x semantics: `Post` replaces an existing record).
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(
    String key,
    Map<String, dynamic> data,
  ) => _write('push_data', key, data);

  /// Replaces the existing record [key]; fails with `notFound` otherwise.
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> update(
    String key,
    Map<String, dynamic> data,
  ) => _write('update_data', key, data);

  /// The record [key]; fails with `notFound` when it does not exist.
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> get(String key) async {
    final validation = _validate(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }
    final result = await _call('get_by_id', key, key);
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        if (variant != 'Ok') {
          return Err(_failure(variant, payload, key));
        }
        try {
          return Ok(LocalDbModel.fromJson(payload));
        } on Object catch (e) {
          return Err(
            ErrorLocalDb.serializationError(
              'Stored record is not valid',
              context: key,
              cause: e,
            ),
          );
        }
      },
      err: Err.new,
    );
  }

  /// Deletes the record [key]; succeeds when it did not exist.
  Future<LocalDbResult<void, ErrorLocalDb>> delete(String key) async {
    final validation = _validate(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }
    final result = await _call('delete_by_id', key, key);
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        return variant == 'Ok' || variant == 'NotFound'
            ? const Ok(null)
            : Err(_failure(variant, payload, key));
      },
      err: Err.new,
    );
  }

  /// Every record, by key.
  Future<LocalDbResult<Map<String, LocalDbModel>, ErrorLocalDb>>
  getAll() async {
    final result = await _call('get_all', null, 'get_all');
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        if (variant != 'Ok') {
          return Err(_failure(variant, payload, 'get_all'));
        }
        try {
          final records = jsonDecode(payload) as List<dynamic>;
          return Ok({
            for (final record in records.cast<Map<String, dynamic>>())
              record['id'] as String: LocalDbModel.fromMap(record),
          });
        } on Object catch (e) {
          return Err(
            ErrorLocalDb.serializationError(
              'Stored records are not valid',
              cause: e,
            ),
          );
        }
      },
      err: Err.new,
    );
  }

  /// Deletes every record.
  Future<LocalDbResult<void, ErrorLocalDb>> clear() async {
    final result = await _call('clear_all_records', null, 'clear');
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        return variant == 'Ok'
            ? const Ok(null)
            : Err(_failure(variant, payload, 'clear'));
      },
      err: Err.new,
    );
  }

  /// Whether [close] was called.
  bool get isClosed => _isClosed;

  /// Releases the database handle. Later calls fail with a database error.
  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _worker.close(_handle).ignore();
  }
}
