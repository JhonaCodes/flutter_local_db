import 'package:flutter/foundation.dart' show kIsWeb;
import 'database_interface.dart';

// Conditional imports for platform-specific implementations
import 'database_stub.dart'
    if (dart.library.io) 'database_native.dart'
    if (dart.library.js_interop) 'database_web.dart';

/// Factory for creating platform-specific database implementations
/// Uses conditional imports to ensure proper cross-platform compilation
class DatabaseFactory {
  /// Creates the appropriate database implementation for the current platform
  static DatabaseInterface create() {
    if (kIsWeb) {
      return createDatabase(); // Will resolve to DatabaseWeb on web
    } else {
      return createDatabase(); // Will resolve to DatabaseNative on native
    }
  }
}

/// This function will be implemented differently on each platform
/// thanks to conditional imports
DatabaseInterface createDatabase() {
  throw UnsupportedError('Unsupported platform');
}