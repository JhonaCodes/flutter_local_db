
import 'package:flutter/cupertino.dart';

@immutable
class ConfigDBModel {

  final int maxRecordsPerFile;

  /// Zero for no backups
  final int backupEveryDays;

  const ConfigDBModel({ this.maxRecordsPerFile = 2000, this.backupEveryDays = 0});
}