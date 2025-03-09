import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProvider extends PathProviderPlatform {
  final testDir = Directory('test_db');

  @override
  Future<String> getApplicationDocumentsPath() async {
    if (!await testDir.exists()) {
      await testDir.create(recursive: true);
    }

    return testDir.path;
  }
}