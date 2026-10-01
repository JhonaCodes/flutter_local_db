import 'dart:convert';

import 'package:db_dsl/db_dsl.dart' show DbErrorCode;
import 'package:db_dsl/native.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:result_controller/result_controller.dart';

import '../../models/local_db_error.dart';
import '../local_db_keys.dart';
import '../../models/local_db_model.dart';
import '../../native/offline_first_core.dart';

/// The key-value storage of [LocalDB] on native platforms.
///
/// Every call runs on the worker isolate of db_dsl (see [NativeKeyValueStore]),
/// so it never blocks the UI isolate, and every response is released by the
/// native library. Records keep the layout of 1.x: one JSON document per key.
class DatabaseCore {
  DatabaseCore._(this._store);

  final NativeKeyValueStore _store;
  bool _isClosed = false;

  /// Opens the database at `<path>.lmdb`.
  ///
  /// Fails with [LocalDbErrorType.legacyFormat] for a database written by
  /// flutter_local_db 1.x, which LMDB 1.0 cannot read (the files are left
  /// untouched).
  static Future<Result<DatabaseCore, ErrorLocalDb>> create(String path) async =>
      (await NativeKeyValueStore.open(OfflineFirstCore.symbols, path)).when(
        ok: (store) {
          Log.d('Key-value database opened at $path');
          return Ok(DatabaseCore._(store));
        },
        err: (error) => Err(switch (error.code) {
          DbErrorCode.legacyFormat => ErrorLocalDb.legacyFormat(
            error.message,
            context: path,
          ),
          _ => ErrorLocalDb.initialization(error.message, context: path),
        }),
      );

  /// Calls a function of the key-value C API and splits its envelope
  /// `{"<Variant>": "<payload>"}`.
  Future<Result<(String, String), ErrorLocalDb>> _call(
    KeyValueCall call,
    String? argument,
    String context,
  ) async {
    if (_isClosed) {
      return Err(ErrorLocalDb.databaseError('Database is closed'));
    }

    return (await _store.call(call, argument)).when(
      ok: (response) {
        try {
          final envelope = jsonDecode(response) as Map<String, dynamic>;
          final MapEntry(:key, :value) = envelope.entries.single;
          return Ok((key, value.toString()));
        } on Object catch (e, stackTrace) {
          return Err(
            ErrorLocalDb.ffiError(
              'Unexpected answer of ${call.name}',
              context: context,
              cause: e,
              stackTrace: stackTrace,
            ),
          );
        }
      },
      err: (error) => Err(
        ErrorLocalDb.ffiError(
          'Native call ${call.name} failed: ${error.message}',
          context: context,
        ),
      ),
    );
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

  Future<Result<LocalDbModel, ErrorLocalDb>> _write(
    KeyValueCall function,
    String key,
    Map<String, dynamic> data,
  ) async {
    final validation = LocalDbKeys.validate(key);
    if (validation.isErr) {
      return Err(validation.errorOrNull!);
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
  Future<Result<LocalDbModel, ErrorLocalDb>> put(
    String key,
    Map<String, dynamic> data,
  ) => _write(KeyValueCall.push, key, data);

  /// Same as [put] (1.x semantics: `Post` replaces an existing record).
  Future<Result<LocalDbModel, ErrorLocalDb>> post(
    String key,
    Map<String, dynamic> data,
  ) => _write(KeyValueCall.push, key, data);

  /// Replaces the existing record [key]; fails with `notFound` otherwise.
  Future<Result<LocalDbModel, ErrorLocalDb>> update(
    String key,
    Map<String, dynamic> data,
  ) => _write(KeyValueCall.update, key, data);

  /// The record [key]; fails with `notFound` when it does not exist.
  Future<Result<LocalDbModel, ErrorLocalDb>> get(String key) async {
    final validation = LocalDbKeys.validate(key);
    if (validation.isErr) {
      return Err(validation.errorOrNull!);
    }
    final result = await _call(KeyValueCall.getById, key, key);
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
  Future<Result<void, ErrorLocalDb>> delete(String key) async {
    final validation = LocalDbKeys.validate(key);
    if (validation.isErr) {
      return Err(validation.errorOrNull!);
    }
    final result = await _call(KeyValueCall.deleteById, key, key);
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        return variant == 'Ok' || variant == 'NotFound'
            ? Ok(null)
            : Err(_failure(variant, payload, key));
      },
      err: Err.new,
    );
  }

  /// Every record, by key.
  Future<Result<Map<String, LocalDbModel>, ErrorLocalDb>> getAll() async {
    final result = await _call(KeyValueCall.getAll, null, 'get_all');
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
  Future<Result<void, ErrorLocalDb>> clear() async {
    final result = await _call(KeyValueCall.clear, null, 'clear');
    return result.when(
      ok: (reply) {
        final (variant, payload) = reply;
        return variant == 'Ok'
            ? Ok(null)
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
    _store.close().ignore();
  }
}
