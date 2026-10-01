/// The engine of [the tables of LocalDB] on Android, iOS, macOS, Linux and Windows.
library;

import 'package:db_dsl/db_dsl.dart';
import 'package:path_provider/path_provider.dart';

import '../native/offline_first_core.dart';

/// Where [the tables of LocalDB] gets its engine and its default directory.
abstract final class LocalEngine {
  /// Whether this platform runs the native engine (and so has tables).
  static const bool available = true;

  /// The bundled offline_first_core.
  static Engine get engine => OfflineFirstCore.engine;

  /// The application support directory of the platform.
  static Future<Result<String, DbError>> supportDirectory() async {
    try {
      return Ok((await getApplicationSupportDirectory()).path);
    } on Object catch (error) {
      return Err(
        DbError(DbErrorCode.io, 'No application support directory: $error'),
      );
    }
  }
}
