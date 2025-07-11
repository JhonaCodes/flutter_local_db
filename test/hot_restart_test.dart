import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/flutter_local_db.dart';
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
  });

  setUp(() async {
    await LocalDB.ClearData();
  });

  group('Hot Restart Simulation Tests', () {
    test('Should handle database reconnection after simulated hot restart', () async {
      await LocalDB.initForTesting(
          localDbName: 'hot_restart_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Create some test data
      final result1 = await LocalDB.Post('test-key-1', {'value': 'before restart'});
      expect(result1.isOk, true);

      // Simulate hot restart by closing the database
      await LocalDB.CloseDatabase();

      // Verify connection is invalid
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true); // Should be true after auto-reconnection

      // Try to access data - should trigger reconnection
      final result2 = await LocalDB.GetById('test-key-1');
      expect(result2.isOk, true);
      expect(result2.data?.data['value'], 'before restart');
    });

    test('Should handle multiple close/reconnection cycles', () async {
      await LocalDB.initForTesting(
          localDbName: 'multiple_cycles_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      for (int i = 0; i < 5; i++) {
        // Create data
        final createResult = await LocalDB.Post('cycle-$i', {'cycle': i});
        expect(createResult.isOk, true);

        // Close database
        await LocalDB.CloseDatabase();

        // Try to read - should reconnect automatically
        final readResult = await LocalDB.GetById('cycle-$i');
        expect(readResult.isOk, true);
        expect(readResult.data?.data['cycle'], i);
      }
    });

    test('Should handle concurrent operations after reconnection', () async {
      await LocalDB.initForTesting(
          localDbName: 'concurrent_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Close database to simulate restart
      await LocalDB.CloseDatabase();

      // Perform concurrent operations - should all trigger reconnection
      final futures = List.generate(10, (index) =>
          LocalDB.Post('concurrent-$index', {'value': index})
      );

      final results = await Future.wait(futures);
      expect(results.every((result) => result.isOk), true);

      // Verify all data was stored
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, 10);
    });

    test('Should preserve data integrity across restart cycles', () async {
      await LocalDB.initForTesting(
          localDbName: 'integrity_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Create initial data
      final initialData = List.generate(20, (i) => 
          LocalDB.Post('integrity-$i', {'value': i, 'timestamp': DateTime.now().toIso8601String()})
      );
      await Future.wait(initialData);

      // Close and reopen multiple times
      for (int cycle = 0; cycle < 3; cycle++) {
        await LocalDB.CloseDatabase();
        
        // Verify data is still there
        final allData = await LocalDB.GetAll();
        expect(allData.isOk, true);
        expect(allData.data.length, 20);

        // Modify some data
        await LocalDB.Put('integrity-${cycle * 3}', {'value': cycle * 100, 'modified': true});
      }

      // Final verification
      final finalData = await LocalDB.GetAll();
      expect(finalData.isOk, true);
      expect(finalData.data.length, 20);
      
      // Check that modifications were preserved
      for (int cycle = 0; cycle < 3; cycle++) {
        final item = await LocalDB.GetById('integrity-${cycle * 3}');
        expect(item.isOk, true);
        expect(item.data?.data['value'], cycle * 100);
        expect(item.data?.data['modified'], true);
      }
    });

    test('Should handle rapid close/open cycles without crashes', () async {
      await LocalDB.initForTesting(
          localDbName: 'rapid_cycles_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Perform rapid cycles
      for (int i = 0; i < 20; i++) {
        await LocalDB.CloseDatabase();
        
        // Immediately try to use the database
        final result = await LocalDB.Post('rapid-$i', {'iteration': i});
        expect(result.isOk, true);
      }

      // Verify all data was stored correctly
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, 20);
    });

    test('Should handle invalid state recovery', () async {
      await LocalDB.initForTesting(
          localDbName: 'invalid_state_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Create some data
      await LocalDB.Post('state-test', {'value': 'test'});

      // Close database
      await LocalDB.CloseDatabase();

      // Multiple rapid operations should not cause issues
      final rapidOps = [
        LocalDB.GetById('state-test'),
        LocalDB.Post('new-key', {'value': 'new'}),
        LocalDB.GetAll(),
        LocalDB.Put('state-test', {'value': 'updated'}),
      ];

      final results = await Future.wait(rapidOps);
      expect(results.every((result) => result.isOk), true);
    });
  });

  group('Connection Validation Tests', () {
    test('Should validate connection state correctly', () async {
      await LocalDB.initForTesting(
          localDbName: 'validation_test.db',
          binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');

      // Should be valid after initialization
      final valid1 = await LocalDB.IsConnectionValid();
      expect(valid1, true);

      // Should still be valid after normal operations
      await LocalDB.Post('validation-key', {'test': 'data'});
      final valid2 = await LocalDB.IsConnectionValid();
      expect(valid2, true);

      // Should handle validation after close
      await LocalDB.CloseDatabase();
      final valid3 = await LocalDB.IsConnectionValid();
      expect(valid3, true); // Should be true after auto-reconnection
    });
  });
}