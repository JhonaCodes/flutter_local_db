/// Export core database interface definition
library;

export 'db_interface.dart';

/// Conditional exports based on platform:
export 'db_stub.dart'

    /// Use db_web.dart implementation if running on web platform (when dart:html is available)
    if (dart.library.html) 'db_web.dart'

    /// Use db_device.dart implementation if running on native platforms like mobile/desktop
    /// (when dart:io is available)
    if (dart.library.io) 'db_device.dart';
