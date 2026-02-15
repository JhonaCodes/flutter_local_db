// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                       INITIALIZER (NATIVE)                                   ║
// ║               Native Platform Initialization Logic                           ║
// ║══════════════════════════════════════════════════════════════════════════════║

import 'dart:ffi';
import '../../models/local_db_result.dart';
import '../../models/local_db_error.dart';
import '../ffi_bindings.dart';
import '../library_loader.dart';
import 'package:logger_rs/logger_rs.dart';

class Initializer {
  /// Initializes the native database environment
  ///
  /// Loads the dynamic library and creates FFI bindings.
  static LocalDbResult<Object, ErrorLocalDb> init() {
    Log.d('🔄 Initializing native environment');
    
    // Load the native library
    final libraryResult = LibraryLoader.loadLibrary();
    if (libraryResult.isErr) {
      Log.e('Failed to load native library');
      return Err(libraryResult.errOrNull!);
    }

    final library = libraryResult.okOrNull!;

    // Validate the library contains required functions
    final validationResult = LibraryLoader.validateLibrary(library);
    if (validationResult.isErr) {
      Log.e('Library validation failed');
      return Err(validationResult.errOrNull!);
    }

    // Create FFI bindings
    try {
      final bindings = LocalDbBindings.fromLibrary(library);
      return Ok(bindings);
    } catch (e) {
      return Err(ErrorLocalDb.initialization('Failed to create bindings', cause: e));
    }
  }
}
