/// Enumeration defining standardized database directory paths
/// Used to maintain consistent directory structure across the application
enum DBDirectory {
  /// Root directory for local database storage
  localDatabase('local_database', 'local_database'),

  /// Directory for active/current database files
  active('/active', '/local_database/active'),

  /// Directory for sealed/immutable database files
  sealed('/sealed', '/local_database/sealed'),

  /// Directory for encrypted/secure database files
  secure('/secure', '/local_database/secure'),

  /// Directory for database backups
  backup('/backup', '/local_database/backup'),

  /// Directory for historical/archived database files
  historical('/historical', '/local_database/historical'),

  /// Directory for synchronization data
  sync('/sync', '/local_database/sync');

  /// Relative path from parent directory
  final String path;

  /// Absolute path from root directory
  final String fullPath;

  /// Constructor for directory enum
  /// @param path Relative path
  /// @param fullPath Complete path from root
  const DBDirectory(this.path, this.fullPath);
}
