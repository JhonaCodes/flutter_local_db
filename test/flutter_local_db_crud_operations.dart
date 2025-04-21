import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'mock_path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockProvider = MockPathProvider();
  PathProviderPlatform.instance = mockProvider;

  setUpAll(() async {
    if (!await mockProvider.testDir.exists()) {
      await mockProvider.testDir.create(recursive: true);
    }

    await LocalDB.initForTesting(
        localDbName: 'test.db',
        binaryPath:
            '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');
  });

  setUp(() async {
    await LocalDB.ClearData();
  });

  group('LocalDB post', () {
    test('Benchmark for writing operations', () async {
      final stopwatch = Stopwatch()..start();

      // Número de operaciones a realizar - aumentado para mejor medición
      const int operationCount = 1000;

      for (int i = 0; i < operationCount; i++) {
        LocalDB.Post('benchmark-$i', {'value': i});
      }

      final totalTime = stopwatch.elapsedMilliseconds;
      final operationsPerSecond = (operationCount / totalTime * 1000).round();

      print('Total time for $operationCount write operations: $totalTime ms');
      print('Operations per second: $operationsPerSecond ops/s');

      // Un benchmark agresivo que busca al menos 2000 operaciones por segundo
      // Esto sería comparable con SQLite en modo optimizado
      expect(operationsPerSecond >= 10000, true,
          reason:
              'Performance benchmark failed: $operationsPerSecond ops/s is below target of 2000 ops/s');
    });

    test('Benchmark for reading operations', () async {
      // Preparar datos para lectura
      const int dataSize = 1000;
      for (int i = 0; i < dataSize; i++) {
        await LocalDB.Post('read-benchmark-$i', {'value': i});
      }

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < dataSize; i++) {
        await LocalDB.GetById('read-benchmark-$i');
      }

      final totalTime = stopwatch.elapsedMilliseconds;
      final operationsPerSecond = (dataSize / totalTime * 1000).round();

      print('Total time for $dataSize read operations: $totalTime ms');
      print('Read operations per second: $operationsPerSecond ops/s');

      // Las lecturas deberían ser más rápidas que las escrituras, al menos 5000 ops/s
      expect(operationsPerSecond >= 5000, true,
          reason:
              'Read performance benchmark failed: $operationsPerSecond ops/s is below target of 5000 ops/s');
    });
  });
}
