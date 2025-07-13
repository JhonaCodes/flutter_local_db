import '../core/database.dart';
import 'native/native_database.dart';

/// Creates a database instance for native platforms (Android, iOS, macOS)
///
/// Returns a [NativeDatabase] implementation that uses FFI to communicate
/// with the Rust/LMDB backend for high-performance local storage.
///
/// Example:
/// ```dart
/// final database = createDatabase();
/// await database.initialize(DbConfig(name: 'my_app_db'));
/// ```
Database createDatabase() {
  return NativeDatabase();
}
