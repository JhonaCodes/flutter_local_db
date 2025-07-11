// Conditional import for web database
// This ensures web code only compiles on web platform

export 'database_web_stub.dart' // Default stub for non-web platforms
    if (dart.library.html) 'database_web.dart'; // Real implementation for web