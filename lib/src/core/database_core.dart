// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            DATABASE CORE                                     ║
// ║                     Platform-Agnostic Database Factory                       ║
// ║══════════════════════════════════════════════════════════════════════════════║

export 'native/database_core_impl.dart'
    if (dart.library.js_interop) 'web/database_core_impl.dart';
