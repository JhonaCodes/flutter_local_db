/// This manifest defines the internal configuration that will be taken into account
/// for future database configurations. It handles critical settings such as
/// historical data processing, backup scheduling, and version control.
class ManifestFormat {
  /// Current version of the database configuration
  /// Used to track changes and ensure compatibility
  static double version = 10.0;

  /// Developer responsible for maintaining the database configuration
  /// Contact for technical inquiries and issues
  static String developer = "Jhonatan Ortiz - jhonacodes@gmail.com";

  /// Last modification date of the configuration
  /// Format: DD - MMM - YYYY
  static String lastUpdate = "15 - Dec - 2024";

  /// Percentage of data that will be preserved for historical analysis
  /// This value affects storage allocation and retention policies
  static double percentageForHistoricalProcess = 30.0;

  /// Unix timestamp for the next scheduled database backup
  /// A value of 0 indicates no backup is currently scheduled
  static int dateEpocNextBackup = 0;

  /// Converts the manifest configuration to TOML format
  /// This format is used for storage and cross-system compatibility
  /// Returns a structured string containing all configuration parameters
  static String toToml() {
    return """
[info]
name = 'local_database'
version = $version
last_update = '$lastUpdate'
developer = '$developer'
   
[metadata]
historical_range = $percentageForHistoricalProcess
backup_on = $dateEpocNextBackup    
""";
  }
}