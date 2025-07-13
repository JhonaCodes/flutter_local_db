import '../core/database.dart';
import 'web/web_database.dart';

/// Creates a database instance for web platform
/// 
/// Returns a [WebDatabase] implementation that uses in-memory storage
/// with localStorage persistence for optimal web compatibility.
/// 
/// Example:
/// ```dart
/// final database = createDatabase();
/// await database.initialize(DbConfig(name: 'my_web_app'));
/// ```
Database createDatabase() {
  return WebDatabase();
}