/// Represents a data entry in the local database
///
/// Contains the ID, data payload, and metadata for each record stored.
/// The data must be JSON-serializable for cross-platform compatibility.
///
/// Example:
/// ```dart
/// final entry = DbEntry(
///   id: 'user-123',
///   data: {'name': 'John Doe', 'email': 'john@example.com'},
///   hash: '1640995200000',
/// );
///
/// // Converting to/from JSON
/// final json = entry.toJson();
/// final restored = DbEntry.fromJson(json);
/// ```
class DbEntry {
  /// Unique identifier for the database entry
  ///
  /// Must be at least 3 characters long and contain only alphanumeric
  /// characters, hyphens, and underscores.
  final String id;

  /// The actual data payload stored in the database
  ///
  /// Must be JSON-serializable. Complex objects should be converted
  /// to Map<String, dynamic> before storing.
  final Map<String, dynamic> data;

  /// Hash or timestamp for tracking changes
  ///
  /// Typically contains a timestamp in milliseconds since epoch,
  /// used for versioning and conflict resolution.
  final String hash;

  /// Size of the entry in kilobytes (optional)
  ///
  /// Used for monitoring storage usage and performance optimization.
  final double? sizeKb;

  const DbEntry({
    required this.id,
    required this.data,
    required this.hash,
    this.sizeKb,
  });

  /// Creates a DbEntry from JSON data
  ///
  /// Example:
  /// ```dart
  /// final json = {
  ///   'id': 'user-123',
  ///   'data': {'name': 'John', 'age': 30},
  ///   'hash': '1640995200000'
  /// };
  /// final entry = DbEntry.fromJson(json);
  /// ```
  factory DbEntry.fromJson(Map<String, dynamic> json) {
    return DbEntry(
      id: json['id'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      hash: json['hash'] as String,
      sizeKb: json['sizeKb'] as double?,
    );
  }

  /// Converts the DbEntry to JSON format
  ///
  /// Example:
  /// ```dart
  /// final entry = DbEntry(id: 'test', data: {'key': 'value'}, hash: '123');
  /// final json = entry.toJson();
  /// // Result: {'id': 'test', 'data': {'key': 'value'}, 'hash': '123'}
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'hash': hash,
      if (sizeKb != null) 'sizeKb': sizeKb,
    };
  }

  /// Creates a copy of this entry with updated fields
  ///
  /// Example:
  /// ```dart
  /// final originalEntry = DbEntry(id: 'test', data: {}, hash: '123');
  /// final updatedEntry = originalEntry.copyWith(
  ///   data: {'updated': true},
  ///   hash: '456'
  /// );
  /// ```
  DbEntry copyWith({
    String? id,
    Map<String, dynamic>? data,
    String? hash,
    double? sizeKb,
  }) {
    return DbEntry(
      id: id ?? this.id,
      data: data ?? this.data,
      hash: hash ?? this.hash,
      sizeKb: sizeKb ?? this.sizeKb,
    );
  }

  @override
  String toString() => 'DbEntry(id: $id, hash: $hash, sizeKb: $sizeKb)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DbEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          hash == other.hash &&
          _mapEquals(data, other.data);

  @override
  int get hashCode => id.hashCode ^ hash.hashCode ^ _mapHashCode(data);

  /// Hash code computation for maps that matches our equality comparison
  static int _mapHashCode(Map<String, dynamic> map) {
    int hash = 0;
    for (final entry in map.entries) {
      hash ^= entry.key.hashCode ^ entry.value.hashCode;
    }
    return hash;
  }

  /// Deep equality comparison for maps
  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Configuration options for database initialization
///
/// Contains settings that affect database behavior across platforms.
///
/// Example:
/// ```dart
/// final config = DbConfig(
///   name: 'my_app_db',
///   maxRecordsPerFile: 10000,
///   backupEveryDays: 7,
///   hashEncrypt: true,
/// );
/// ```
class DbConfig {
  /// Name of the database
  ///
  /// Used as the filename for the database file. Should not include
  /// file extensions as they are added automatically per platform.
  final String name;

  /// Maximum number of records per database file
  ///
  /// Used for performance optimization and file size management.
  final int maxRecordsPerFile;

  /// Backup interval in days
  ///
  /// How often automatic backups are created (if supported by platform).
  final int backupEveryDays;

  /// Whether to encrypt hash values
  ///
  /// Provides additional security for sensitive data.
  final bool hashEncrypt;

  const DbConfig({
    required this.name,
    this.maxRecordsPerFile = 10000,
    this.backupEveryDays = 7,
    this.hashEncrypt = false,
  });

  /// Creates a DbConfig from JSON data
  factory DbConfig.fromJson(Map<String, dynamic> json) {
    return DbConfig(
      name: json['name'] as String,
      maxRecordsPerFile: json['maxRecordsPerFile'] as int? ?? 10000,
      backupEveryDays: json['backupEveryDays'] as int? ?? 7,
      hashEncrypt: json['hashEncrypt'] as bool? ?? false,
    );
  }

  /// Converts the DbConfig to JSON format
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'maxRecordsPerFile': maxRecordsPerFile,
      'backupEveryDays': backupEveryDays,
      'hashEncrypt': hashEncrypt,
    };
  }

  @override
  String toString() => 'DbConfig(name: $name, maxRecords: $maxRecordsPerFile)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DbConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          maxRecordsPerFile == other.maxRecordsPerFile &&
          backupEveryDays == other.backupEveryDays &&
          hashEncrypt == other.hashEncrypt;

  @override
  int get hashCode =>
      name.hashCode ^
      maxRecordsPerFile.hashCode ^
      backupEveryDays.hashCode ^
      hashEncrypt.hashCode;
}
