// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                             PATH HELPER                                      ║
// ║                  Platform-Agnostic Path Helper Factory                       ║
// ║══════════════════════════════════════════════════════════════════════════════║

export 'native/path_helper_impl.dart'
    if (dart.library.js_interop) 'web/path_helper_impl.dart';
