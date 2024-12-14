/// Enumeration defining core database index and manifest files
/// These files serve as the initial structure for the database system
enum DBFile {
  /// Master index file tracking all database entries
  /// Stores global metadata and references to all records
  globalIndex('global_index.json'),

  /// Active records index file
  /// Tracks currently active and accessible records
  activeSubIndex('active_index.json'),

  /// Database manifest file in TOML format
  /// Contains configuration, schema, and database metadata
  manifest('manifest.toml');

  /// File extension/name for the index file
  final String ext;

  /// Constructor for file enum
  /// @param ext File extension/name to be used
  const DBFile(this.ext);
}
