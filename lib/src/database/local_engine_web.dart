/// The engine of [the tables of LocalDB] on the web, where the native engine does
/// not run.
library;

import 'package:db_dsl/db_dsl.dart';

/// Where [the tables of LocalDB] gets its engine and its default directory.
///
/// On the web, flutter_local_db offers the key-value `LocalDB` API
/// (IndexedDB); the query API answers [DbErrorCode.unsupportedPlatform].
abstract final class LocalEngine {
  /// Whether this platform runs the native engine (and so has tables).
  static const bool available = false;

  /// An engine that refuses every database.
  static Engine get engine => const _UnsupportedEngine();

  /// Always [DbErrorCode.unsupportedPlatform].
  static Future<Result<String, DbError>> supportDirectory() async =>
      Err(_UnsupportedEngine._error);
}

/// Refuses to open, explaining why.
final class _UnsupportedEngine implements Engine {
  const _UnsupportedEngine();

  static final DbError _error = DbError(
    DbErrorCode.unsupportedPlatform,
    'the tables of LocalDB needs the native engine, which does not run on the web; '
    'use LocalDB (IndexedDB) there',
  );

  @override
  Future<Result<EngineConnection, DbError>> open(
    String path,
    DbOptions options,
  ) async => Err(_error);
}
