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

    await LocalDB.initForTesting(
        localDbName: 'connection_pool_test.db',
        binaryPath:
            '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');
  });

  setUp(() async {
    await LocalDB.ClearData();
  });
  
  tearDown(() async {
    try {
      await LocalDB.ClearData();
      await LocalDB.CloseDatabase();
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('Connection Pool Tests', () {
    test('Should validate connection after hot reload simulation', () async {
      // Create some test data first
      final result = await LocalDB.Post('connection-test', {'value': 'test'});
      expect(result.isOk, true);

      // Verify connection is valid
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);

      // Simulate connection validation with data retrieval
      final retrieved = await LocalDB.GetById('connection-test');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['value'], 'test');
    });

    test('Should handle connection recovery gracefully', () async {
      // Test that we can recover from potential connection issues
      for (int i = 0; i < 5; i++) {
        final result = await LocalDB.Post('recovery-test-$i', {'iteration': i});
        expect(result.isOk, true);
        
        // Force connection validation
        final isValid = await LocalDB.IsConnectionValid();
        expect(isValid, true);
      }

      // Verify all data was stored correctly
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, greaterThanOrEqualTo(5));
    });

    test('Should maintain connection stability during rapid operations', () async {
      final operations = <Future>[];
      
      // Perform multiple rapid operations that would stress the connection pool
      for (int i = 0; i < 20; i++) {
        operations.add(LocalDB.Post('rapid-pool-$i', {'index': i}));
      }
      
      final results = await Future.wait(operations);
      expect(results.every((result) => result.isOk), true);
      
      // Verify connection is still valid after all operations
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
      
      // Verify data integrity
      final finalData = await LocalDB.GetAll();
      expect(finalData.isOk, true);
      expect(finalData.data.length, greaterThanOrEqualTo(20));
    });

    test('Should handle multiple database reinitializations', () async {
      // Test multiple init cycles to simulate hot restarts
      for (int cycle = 0; cycle < 3; cycle++) {
        await LocalDB.init(localDbName: 'reinit_test_$cycle.db');
        
        // Test basic operations after each reinit
        final testResult = await LocalDB.Post('reinit-$cycle', {'cycle': cycle});
        expect(testResult.isOk, true);
        
        final retrieved = await LocalDB.GetById('reinit-$cycle');
        expect(retrieved.isOk, true);
        expect(retrieved.data?.data['cycle'], cycle);
        
        // Close and prepare for next cycle
        await LocalDB.CloseDatabase();
      }
      
      // Final reinit to clean state
      await LocalDB.initForTesting(
        localDbName: 'connection_pool_test.db',
        binaryPath: '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');
    });

    test('Should validate connection health with ping operations', () async {
      // Create test data
      await LocalDB.Post('ping-test', {'timestamp': DateTime.now().toIso8601String()});
      
      // Validate connection health multiple times
      for (int i = 0; i < 5; i++) {
        final isValid = await LocalDB.IsConnectionValid();
        expect(isValid, true);
        
        // Perform a quick operation to ensure responsiveness
        final quickTest = await LocalDB.GetById('ping-test');
        expect(quickTest.isOk, true);
        
        // Small delay to simulate real usage patterns
        await Future.delayed(const Duration(milliseconds: 100));
      }
    });
  });

  group('Generation System Tests', () {
    test('Should handle generation-based validation', () async {
      // Test that generation system works with normal operations
      final testData = await LocalDB.Post('generation-test', {'version': 1});
      expect(testData.isOk, true);
      
      // Update the data to test generation tracking
      final updateResult = await LocalDB.Put('generation-test', {'version': 2});
      expect(updateResult.isOk, true);
      
      // Verify the update was applied
      final finalData = await LocalDB.GetById('generation-test');
      expect(finalData.isOk, true);
      expect(finalData.data?.data['version'], 2);
    });

    test('Should maintain generation consistency across operations', () async {
      // Create multiple records to test generation consistency
      final operations = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        operations.add(LocalDB.Post('gen-test-$i', {'generation_marker': i}));
      }
      
      final results = await Future.wait(operations);
      expect(results.every((result) => result.isOk), true);
      
      // Verify all records are accessible (generation validation passes)
      for (int i = 0; i < 10; i++) {
        final retrieved = await LocalDB.GetById('gen-test-$i');
        expect(retrieved.isOk, true);
        expect(retrieved.data?.data['generation_marker'], i);
      }
    });

    test('Should handle edge cases in generation tracking', () async {
      // Test rapid creation and deletion which stresses generation tracking
      for (int i = 0; i < 5; i++) {
        await LocalDB.Post('temp-$i', {'temp': true});
        await LocalDB.Delete('temp-$i');
      }
      
      // Verify connection is still healthy after stress operations
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
      
      // Verify we can still perform normal operations
      final normalOp = await LocalDB.Post('post-stress', {'after_stress': true});
      expect(normalOp.isOk, true);
    });
  });

  group('Hot Reload Recovery Integration Tests', () {
    test('Should detect and recover from simulated hot reload scenarios', () async {
      // Create initial data
      await LocalDB.Post('pre-reload', {'state': 'before'});
      
      // Simulate potential hot reload by forcing connection validation
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
      
      // Verify data persists through validation
      final preData = await LocalDB.GetById('pre-reload');
      expect(preData.isOk, true);
      expect(preData.data?.data['state'], 'before');
      
      // Add post-"reload" data
      await LocalDB.Post('post-reload', {'state': 'after'});
      
      // Verify both records exist
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, greaterThanOrEqualTo(2));
    });

    test('Should maintain data integrity through multiple validation cycles', () async {
      // Create baseline data
      final initialData = {'baseline': true, 'timestamp': DateTime.now().millisecondsSinceEpoch};
      await LocalDB.Post('integrity-test', initialData);
      
      // Perform multiple validation cycles
      for (int cycle = 0; cycle < 3; cycle++) {
        // Force validation
        final isValid = await LocalDB.IsConnectionValid();
        expect(isValid, true);
        
        // Verify data integrity after each validation
        final retrieved = await LocalDB.GetById('integrity-test');
        expect(retrieved.isOk, true);
        expect(retrieved.data?.data['baseline'], true);
        
        // Update data to verify write operations work after validation
        await LocalDB.Put('integrity-test', {
          ...initialData,
          'validation_cycle': cycle,
        });
      }
      
      // Final verification
      final finalData = await LocalDB.GetById('integrity-test');
      expect(finalData.isOk, true);
      expect(finalData.data?.data['validation_cycle'], 2);
    });
  });
}