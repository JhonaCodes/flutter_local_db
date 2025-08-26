// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            LIBRARY LOADER                                   ║
// ║                    Platform-Specific Native Library Loading                 ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: library_loader.dart                                                 ║
// ║  Purpose: Load native libraries across different platforms                  ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Handles the complex task of loading native libraries across different    ║
// ║    platforms (Android, iOS, macOS, Windows, Linux). Each platform has      ║
// ║    different requirements and file locations for native libraries.         ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Cross-platform library loading                                         ║
// ║    • Automatic platform detection                                           ║
// ║    • Fallback loading strategies                                             ║
// ║    • Detailed error reporting                                                ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'dart:io';
import '../models/local_db_result.dart';
import '../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

/// Platform-specific library loader for native LMDB database
///
/// Handles the complexity of loading native libraries across different
/// platforms with appropriate fallback strategies and detailed error reporting.
class LibraryLoader {
  /// Loads the appropriate native library for the current platform
  ///
  /// This method automatically detects the current platform and attempts
  /// to load the correct native library using platform-specific strategies.
  ///
  /// Returns:
  /// - [Ok] with loaded [DynamicLibrary] on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = await LibraryLoader.loadLibrary();
  /// result.when(
  ///   ok: (lib) => print('Library loaded successfully'),
  ///   err: (error) => print('Failed to load: $error'),
  /// );
  /// ```
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> loadLibrary() {
    Log.i('🔄 Starting library loading process...');

    try {
      if (Platform.isAndroid) {
        return _loadAndroidLibrary();
      } else if (Platform.isIOS) {
        return _loadIOSLibrary();
      } else if (Platform.isMacOS) {
        return _loadMacOSLibrary();
      } else if (Platform.isWindows) {
        return _loadWindowsLibrary();
      } else if (Platform.isLinux) {
        return _loadLinuxLibrary();
      } else {
        return Err(
          ErrorLocalDb.platformError(
            'Unsupported platform: ${Platform.operatingSystem}',
            context: 'platform_detection',
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.e('💥 Unexpected error during library loading: $e');
      return Err(
        ErrorLocalDb.unknown(
          'Unexpected error during library loading',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Loads the library on Android platform
  ///
  /// Android uses .so (shared object) files located in the app's native library directory.
  /// The Android plugin system automatically handles architecture-specific library selection.
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadAndroidLibrary() {
    Log.i('📱 Loading Android library...');

    const libName = 'liboffline_first_core.so';

    try {
      final lib = DynamicLibrary.open(libName);
      Log.i('✅ Android library loaded successfully: $libName');
      return Ok(lib);
    } catch (e) {
      Log.e('❌ Failed to load Android library: $e');
      return Err(
        ErrorLocalDb.ffiError(
          'Failed to load Android native library',
          context: libName,
          cause: e,
        ),
      );
    }
  }

  /// Loads the library on iOS platform
  ///
  /// iOS uses static linking, so the library is embedded in the app bundle.
  /// We use DynamicLibrary.process() to access the linked symbols.
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadIOSLibrary() {
    Log.i('📱 Loading iOS library...');

    try {
      final lib = DynamicLibrary.process();
      Log.i('✅ iOS library loaded from app bundle');
      return Ok(lib);
    } catch (e) {
      Log.e('❌ Failed to load iOS library: $e');
      return Err(
        ErrorLocalDb.ffiError(
          'Failed to load iOS native library from app bundle',
          context: 'DynamicLibrary.process()',
          cause: e,
        ),
      );
    }
  }

  /// Loads the library on macOS platform
  ///
  /// macOS can use both .dylib files and process linking.
  /// We try process linking first (for bundled apps), then fallback to .dylib files.
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadMacOSLibrary() {
    Log.i('🖥️ Loading macOS library...');

    // Strategy 1: Try loading from process (bundled app)
    try {
      final lib = DynamicLibrary.process();
      Log.i('✅ macOS library loaded from app bundle');
      return Ok(lib);
    } catch (e) {
      Log.w('⚠️ Failed to load from process bundle: $e');
    }

    // Strategy 2: Try loading architecture-specific .dylib files
    final architectures = ['arm64', 'x86_64'];

    for (final arch in architectures) {
      final libPath = 'liboffline_first_core_$arch.dylib';

      try {
        final lib = DynamicLibrary.open(libPath);
        Log.i('✅ macOS library loaded: $libPath');
        return Ok(lib);
      } catch (e) {
        Log.w('⚠️ Failed to load $libPath: $e');
      }
    }

    // Strategy 3: Try generic .dylib name
    try {
      const libPath = 'liboffline_first_core.dylib';
      final lib = DynamicLibrary.open(libPath);
      Log.i('✅ macOS library loaded: $libPath');
      return Ok(lib);
    } catch (e) {
      Log.e('❌ All macOS loading strategies failed. Last error: $e');
    }

    return Err(
      ErrorLocalDb.ffiError(
        'Failed to load macOS native library using any available strategy',
        context: 'process, arm64, x86_64, generic',
      ),
    );
  }

  /// Loads the library on Windows platform
  ///
  /// Windows uses .dll (Dynamic Link Library) files.
  /// We support both architecture-specific and generic naming.
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadWindowsLibrary() {
    Log.i('🪟 Loading Windows library...');

    final libraryNames = [
      'offline_first_core.dll',
      'liboffline_first_core.dll',
      'offline_first_core_x86_64.dll',
      'liboffline_first_core_x86_64.dll',
    ];

    for (final libName in libraryNames) {
      try {
        final lib = DynamicLibrary.open(libName);
        Log.i('✅ Windows library loaded: $libName');
        return Ok(lib);
      } catch (e) {
        Log.w('⚠️ Failed to load $libName: $e');
      }
    }

    return Err(
      ErrorLocalDb.ffiError(
        'Failed to load Windows native library',
        context: libraryNames.join(', '),
      ),
    );
  }

  /// Loads the library on Linux platform
  ///
  /// Linux uses .so (shared object) files.
  /// We support both architecture-specific and generic naming.
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadLinuxLibrary() {
    Log.i('🐧 Loading Linux library...');

    final libraryNames = [
      'liboffline_first_core.so',
      'liboffline_first_core_x86_64.so',
      './liboffline_first_core.so',
      '/usr/local/lib/liboffline_first_core.so',
    ];

    for (final libName in libraryNames) {
      try {
        final lib = DynamicLibrary.open(libName);
        Log.i('✅ Linux library loaded: $libName');
        return Ok(lib);
      } catch (e) {
        Log.w('⚠️ Failed to load $libName: $e');
      }
    }

    return Err(
      ErrorLocalDb.ffiError(
        'Failed to load Linux native library',
        context: libraryNames.join(', '),
      ),
    );
  }

  /// Validates that a loaded library contains all required functions
  ///
  /// Performs a quick validation to ensure the loaded library contains
  /// all the expected function symbols before proceeding.
  ///
  /// Parameters:
  /// - [lib] - The loaded dynamic library to validate
  ///
  /// Returns:
  /// - [Ok] with the library if validation passes
  /// - [Err] with validation error if functions are missing
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> validateLibrary(
    DynamicLibrary lib,
  ) {
    Log.i('🔍 Validating library functions...');

    const requiredFunctions = [
      'create_db',
      'put',
      'get',
      'delete',
      'exists',
      'get_all_keys',
      'get_all',
      'get_stats',
      'clear',
      'close_db',
      'free_string',
    ];

    final missingFunctions = <String>[];

    for (final functionName in requiredFunctions) {
      try {
        lib.lookup(functionName);
      } catch (e) {
        missingFunctions.add(functionName);
        Log.w('⚠️ Missing function: $functionName');
      }
    }

    if (missingFunctions.isNotEmpty) {
      return Err(
        ErrorLocalDb.ffiError(
          'Library missing required functions',
          context: 'Missing: ${missingFunctions.join(', ')}',
        ),
      );
    }

    Log.i('✅ Library validation successful - all functions present');
    return Ok(lib);
  }

  /// Gets information about the current platform
  ///
  /// Returns a map with platform information useful for debugging
  /// library loading issues.
  static Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'architecture': _getArchitecture(),
      'isDebugMode': _isDebugMode(),
      'executablePath': Platform.resolvedExecutable,
      'environment': {
        'PATH': Platform.environment['PATH'],
        'LD_LIBRARY_PATH': Platform.environment['LD_LIBRARY_PATH'],
        'DYLD_LIBRARY_PATH': Platform.environment['DYLD_LIBRARY_PATH'],
      },
    };
  }

  /// Gets the current architecture
  static String _getArchitecture() {
    if (Platform.version.contains('arm64') ||
        Platform.version.contains('aarch64')) {
      return 'arm64';
    } else if (Platform.version.contains('x64') ||
        Platform.version.contains('x86_64')) {
      return 'x86_64';
    } else {
      return 'unknown';
    }
  }

  /// Checks if running in debug mode
  static bool _isDebugMode() {
    bool debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }
}
