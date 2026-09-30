import 'engine_bridge.dart';
import 'errors.dart';

/// The query API needs the native engine (Rust + LMDB), which does not run in
/// browsers. On the web, flutter_local_db offers the key-value [LocalDB] API
/// (IndexedDB).
abstract final class EngineBridges {
  /// Always fails with [LocalDbErrorCode.unsupportedPlatform].
  static Future<String> applicationSupportDirectory() => throw _unsupported;

  static const LocalDbException _unsupported = LocalDbException(
    LocalDbErrorCode.unsupportedPlatform,
    'LocalDatabase needs the native engine, which is not available on the '
    'web; use LocalDB (IndexedDB) there',
  );

  /// Always fails with [LocalDbErrorCode.unsupportedPlatform].
  static Future<EngineBridge> open(String path, Map<String, Object?> options) =>
      throw _unsupported;
}
