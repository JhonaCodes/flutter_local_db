// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                             INITIALIZER                                      ║
// ║                  Platform-Agnostic Initializer Factory                       ║
// ║══════════════════════════════════════════════════════════════════════════════║

export 'native/initializer_impl.dart'
    if (dart.library.js_interop) 'web/initializer_impl.dart';
