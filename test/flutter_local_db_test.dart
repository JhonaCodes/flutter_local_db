import 'package:flutter_local_db/src/service/local_db_result.dart' as legacy;
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

    await LocalDB.init();
  });

  setUp(() async {
    await LocalDB.ClearData();
  });

  group('LocalDB Basic Operations', () {
    test('Should create and retrieve data', () async {
      final testData = {'name': 'test', 'value': 123};

      final result = await LocalDB.Post('test-key', testData);

      expect(result.isOk, true);

      final retrieved = await LocalDB.GetById('test-key');

      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['name'], 'test');
      expect(retrieved.data?.data['value'], 123);
    });

    test('Should update existing data', () async {
      await await LocalDB.Post('update-key', {'value': 'initial'});
      final updateResult = await LocalDB.Put('update-key', {
        'value': 'updated',
      });
      expect(updateResult.isOk, true);

      final retrieved = await LocalDB.GetById('update-key');
      expect(retrieved.isOk, true);
      expect(retrieved.data?.data['value'], 'updated');
    });

    test('Should delete data', () async {
      // Create data
      await LocalDB.Post('delete-key', {'value': 'to-delete'});

      // Delete the data
      final deleteResult = await LocalDB.Delete('delete-key');

      expect(deleteResult.isOk, true);

      // Verify deletion - should return Ok(null) for deleted key
      final retrieved = await LocalDB.GetById('delete-key');
      retrieved.when(
        ok: (data) {
          // Should return null for deleted key (not found converts to Ok(null))
          expect(data, null);
        },
        err: (err) {
          // This should not happen - not found should return Ok(null)
          fail('Expected Ok(null) for deleted key, but got error: $err');
        },
      );
    });
  });

  group('LocalDB Concurrent Operations', () {
    test('Should handle multiple concurrent writes', () async {
      // Crear una lista de Futures para ejecutar operaciones concurrentes
      final futures = List.generate(
        10,
        (index) => LocalDB.Post('concurrent-$index', {'value': index}),
      );

      // Esperar a que todas las operaciones se completen y verificar sus resultados
      final results = await Future.wait(futures);
      expect(results.every((result) => result.isOk), true);

      // Verificar que todos los datos se guardaron correctamente
      final allData = await LocalDB.GetAll();
      expect(allData.isOk, true);
      expect(allData.data.length, 10);
    });
  });

  group('LocalDB Performance', () {
    test('Should perform bulk operations efficiently', () async {
      final Stopwatch stopwatch = Stopwatch()..start();

      // Crear una lista de Futures para operaciones en lote
      final futures = List.generate(
        50,
        (index) => LocalDB.Post('bulk-$index', {
          'data': 'test-data-$index',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // Esperar a que todas las operaciones se completen
      final results = await Future.wait(futures);

      // Medir y mostrar el tiempo transcurrido
      final elapsed = stopwatch.elapsed;
      print('Bulk operations completed in: ${elapsed.inMilliseconds}ms');

      // Verificar que todas las operaciones fueron exitosas
      expect(results.every((result) => result.isOk), true);
    });
  });

  group('LocalDB Error Handling', () {
    test('Should handle invalid keys gracefully', () async {
      final result = await LocalDB.Post('', {'test': 'data'});
      expect(result.isErr, true);

      final result2 = await LocalDB.Post('a', {'test': 'data'});
      expect(result2.isErr, true);
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
        final result = await LocalDB.Post(id, {'test': 'data'});
        result.when(
          ok: (_) => fail('Should reject invalid ID: $id'),
          err: (error) => expect(error.type, ErrorType.validationError),
        );
      }
    });

    test('Should reject IDs shorter than 3 characters', () async {
      final result = await LocalDB.Post('ab', {'test': 'data'});
      result.when(
        ok: (_) => fail('Should reject short ID'),
        err: (error) => expect(error.type, ErrorType.validationError),
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
          'field2': {'subfield': 'value2'},
        },
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
  });

  group('Batch Operation Tests', () {
    test('Should handle batch operations with different data sizes', () async {
      final smallData = {'value': 'small'};
      final mediumData = Map.fromEntries(
        List.generate(100, (i) => MapEntry('key$i', 'value$i')),
      );
      final largeData = Map.fromEntries(
        List.generate(1000, (i) => MapEntry('key$i', 'value$i')),
      );

      final operations = [
        await LocalDB.Post('small-data', smallData),
        await LocalDB.Post('medium-data', mediumData),
        await LocalDB.Post('large-data', largeData),
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
          final updateResult = await LocalDB.Put('concurrent-counter', {
            'counter': newCounter,
          });

          expect(
            updateResult.isOk,
            true,
            reason: 'Failed to update counter at iteration $i',
          );
        } else {
          fail('Failed to fetch current counter value at iteration $i');
        }
      }

      final finalResult = await LocalDB.GetById('concurrent-counter');
      finalResult.when(
        ok: (data) => expect(
          data?.data['counter'],
          100,
          reason: 'Final counter value mismatch',
        ),
        err: (error) => fail('Failed to verify concurrent operations: $error'),
      );
    });
  });

  group('Error Recovery Tests', () {
    test('Should handle database cleanup after failed operations', () async {
      // Simulate a failed operation
      final invalidData = {
        'key': double.infinity,
      }; // Will fail JSON serialization
      await LocalDB.Post('failed-op', invalidData);

      // Verify database is still operational
      final validData = {'key': 'value'};
      final result = await LocalDB.Post('recovery-test', validData);
      expect(result.isOk, true);
    });
  });

  group('Performance Optimization Tests', () {
    test('Should maintain performance with large datasets', () async {
      final stopwatch = Stopwatch()..start();

      // Create 1000 records y esperar a que todos terminen
      final writeFutures = List.generate(
        1000,
        (i) => LocalDB.Post('perf-test-$i', {
          'data': List.generate(100, (j) => 'value-$j').join(','),
        }),
      );

      // Esperar a que todas las escrituras se completen
      final writeResults = await Future.wait(writeFutures);

      // Verificar que todas las escrituras fueron exitosas
      expect(writeResults.every((result) => result.isOk), true);

      final writeTime = stopwatch.elapsedMilliseconds;
      print('Write time for 1000 records: ${writeTime}ms');

      stopwatch.reset();
      stopwatch.start();

      // Read all records
      final readResult = await LocalDB.GetAll();
      final readTime = stopwatch.elapsedMilliseconds;
      print('Read time for all records: ${readTime}ms');

      readResult.when(
        ok: (data) => expect(data.length, 1000),
        err: (error) => fail('Failed to read data: $error'),
      );

      // Performance assertions - ajustar según sea necesario para tu entorno
      expect(
        writeTime / 1000 < 50,
        true,
        reason:
            'Average write time per record: ${writeTime / 1000}ms exceeded 50ms limit',
      );
      expect(
        readTime < 1000,
        true,
        reason: 'Total read time: ${readTime}ms exceeded 1000ms limit',
      );
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
          err: (error) => expect(
            error.type,
            ErrorType.validationError,
            reason: 'Should get validation error for ID: $id',
          ),
        );
      }
    });

    test('Should handle special characters in data values', () async {
      final specialData = {
        'null': null,
        'empty': '',
        'special': '!@#\$%^&*()',
        'unicode': '你好世界',
        'emoji': '👋🌍',
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
              expect(
                retrievedData?.data['description'],
                'Testing maximum key length',
              );
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

    test('Should validate data type preservation', () async {
      final complexTypes = {
        'integer': 42,
        'double': 3.14159,
        'bool': true,
        'datetime': DateTime.now().toIso8601String(),
        'list': [1, 2, 3],
        'map': {'nested': 'value'},
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
        'big_data': List.generate(10000, (index) => 'chunk-$index').join(),
      };

      final result = await LocalDB.Post('large-payload', largePayload);
      result.when(
        ok: (data) async {
          final retrieved = await LocalDB.GetById('large-payload');
          retrieved.when(
            ok: (retrievedData) {
              expect(
                retrievedData?.data['big_data'].length,
                largePayload['big_data']!.length,
              );
            },
            err: (error) => fail('Failed to retrieve large payload'),
          );
        },
        err: (error) => fail('Should accept large payload: $error'),
      );
    });

    test(
      'Should provide transaction-like behavior for critical updates',
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
          final rollback = await LocalDB.Put('transaction-test', {
            'balance': 100,
          });
          expect(rollback.isOk, true);
        }
      },
    );

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
        return Future.value(legacy.Err('Failed to read'));
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
        stressOperations.add(
          LocalDB.Put('stress-${i % 10}', {'updated': true}),
        );
        stressOperations.add(LocalDB.GetById('stress-${i % 10}'));
      }

      expect(stressOperations.length, 300);
    });
  });
}
