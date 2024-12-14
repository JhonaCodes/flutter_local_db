import 'package:flutter/cupertino.dart';

/// Configuration model for database initialization and behavior
/// Contains essential settings that define database operation parameters
/// @immutable - Configuration cannot be modified after instantiation
@immutable
class ConfigDBModel {
  /// Maximum number of records allowed per database file
  /// Default value is 2000 records
  /// Used to manage database splitting and performance
  final int maxRecordsPerFile;

  /// Interval in days between automatic backups
  /// Default value is 0 (no automatic backups)
  /// Set to desired number of days to enable periodic backups
  final int backupEveryDays;

  /// Encryption key for secure storage
  /// Default value is 'flutter_local_db'
  /// Currently in development - will be used for data encryption
  /// Note: Must be exactly 16 characters when implemented
  final String hashEncrypt;

  /// Creates an immutable database configuration
  /// @param maxRecordsPerFile Maximum records per file (default: 2000)
  /// @param backupEveryDays Days between backups (default: 0)
  /// @param hashEncrypt Encryption key (default: 'flutter_local_db')
  const ConfigDBModel(
      {this.maxRecordsPerFile = 2000,
        this.backupEveryDays = 0,
        this.hashEncrypt = 'flutter_local_db'});
}