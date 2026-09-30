import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Saves the table of `integration_test/benchmark_test.dart` to
/// `build/benchmark.md`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final table = data?['table'] as String? ?? '';
    await File('build/benchmark.md').writeAsString('$table\n');
    stdout.writeln(table);
  },
);
