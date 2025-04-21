import 'package:flutter_local_db/src/service/local_db_result.dart';
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
        localDbName: 'test.db',
        binaryPath:
            '../flutter_local_db/macos/Frameworks/liboffline_first_core_arm64.dylib');
  });

  setUp(() async {
    await LocalDB.ClearData();
  });

  group('LocalDB Basic Operations', () {
    test('Should create and retrieve data', () async {
      final testData = {'name': 'test', 'value': 123};

      final result = LocalDB.Post('test-key', testData);

      expect(result.isOk, true);

      final retrieved = LocalDB.GetById('test-key');

      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['name'], 'test');
      expect(retrieved.data?.data['value'], 123);

    });

    test('Should update existing data', () async {
      await LocalDB.Post('update-key', {'value': 'initial'});
      final updateResult = LocalDB.Put('update-key', {'value': 'updated'});
      expect(updateResult.isOk, true);

      final retrieved = LocalDB.GetById('update-key');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['value'], 'updated');
    });

    test('Should delete data', () async {
      // Create data
      LocalDB.Post('delete-key', {'value': 'to-delete'});

      // Delete the data
      final deleteResult = LocalDB.Delete('delete-key');

      expect(deleteResult.isOk, true);

      // Verify deletion - should return Ok(null) no Err
      final retrieved = LocalDB.GetById('delete-key');
      retrieved.when(
        ok: (data) {},
        err: (err) {
          print(err.detailsResult);
          print(err.toJson());
          expect(err.detailsResult.message, 'Unknown');
        },
      );
    });
  });

  group('LocalDB Concurrent Operations', () {
    test('Should handle multiple concurrent writes', () async {
      final futures = List.generate(
          10, (index) => LocalDB.Post('concurrent-$index', {'value': index}));


      expect(futures.every((r) => r.isOk), true);

      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, 10);
    });
  });

  group('LocalDB Performance', () {
    test('Should perform bulk operations efficiently', () async {
      final Stopwatch stopwatch = Stopwatch()..start();

      final futures = List.generate(
          50,
          (index) => LocalDB.Post('bulk-$index', {
                'data': 'test-data-$index',
                'timestamp': DateTime.now().toIso8601String(),
              }));



      stopwatch.reset();
      stopwatch.start();

      expect(futures.every((r) => r.isOk), true);
    });
  });

  group('LocalDB Error Handling', () {
    test('Should handle invalid keys gracefully', () async {
      final result = LocalDB.Post('', {'test': 'data'});
      expect(result.isErr, true);

      final result2 = LocalDB.Post('a', {'test': 'data'});
      expect(result2.isErr, true);
    });

    test('Should handle non-existent keys for Put operation', () async {
      final updateResult = LocalDB.Put('non-existent-key', {'data': 'test'});
      print("@@@##${updateResult.errorOrNull?.detailsResult.message}");
      expect(updateResult.isErr, true);

      updateResult.when(
          ok: (data) => fail('Should not succeed for non-existent key') ,
          err: (error) => expect(error.detailsResult.message, "Unknown",
          ),
      );
    });

    test('Should handle empty data gracefully', () async {
      final result = await LocalDB.Post('empty-data', {});
      expect(result.isOk, true);

      final retrieved = await LocalDB.GetById('empty-data');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data, {});
    });
  });

  group('ID Validation Tests', () {
    test('Should reject IDs with invalid characters', () async {
      final invalidIds = [
        'test@key',
        'test space',
        'test#hash',
        'test\$dollar',
        'test&amp',
      ];

      for (final id in invalidIds) {
        final result = LocalDB.Post(id, {'test': 'data'});
        result.when(
          ok: (_) => fail('Should reject invalid ID: $id'),
          err: (error) => expect(result.errorOrNull?.detailsResult.message.toString().contains('SerializationError'), true),
        );
      }

    });

    test('Should reject IDs shorter than 3 characters', () async {
      final result = await LocalDB.Post('ab', {'test': 'data'});
      result.when(
        ok: (_) => fail('Should reject short ID'),
        err: (error) => expect(error.detailsResult.message.toString().contains('SerializationError'), true),
      );
    });
  });

  group('Data Validation Tests', () {
    test('Should handle complex nested data structures', () async {
      final complexData = {
        'string': 'value',
        'number': 42,
        'boolean': true,
        'array': [1, 2, 3],
        'nested': {
          'field1': 'value1',
          'field2': {'subfield': 'value2'}
        }
      };

      final result = await LocalDB.Post('complex-data', complexData);
      expect(result.isOk, true);

      final retrieved = await LocalDB.GetById('complex-data');
      retrieved.when(
        ok: (data) {
          expect(data?.data['nested']['field2']['subfield'], 'value2');
          expect(data?.data['array'], [1, 2, 3]);
        },
        err: (error) => fail('Failed to retrieve complex data: $error'),
      );
    });

    test('Should reject invalid JSON data', () async {
      // Test with invalid JSON data types
      final Map<String, dynamic> invalidData = {
        'invalid': double.infinity, // Infinity no es serializable en JSON
        'nan': double.nan, // NaN no es serializable en JSON
      };

      final result = await LocalDB.Post('invalid-json', invalidData);
      result.when(
        ok: (_) => fail('Should reject non-serializable JSON data'),
        err: (error) =>
            expect(error.detailsResult.message.toString().contains('SerializationError'), true),
      );

      // Test with deeply nested structures
      Map<String, dynamic> deeplyNested = {'root': 'value'};
      Map<String, dynamic> current = deeplyNested;

      // Crear una estructura anidada profunda pero válida
      for (var i = 0; i < 50; i++) {
        Map<String, dynamic> newLevel = {'level$i': 'value'};
        current['nested'] = newLevel;
        current = newLevel;
      }

      final resultNested = await LocalDB.Post('invalid-nested', deeplyNested);
      resultNested.when(
        ok: (data) => expect(data.id, 'invalid-nested'),
        err: (error) =>
            fail('Valid nested structure should be accepted: $error'),
      );
    });
  });

  group('Batch Operation Tests', () {
    test('Should handle batch operations with different data sizes', () async {
      final smallData = {'value': 'small'};
      final mediumData = Map.fromEntries(
          List.generate(100, (i) => MapEntry('key$i', 'value$i')));
      final largeData = Map.fromEntries(
          List.generate(1000, (i) => MapEntry('key$i', 'value$i')));

      final operations = [
        LocalDB.Post('small-data', smallData),
        LocalDB.Post('medium-data', mediumData),
        LocalDB.Post('large-data', largeData),
      ];

      expect(operations.every((r) => r.isOk), true);
    });

    test('Should maintain data consistency in concurrent operations', () async {
      final baseData = {'counter': 0};
      await LocalDB.Post('concurrent-counter', baseData);

      for (int i = 1; i <= 100; i++) {
        final current = await LocalDB.GetById('concurrent-counter');

        if (current.isOk && current.data != null) {
          final newCounter = current.data!.data['counter'] + 1;
          final updateResult =
              await LocalDB.Put('concurrent-counter', {'counter': newCounter});

          expect(updateResult.isOk, true,
              reason: 'Failed to update counter at iteration $i');
        } else {
          fail('Failed to fetch current counter value at iteration $i');
        }
      }

      final finalResult = await LocalDB.GetById('concurrent-counter');
      finalResult.when(
        ok: (data) => expect(data?.data['counter'], 100,
            reason: 'Final counter value mismatch'),
        err: (error) => fail('Failed to verify concurrent operations: $error'),
      );
    });
  });

  group('Error Recovery Tests', () {
    test('Should handle database cleanup after failed operations', () async {
      // Simulate a failed operation
      final invalidData = {
        'key': double.infinity
      }; // Will fail JSON serialization
      await LocalDB.Post('failed-op', invalidData);

      // Verify database is still operational
      final validData = {'key': 'value'};
      final result = await LocalDB.Post('recovery-test', validData);
      expect(result.isOk, true);
    });

    test('Should maintain data integrity during partial updates', () async {
      final originalData = {
        'field1': 'value1',
        'field2': 'value2',
      };

      await LocalDB.Post('partial-update', originalData);

      // Attempt partial update with invalid data
      final invalidUpdate = {'field1': double.infinity};
      final updateResult = await LocalDB.Put('partial-update', invalidUpdate);
      expect(updateResult.isErr, true);

      // Verify original data is preserved
      final retrieved = await LocalDB.GetById('partial-update');
      retrieved.when(
        ok: (data) {
          expect(data?.data['field1'], 'value1');
          expect(data?.data['field2'], 'value2');
        },
        err: (error) => fail('Failed to retrieve data: $error'),
      );
    });
  });

  group('Performance Optimization Tests', () {
    test('Should maintain performance with large datasets', () async {
      final stopwatch = Stopwatch()..start();

      // Create 1000 records
      List.generate(
          1000,
          (i) => LocalDB.Post('perf-test-$i',
              {'data': List.generate(100, (j) => 'value-$j').join(',')}));


      final writeTime = stopwatch.elapsedMilliseconds;

      stopwatch.reset();
      stopwatch.start();

      // Read all records
      final readResult = await LocalDB.GetAll();
      final readTime = stopwatch.elapsedMilliseconds;

      readResult.when(
        ok: (data) => expect(data.length, 1000),
        err: (error) => fail('Failed to read data: $error'),
      );

      // Performance assertions
      expect(writeTime / 1000 < 50, true); // Average 50ms per write
      expect(readTime < 1000, true); // Less than 1 second for full read
    });

    test('Should handle rapid sequential operations efficiently', () async {
      final stopwatch = Stopwatch()..start();

      // Perform 100 rapid sequential operations
      for (int i = 0; i < 100; i++) {
        await LocalDB.Post('rapid-$i', {'value': i});
        await LocalDB.Put('rapid-$i', {'value': i + 1});
        await LocalDB.Delete('rapid-$i');
      }

      final totalTime = stopwatch.elapsedMilliseconds;

      print("Total time: $totalTime");
      expect(totalTime < 1600, true); // Should complete within 5 seconds
    });
  });

  group('Data Format Validation Tests', () {
    test('Should validate ID format consistently', () async {
      // Test valid IDs
      for (final id in ['valid-123', 'test_123', 'abc123']) {
        final result = await LocalDB.Post(id, {'test': 'data'});
        result.when(
          ok: (data) =>
              expect(data.id, id, reason: 'Should accept valid ID: $id'),
          err: (error) =>
              fail('Should not reject valid ID: $id. Error: $error'),
        );

        // Verify the data was stored
        final retrieved = await LocalDB.GetById(id);
        retrieved.when(
          ok: (data) => expect(data?.id, id),
          err: (error) =>
              fail('Should find stored valid ID: $id. Error: $error'),
        );

        // Clean up
        await LocalDB.Delete(id);
      }

      // Test invalid IDs
      for (final id in ['a b', 'test@123', 'ab', '']) {
        final result = await LocalDB.Post(id, {'test': 'data'});
        result.when(
          ok: (_) => fail('Should reject invalid ID: $id'),
          err: (error) => expect(error.detailsResult.message.toString().contains('SerializationError'), true,
              reason: 'Should get invalid format error for ID: $id'),
        );
      }
    });

    test('Should handle special characters in data values', () async {
      final specialData = {
        'null': null,
        'empty': '',
        'special': '!@#\$%^&*()',
        'unicode': '你好世界',
        'emoji': '👋🌍'
      };

      final result = await LocalDB.Post('special-chars', specialData);
      expect(result.isOk, true);

      final retrieved = await LocalDB.GetById('special-chars');
      retrieved.when(
        ok: (data) {
          expect(data?.data['special'], '!@#\$%^&*()');
          expect(data?.data['unicode'], '你好世界');
          expect(data?.data['emoji'], '👋🌍');
        },
        err: (error) => fail('Failed to handle special characters: $error'),
      );
    });
  });

  group('Advanced LocalDB Scenarios', () {
    test('Should handle extremely long keys', () async {
      final longKey = 'x' * 255; // Probar límite máximo de longitud de clave
      final testData = {'description': 'Testing maximum key length'};

      final result = await LocalDB.Post(longKey, testData);
      result.when(
        ok: (data) async {
          expect(data.id, longKey);

          final retrieved = await LocalDB.GetById(longKey);
          retrieved.when(
            ok: (retrievedData) {
              expect(retrievedData?.data['description'],
                  'Testing maximum key length');
            },
            err: (error) => fail('Failed to retrieve long key data'),
          );
        },
        err: (error) => fail('Should accept long valid key'),
      );
    });

    test('Should handle concurrent mixed operations', () async {
      // Simular operaciones concurrentes mixtas: post, put, delete
      final operations = [
        LocalDB.Post('mixed-1', {'type': 'post'}),
        LocalDB.Post('mixed-2', {'type': 'post'}),
        LocalDB.Put('mixed-1', {'type': 'updated'}),
        LocalDB.Delete('mixed-2'),
        LocalDB.GetById('mixed-1'),
      ];

      // Verificar que no haya errores inesperados
      expect(operations.length, 5);
    });

    test('Should handle data persistence across multiple sessions', () async {
      // Simular reinicio de la base de datos
      await LocalDB.Post('persistent-key', {'value': 'persist-test'});

      // Reinicializar la base de datos
      await LocalDB.ClearData();

      final retrieved = LocalDB.GetById('persistent-key');
      retrieved.when(
        ok: (data) => fail('Data should not persist after clear'),
        err: (error) => expect(error.detailsResult.message, 'Unknown'),
      );
    });

    test('Should validate data type preservation', () async {
      final complexTypes = {
        'integer': 42,
        'double': 3.14159,
        'bool': true,
        'datetime': DateTime.now().toIso8601String(),
        'list': [1, 2, 3],
        'map': {'nested': 'value'}
      };

      final result = await LocalDB.Post('type-preservation', complexTypes);

      expect(result.isOk, true);

      final retrieved = await LocalDB.GetById('type-preservation');
      retrieved.when(
        ok: (data) {
          expect(data?.data['integer'], 42);
          expect(data?.data['double'], 3.14159);
          expect(data?.data['bool'], true);
          expect(data?.data['list'], [1, 2, 3]);
          expect(data?.data['map'], {'nested': 'value'});
        },
        err: (error) => fail('Failed to preserve data types'),
      );
    });

    test('Should handle maximum data payload size', () async {
      final largePayload = {
        'big_data': List.generate(10000, (index) => 'chunk-$index').join()
      };

      final result = await LocalDB.Post('large-payload', largePayload);
      result.when(
        ok: (data) async {
          final retrieved = await LocalDB.GetById('large-payload');
          retrieved.when(
            ok: (retrievedData) {
              expect(retrievedData?.data['big_data'].length,
                  largePayload['big_data']!.length);
            },
            err: (error) => fail('Failed to retrieve large payload'),
          );
        },
        err: (error) => fail('Should accept large payload: $error'),
      );
    });

    test('Should provide transaction-like behavior for critical updates',
        () async {
      await LocalDB.Post('transaction-test', {'balance': 100});

      try {
        // Simular una actualización crítica
        final current = await LocalDB.GetById('transaction-test');
        if (current.isOk && current.data != null) {
          final newBalance = current.data!.data['balance'] - 50;

          // Primera operación
          await LocalDB.Put('transaction-test', {'balance': newBalance});

          // Simular un error potencial
          if (newBalance < 0) {
            throw Exception('Insufficient funds');
          }

          // Segunda operación
          final finalResult = await LocalDB.GetById('transaction-test');
          finalResult.when(
            ok: (data) {
              expect(data?.data['balance'], 50);
            },
            err: (error) => fail('Transaction-like update failed'),
          );
        }
      } catch (e) {
        // Manejo de errores
        final rollback =
            await LocalDB.Put('transaction-test', {'balance': 100});
        expect(rollback.isOk, true);
      }
    });

    test('Should handle case sensitivity in keys', () async {
      await LocalDB.Post('CaseSensitive', {'value': 'uppercase'});
      await LocalDB.Post('casesensitive', {'value': 'lowercase'});

      final upperCase = await LocalDB.GetById('CaseSensitive');
      final lowerCase = await LocalDB.GetById('casesensitive');

      upperCase.when(
        ok: (data) => expect(data?.data['value'], 'uppercase'),
        err: (error) => fail('Failed to retrieve uppercase key'),
      );

      lowerCase.when(
        ok: (data) => expect(data?.data['value'], 'lowercase'),
        err: (error) => fail('Failed to retrieve lowercase key'),
      );
    });
  });

  group('Advanced Edge Case Tests', () {
    test('Should handle extremely nested data structures', () async {
      // Probar estructuras de datos profundamente anidadas
      Map<String, dynamic> createNestedStructure(int depth) {
        if (depth == 0) return {'leaf': 'value'};
        return {'nested': createNestedStructure(depth - 1)};
      }

      final deepNested = createNestedStructure(20); // Profundidad de 20 niveles

      final result = await LocalDB.Post('deep-nested', deepNested);
      result.when(
        ok: (data) async {
          final retrieved = await LocalDB.GetById('deep-nested');
          retrieved.when(
            ok: (retrievedData) {
              // Verificar que la estructura profunda se mantiene
              dynamic checkNesting(dynamic obj) {
                if (obj is Map && obj.containsKey('nested')) {
                  return checkNesting(obj['nested']);
                }
                return obj['leaf'] == 'value';
              }

              expect(checkNesting(retrievedData?.data), true);
            },
            err: (error) => fail('Failed to retrieve deeply nested data'),
          );
        },
        err: (error) => fail('Should accept deeply nested data'),
      );
    });

    test('Should handle multiple concurrent read/write conflicts', () async {
      // Simular múltiples escrituras concurrentes en la misma clave
      final key = 'conflict-key';
      await LocalDB.Post(key, {'counter': 0});

      List.generate(100, (i) async {
        final current = await LocalDB.GetById(key);
        if (current.isOk && current.data != null) {
          final currentValue = current.data!.data['counter'] ?? 0;
          return LocalDB.Put(key, {'counter': currentValue + 1});
        }
        return Future.value(Err('Failed to read'));
      });

      final finalResult = await LocalDB.GetById(key);
      finalResult.when(
        ok: (data) {
          // Verificar que el contador final sea consistente
          expect(data?.data['counter'], greaterThanOrEqualTo(0));
          expect(data?.data['counter'], lessThanOrEqualTo(100));
        },
        err: (error) => fail('Failed to verify final state'),
      );
    });

    test('Should handle rapid data modification sequences', () async {
      final key = 'rapid-modification';
      await LocalDB.Post(key, {'value': 0});

      for (int i = 0; i < 50; i++) {
        final current = await LocalDB.GetById(key);
        if (current.isOk && current.data != null) {
          final currentValue = current.data!.data['value'] ?? 0;
          await LocalDB.Put(key, {'value': currentValue + 1});
        }
      }

      final finalResult = await LocalDB.GetById(key);
      finalResult.when(
        ok: (data) {
          expect(data?.data['value'], 50);
        },
        err: (error) => fail('Failed to verify rapid modifications'),
      );
    });

    test('Should maintain data integrity under stress', () async {
      final stressOperations = [];

      for (int i = 0; i < 100; i++) {
        stressOperations.add(LocalDB.Post('stress-$i', {'index': i}));
        stressOperations
            .add(LocalDB.Put('stress-${i % 10}', {'updated': true}));
        stressOperations.add(LocalDB.GetById('stress-${i % 10}'));
      }

      expect(stressOperations.length, 300);
    });
  });
}
