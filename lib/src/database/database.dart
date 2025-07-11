/// Conditional export for database implementations
/// 
/// This file automatically selects the appropriate database implementation
/// based on the platform:
/// - Native implementation (FFI + Rust) for mobile and desktop
/// - Web implementation (IndexedDB) for web platforms  
/// - Stub implementation for unsupported platforms
///
/// The conditional exports ensure that:
/// - Mobile apps never import web-specific code (avoiding crashes)
/// - Web apps use modern IndexedDB with dart:js_interop
/// - All platforms use the same interface

export 'database_interface.dart';
export 'database_stub.dart'
    if (dart.library.io) 'database_native.dart'
    if (dart.library.js_interop) 'database_web.dart';