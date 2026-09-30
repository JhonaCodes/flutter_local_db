/// Entry points of offline_first_core (Rust + LMDB 1.0).
///
/// They resolve against the code asset `hook/build.dart` bundles for the
/// target platform, so no library is opened by path.
@DefaultAsset('package:flutter_local_db/src/native/bindings.dart')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The C ABI of offline_first_core. Every returned string belongs to Rust and
/// is released with [freeString], exactly once.
abstract final class Bindings {
  /// `ofc_open(path, options, out)`: opens `<path>.lmdb`; writes the handle to
  /// `out` and returns the wire response.
  @Native<
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Pointer<Void>>)
  >(symbol: 'ofc_open')
  external static Pointer<Utf8> open(
    Pointer<Utf8> path,
    Pointer<Utf8> options,
    Pointer<Pointer<Void>> out,
  );

  /// `ofc_execute(handle, request)`: runs one wire-protocol request.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'ofc_execute',
  )
  external static Pointer<Utf8> execute(
    Pointer<Void> handle,
    Pointer<Utf8> request,
  );

  /// `ofc_free_string(string)`: releases a returned string.
  @Native<Void Function(Pointer<Utf8>)>(symbol: 'ofc_free_string')
  external static void freeString(Pointer<Utf8> string);

  /// `close_database(handle)`: releases a handle.
  @Native<Pointer<Utf8> Function(Pointer<Void>)>(symbol: 'close_database')
  external static Pointer<Utf8> close(Pointer<Void> handle);

  /// `push_data(handle, json)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'push_data',
  )
  external static Pointer<Utf8> push(Pointer<Void> handle, Pointer<Utf8> json);

  /// `update_data(handle, json)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'update_data',
  )
  external static Pointer<Utf8> update(
    Pointer<Void> handle,
    Pointer<Utf8> json,
  );

  /// `get_by_id(handle, id)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'get_by_id',
  )
  external static Pointer<Utf8> getById(Pointer<Void> handle, Pointer<Utf8> id);

  /// `delete_by_id(handle, id)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'delete_by_id',
  )
  external static Pointer<Utf8> deleteById(
    Pointer<Void> handle,
    Pointer<Utf8> id,
  );

  /// `get_all(handle)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>)>(symbol: 'get_all')
  external static Pointer<Utf8> getAll(Pointer<Void> handle);

  /// `clear_all_records(handle)` of the key-value API.
  @Native<Pointer<Utf8> Function(Pointer<Void>)>(symbol: 'clear_all_records')
  external static Pointer<Utf8> clear(Pointer<Void> handle);
}
