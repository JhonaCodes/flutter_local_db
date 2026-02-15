// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                       INITIALIZER (WEB)                                      ║
// ║                 Web Platform Initialization Logic                            ║
// ║══════════════════════════════════════════════════════════════════════════════║

import '../../models/local_db_result.dart';
import '../../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

class Initializer {
  /// Initializes the web database environment
  ///
  /// Web (IndexedDB) does not require explicit library loading or bindings.
  static LocalDbResult<Object?, ErrorLocalDb> init() {
    Log.d('🌐 Web environment ready (No native bindings required)');
    return const Ok(null);
  }
}
