import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../native/native_worker.dart';
import 'engine_bridge.dart';
import 'errors.dart';

/// Opens bridges to the native engine through the database worker isolate.
abstract final class EngineBridges {
  /// Path of the application support directory.
  static Future<String> applicationSupportDirectory() async =>
      (await getApplicationSupportDirectory()).path;

  /// Opens the database at `<path>.lmdb`.
  static Future<EngineBridge> open(
    String path,
    Map<String, Object?> options,
  ) async {
    final int handle;
    final String response;
    final NativeWorker worker;
    try {
      worker = await NativeWorker.shared();
      (handle, response) = await worker.open(path, jsonEncode(options));
    } on Object catch (e) {
      // The native library is missing or failed to load.
      throw LocalDbException(LocalDbErrorCode.nativeLibrary, e.toString());
    }
    if (handle == 0) {
      throw _NativeBridge.errorOf(jsonDecode(response) as Map<String, Object?>);
    }
    return _NativeBridge(worker, handle);
  }
}

final class _NativeBridge implements EngineBridge {
  _NativeBridge(this._worker, this._handle);

  final NativeWorker _worker;
  final int _handle;
  bool _closed = false;

  static LocalDbException errorOf(Map<String, Object?> response) {
    final error = response['error'] as Map<String, Object?>?;
    final code = error?['code'] as String? ?? '';
    return LocalDbException(
      LocalDbErrorCode.fromWire(code),
      error?['message'] as String? ?? 'Malformed response: $response',
      wireCode: code,
    );
  }

  @override
  Future<Map<String, Object?>> request(Map<String, Object?> request) async {
    if (_closed) {
      throw const LocalDbException(
        LocalDbErrorCode.closed,
        'The database is closed',
      );
    }
    final String text;
    try {
      text = await _worker.execute(_handle, jsonEncode(request));
    } on Object catch (e) {
      throw LocalDbException(LocalDbErrorCode.nativeLibrary, e.toString());
    }
    final response = jsonDecode(text) as Map<String, Object?>;
    final ok = response['ok'];
    if (ok is Map<String, Object?>) {
      return ok;
    }
    throw errorOf(response);
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _worker.close(_handle);
  }
}
