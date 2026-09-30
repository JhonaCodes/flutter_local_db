import 'dart:io';

/// Host resources of the tests.
abstract final class TestHost {
  /// A fresh temporary directory.
  static Future<Directory> temporaryDirectory(String label) =>
      Directory.systemTemp.createTemp('flutter_local_db_$label');
}
