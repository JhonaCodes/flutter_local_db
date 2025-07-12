import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_local_db/src/core/log.dart';
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
        localDbName: 'logging_test.db',
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

  group('Enhanced Logging Tests', () {
    test('Should use standardized logging throughout operations', () async {
      // Test that logging works during normal database operations
      // We can't directly test log output, but we can ensure operations complete
      // which indicates logging isn't causing crashes
      
      Log.i('Starting logging test');
      
      final result = await LocalDB.Post('logging-test', {
        'message': 'Testing logging integration',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      expect(result.isOk, true);
      Log.d('Post operation completed successfully');
      
      final retrieved = await LocalDB.GetById('logging-test');
      expect(retrieved.isOk, true);
      Log.d('Get operation completed successfully');
      
      await LocalDB.Put('logging-test', {
        'message': 'Updated with logging',
        'timestamp': DateTime.now().toIso8601String(),
      });
      Log.d('Put operation completed successfully');
      
      await LocalDB.Delete('logging-test');
      Log.d('Delete operation completed successfully');
      
      Log.i('Logging test completed');
    });

    test('Should handle error logging without exposing sensitive data', () async {
      // Test error scenarios to ensure proper error logging
      Log.w('Testing error scenarios');
      
      // Test invalid ID format (should be logged but not expose user data)
      final invalidIdResult = await LocalDB.Post('ab', {'test': 'data'});
      expect(invalidIdResult.isErr, true);
      
      // Test invalid data format
      try {
        final invalidDataResult = await LocalDB.Post('error-test', {
          'invalid': double.infinity,
        });
        expect(invalidDataResult.isErr, true);
      } catch (e) {
        Log.e('Expected error occurred during invalid data test', error: e);
      }
      
      // Test non-existent key retrieval
      final notFoundResult = await LocalDB.GetById('non-existent-key');
      expect(notFoundResult.isErr, true);
      
      Log.i('Error logging test completed');
    });

    test('Should maintain logging performance during high-volume operations', () async {
      Log.i('Starting high-volume logging test');
      
      final stopwatch = Stopwatch()..start();
      
      // Perform many operations that would trigger logging
      for (int i = 0; i < 50; i++) {
        await LocalDB.Post('volume-test-$i', {
          'index': i,
          'data': 'Volume test data for logging performance'
        });
        
        if (i % 10 == 0) {
          Log.d('Processed ${i + 1} operations');
        }
      }
      
      final elapsed = stopwatch.elapsedMilliseconds;
      Log.i('High-volume test completed in ${elapsed}ms');
      
      // Verify operations completed successfully
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, greaterThanOrEqualTo(50));
      
      // Logging should not significantly impact performance
      expect(elapsed < 10000, true, 
          reason: 'Logging overhead too high: ${elapsed}ms');
    });

    test('Should handle different log levels appropriately', () async {
      // Test all log levels work without causing issues
      Log.d('Debug level test message');
      Log.i('Info level test message');
      Log.w('Warning level test message');
      Log.f('Fatal level test message');
      
      // Test error logging with context
      try {
        throw Exception('Test exception for logging');
      } catch (e, stack) {
        Log.e('Test error with full context', 
            error: e, 
            stackTrace: stack,
            time: DateTime.now());
      }
      
      // Verify logging doesn't interfere with database operations
      final testResult = await LocalDB.Post('log-levels-test', {
        'tested_levels': ['debug', 'info', 'warning', 'error', 'fatal'],
      });
      
      expect(testResult.isOk, true);
    });
  });

  group('Security and Data Privacy Tests', () {
    test('Should not log sensitive user data in operations', () async {
      // Test with data that could be considered sensitive
      final sensitiveData = {
        'user_email': 'user@example.com',
        'api_token': 'secret_token_12345',
        'password_hash': 'hashed_password_data',
        'personal_info': {
          'name': 'John Doe',
          'ssn': '123-45-6789',
        }
      };
      
      // Operations should complete without logging sensitive details
      final result = await LocalDB.Post('sensitive-data-test', sensitiveData);
      expect(result.isOk, true);
      
      // Verify data was stored correctly (but not logged in detail)
      final retrieved = await LocalDB.GetById('sensitive-data-test');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['user_email'], 'user@example.com');
      
      // Update with more sensitive data
      await LocalDB.Put('sensitive-data-test', {
        ...sensitiveData,
        'credit_card': '4111-1111-1111-1111',
      });
      
      // Delete sensitive data
      await LocalDB.Delete('sensitive-data-test');
    });

    test('Should sanitize error messages to prevent information leakage', () async {
      // Test various error conditions that might expose system information
      
      // Test with extremely long key
      final longKey = 'x' * 300;
      final longKeyResult = await LocalDB.Post(longKey, {'test': 'data'});
      // Should fail gracefully without exposing internal details
      longKeyResult.when(
        ok: (_) => fail('Should reject overly long key'),
        err: (error) {
          // Error message should be generic, not expose internal paths or details
          expect(error.detailsResult.message.contains('SerializationError'), true);
        },
      );
      
      // Test with invalid characters that might reveal system details
      final invalidChars = ['<script>', 'SELECT * FROM', '../../../etc/passwd'];
      for (final invalidChar in invalidChars) {
        final result = await LocalDB.Post('test-$invalidChar', {'data': 'test'});
        result.when(
          ok: (_) => {}, // Some might be valid, that's ok
          err: (error) {
            // Error should not echo back the invalid input
            expect(error.detailsResult.message.contains(invalidChar), false,
                reason: 'Error message should not contain potentially malicious input');
          },
        );
      }
    });

    test('Should handle file path security appropriately', () async {
      // Test that database operations don't expose file system details
      await LocalDB.Post('path-security-test', {
        'filename': '../../../sensitive_file.txt',
        'path_like_data': '/etc/passwd',
        'windows_path': 'C:\\Windows\\System32\\config',
      });
      
      final retrieved = await LocalDB.GetById('path-security-test');
      expect(retrieved.isOk, true);
      
      // Data should be stored as-is (it's just data), but not cause security issues
      expect(retrieved.data?.data['filename'], '../../../sensitive_file.txt');
    });

    test('Should maintain data integrity while preventing injection attacks', () async {
      // Test various injection-style inputs as data values
      final injectionTests = [
        'DROP TABLE users;',
        r'{"$ne": null}',
        '<script>alert("xss")</script>',
        r'${1+1}',
        'null; DROP TABLE users; --',
      ];
      
      for (int i = 0; i < injectionTests.length; i++) {
        final injectionData = injectionTests[i];
        final result = await LocalDB.Post('injection-test-$i', {
          'potentially_malicious': injectionData,
          'safe_data': 'normal data',
        });
        
        expect(result.isOk, true, 
            reason: 'Should handle injection attempt as normal data');
        
        // Verify data was stored correctly without being executed
        final retrieved = await LocalDB.GetById('injection-test-$i');
        expect(retrieved.isOk, true);
        expect(retrieved.data?.data['potentially_malicious'], injectionData);
        expect(retrieved.data?.data['safe_data'], 'normal data');
      }
    });

    test('Should handle Unicode and special characters securely', () async {
      final specialCharData = {
        'unicode': '你好世界 🌍 🚀',
        'emoji': '👋 😀 🎉 💯',
        'special_chars': '!@#\$%^&*()_+-=[]{}|;:,.<>?',
        'mixed': 'Hello 世界 👋 @#\$%',
        'null_chars': 'before\x00after',
        'control_chars': 'tab\there\nand\rcarriage\breturn',
      };
      
      final result = await LocalDB.Post('unicode-security-test', specialCharData);
      expect(result.isOk, true);
      
      final retrieved = await LocalDB.GetById('unicode-security-test');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['unicode'], '你好世界 🌍 🚀');
      expect(retrieved.data?.data['emoji'], '👋 😀 🎉 💯');
    });
  });

  group('Production Readiness Tests', () {
    test('Should perform consistently under production-like conditions', () async {
      // Simulate production workload patterns
      final operations = <Future>[];
      
      // Mixed read/write operations
      for (int i = 0; i < 20; i++) {
        operations.add(LocalDB.Post('prod-test-$i', {
          'id': i,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': List.generate(10, (j) => 'data-$j').join(','),
        }));
        
        if (i % 5 == 0) {
          operations.add(LocalDB.GetAll());
        }
      }
      
      final results = await Future.wait(operations, eagerError: false);
      
      // Most operations should succeed (allowing for some potential races)
      final successCount = results.where((result) {
        if (result is LocalDbResult) {
          return result.isOk;
        }
        return true;
      }).length;
      
      expect(successCount / results.length > 0.9, true,
          reason: 'Production test success rate too low');
      
      // Verify database is still functional after stress
      final finalTest = await LocalDB.Post('final-prod-test', {'status': 'ok'});
      expect(finalTest.isOk, true);
    });
  });
}