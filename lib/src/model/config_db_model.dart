import 'package:flutter/cupertino.dart';

@immutable
class ConfigDBModel {
  final int maxRecordsPerFile;

  /// Zero for no backups
  final int backupEveryDays;

  /// In progress
  final String hashEncrypt;

  const ConfigDBModel(
      {this.maxRecordsPerFile = 2000,
      this.backupEveryDays = 0,
      this.hashEncrypt = 'flutter_local_db'});
}
