import '../core/database.dart';
import 'web/web_database.dart';

/// Creates a database instance for web platform using IndexedDB
///
/// Returns a WebDatabase implementation that uses IndexedDB for persistent storage
/// via package:web for optimal performance and browser compatibility.
///
/// This implementation provides:
/// - ✅ Persistent storage (survives browser restarts)
/// - ✅ Large storage capacity (typically several GB)
/// - ✅ Full CRUD operations with transactional safety
/// - ✅ Same API as native platforms
///
/// Example:
/// ```dart
/// final database = createDatabase();
/// await database.initialize(DbConfig(name: 'my_web_app'));
///
/// // Works exactly like native platforms
/// final result = await database.insert('user-1', {'name': 'John'});
/// ```
Database createDatabase() {
  return WebDatabase();
}
