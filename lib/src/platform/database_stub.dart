import '../core/database.dart';

/// Stub implementation for conditional imports
///
/// This file serves as a fallback when neither native nor web
/// implementations are available. It should never be used in practice.
///
/// The actual implementations are:
/// - `database_io.dart` for native platforms (Android, iOS, macOS)
/// - `database_web.dart` for web platform
Database createDatabase() {
  throw UnsupportedError('Platform not supported');
}
