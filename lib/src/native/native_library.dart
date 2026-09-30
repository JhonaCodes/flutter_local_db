import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// Calls into offline_first_core (Rust + LMDB 1.0), copying every response
/// string into Dart and releasing it in Rust.
///
/// Only used inside the database worker isolate: every call blocks until the
/// native side answers.
final class NativeLibrary {
  /// The library bundled by the build hook.
  const NativeLibrary();

  String _take(Pointer<Utf8> response) {
    if (response == nullptr) {
      throw StateError('offline_first_core returned no response');
    }
    try {
      return response.toDartString();
    } finally {
      Bindings.freeString(response);
    }
  }

  T _withStrings<T>(
    List<String?> values,
    T Function(List<Pointer<Utf8>>) body,
  ) {
    final pointers = [
      for (final value in values)
        value == null ? nullptr.cast<Utf8>() : value.toNativeUtf8(),
    ];
    try {
      return body(pointers);
    } finally {
      for (final pointer in pointers) {
        if (pointer != nullptr) {
          malloc.free(pointer);
        }
      }
    }
  }

  /// Opens `<path>.lmdb`. Returns the handle address (0 on failure) and the
  /// wire-protocol response.
  (int, String) open(String path, String? optionsJson) {
    final out = malloc<Pointer<Void>>();
    try {
      final response = _withStrings([
        path,
        optionsJson,
      ], (strings) => Bindings.open(strings[0], strings[1], out));
      return (out.value.address, _take(response));
    } finally {
      malloc.free(out);
    }
  }

  /// Runs one wire-protocol request.
  String execute(int handle, String request) => _withStrings(
    [request],
    (strings) =>
        _take(Bindings.execute(Pointer.fromAddress(handle), strings[0])),
  );

  /// Releases a handle.
  String close(int handle) =>
      _take(Bindings.close(Pointer.fromAddress(handle)));

  /// Runs one call of the 0.5 key-value API.
  String legacy(int handle, String function, String? argument) {
    final target = Pointer<Void>.fromAddress(handle);
    String withArgument(
      Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>) call,
    ) => _withStrings([argument], (s) => _take(call(target, s[0])));
    return switch (function) {
      'push_data' => withArgument(Bindings.push),
      'update_data' => withArgument(Bindings.update),
      'get_by_id' => withArgument(Bindings.getById),
      'delete_by_id' => withArgument(Bindings.deleteById),
      'get_all' => _take(Bindings.getAll(target)),
      'clear_all_records' => _take(Bindings.clear(target)),
      _ => throw ArgumentError.value(function, 'function', 'unknown'),
    };
  }
}
