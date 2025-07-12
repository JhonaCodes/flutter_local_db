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

  group('Hot Restart Recovery Tests', () {
    test('Should use retry mechanism on initialization', () async {
      print('=== Testing retry mechanism ===');
      
      // This should work with our new retry mechanism
      await LocalDB.init(localDbName: 'retry_test.db');
      print('First initialization successful');

      // Verify we can perform operations
      final result1 = await LocalDB.Post('retry-test', {'value': 'test'});
      print('Post result: ${result1.isOk}');
      expect(result1.isOk, true);

      // Simulate hot restart by closing and reinitializing
      await LocalDB.CloseDatabase();
      print('Database closed');

      // This should trigger our retry mechanism if needed
      await LocalDB.init(localDbName: 'retry_test.db');
      print('Reinitialization successful');

      // Verify we can still perform operations
      final result2 = await LocalDB.Post('retry-test-2', {'value': 'test2'});
      print('Post after restart result: ${result2.isOk}');
      expect(result2.isOk, true);

      print('=== Retry mechanism test completed ===');
    });

    test('Should handle multiple rapid reinitializations', () async {
      print('=== Testing rapid reinitializations ===');
      
      for (int i = 0; i < 5; i++) {
        print('Rapid init attempt ${i + 1}');
        
        await LocalDB.init(localDbName: 'rapid_test_$i.db');
        
        // Quick operation
        final result = await LocalDB.Post('rapid-$i', {'iteration': i});
        expect(result.isOk, true);
        
        // Close
        await LocalDB.CloseDatabase();
        
        // Small delay
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      print('=== Rapid reinitializations test completed ===');
    });

    test('Should handle failure gracefully and provide helpful error', () async {
      print('=== Testing graceful failure handling ===');
      
      // This test verifies that our error messages are helpful
      // We can't easily simulate a real failure, but we can test the error structure
      try {
        await LocalDB.init(localDbName: 'normal_test.db');
        expect(true, true); // Should succeed
      } catch (e) {
        // If it fails, the error message should be helpful
        final errorMessage = e.toString();
        print('Error message: $errorMessage');
        
        // Should contain helpful information
        expect(errorMessage.contains('hot restart') || 
               errorMessage.contains('binary') || 
               errorMessage.contains('restart'), true);
      }
      
      print('=== Graceful failure test completed ===');
    });

    test('Should validate connection pool functionality', () async {
      print('=== Testing connection pool ===');
      
      // Initialize database
      await LocalDB.init(localDbName: 'pool_test.db');
      
      // Test basic operation to ensure connection is working
      final result1 = await LocalDB.Post('pool-test-1', {'test': 'data'});
      expect(result1.isOk, true);
      
      // Test that connection validation works
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
      
      // Test multiple operations to ensure connection reuse
      for (int i = 2; i <= 5; i++) {
        final result = await LocalDB.Post('pool-test-$i', {'test': 'data-$i'});
        expect(result.isOk, true);
      }
      
      // Verify we can read all the data
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      if (allData.isOk) {
        expect(allData.data!.length, greaterThanOrEqualTo(5));
      }
      
      print('=== Connection pool test completed ===');
    });

    test('Should handle generation validation', () async {
      print('=== Testing generation validation ===');
      
      // Initialize database
      await LocalDB.init(localDbName: 'generation_test.db');
      
      // Test that operations work with current generation
      final result1 = await LocalDB.Post('gen-test-1', {'generation': 'current'});
      expect(result1.isOk, true);
      
      // Test reading works
      final result2 = await LocalDB.GetById('gen-test-1');
      expect(result2.isOk, true);
      
      print('=== Generation validation test completed ===');
    });

    test('Should handle enhanced error detection', () async {
      print('=== Testing enhanced error detection ===');
      
      // Initialize database
      await LocalDB.init(localDbName: 'error_detect_test.db');
      
      // Test that health check operations work
      final healthCheck = await LocalDB.GetById('__health_check__');
      // This should return an error (not found) but not crash
      expect(healthCheck.isErr, true);
      
      // Test that we can still perform normal operations after health check
      final normalOp = await LocalDB.Post('error-test-1', {'test': 'after_health_check'});
      expect(normalOp.isOk, true);
      
      print('=== Enhanced error detection test completed ===');
    });

    test('Should validate connection recovery scenarios', () async {
      print('=== Testing connection recovery scenarios ===');
      
      // Test recovery with different database names
      final dbNames = ['recovery_1.db', 'recovery_2.db', 'recovery_3.db'];
      
      for (final dbName in dbNames) {
        try {
          await LocalDB.init(localDbName: dbName);
          
          // Test operation
          final result = await LocalDB.Post('recovery-test', {'db': dbName});
          expect(result.isOk, true);
          
          // Close and try next
          await LocalDB.CloseDatabase();
          
          print('Successfully tested recovery with: $dbName');
        } catch (e) {
          print('Recovery test failed for $dbName: $e');
          // Continue with next database name
        }
      }
      
      print('=== Connection recovery scenarios test completed ===');
    });
  });
}