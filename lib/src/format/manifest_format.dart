
/// This information is related for current lib
class ManifestFormat {

  static double version = 10.0;
  static String developer = "Jhonatan Ortiz - jhonacodes@gmail.com";
  static String lastUpdate = "15 - Dec - 2024";

  static double percentageForHistoricalProcess = 30.0;

  static int dateEpocNextBackup = 0;


  static String toToml(){
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