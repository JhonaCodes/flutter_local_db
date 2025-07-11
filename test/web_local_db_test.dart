@TestOn('browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/flutter_local_db.dart';

void main() {
  group('Web LocalDB Tests (IndexedDB)', () {
    setUp(() async {
      // Clear any existing data before each test
      await LocalDB.init(localDbName: 'test_web_db');
      await LocalDB.ClearData();
    });

    test('Should initialize database on web platform', () async {
      // This test verifies that IndexedDB initialization works
      await LocalDB.init(localDbName: 'web_init_test');
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
    });

    test('Should create and retrieve data on web', () async {
      final testData = {'name': 'Web Test', 'value': 42, 'isWeb': true};

      // Create data
      final createResult = await LocalDB.Post('web-test-key', testData);
      expect(createResult.isOk, true);

      // Retrieve data
      final retrieveResult = await LocalDB.GetById('web-test-key');
      expect(retrieveResult.isOk, true);
      expect(retrieveResult.data?.data['name'], 'Web Test');
      expect(retrieveResult.data?.data['value'], 42);
      expect(retrieveResult.data?.data['isWeb'], true);
    });

    test('Should update existing data on web', () async {
      // Create initial data
      await LocalDB.Post('update-web-key', {'value': 'initial'});

      // Update data
      final updateResult = await LocalDB.Put('update-web-key', {'value': 'updated', 'platform': 'web'});
      expect(updateResult.isOk, true);

      // Verify update
      final retrieveResult = await LocalDB.GetById('update-web-key');
      expect(retrieveResult.isOk, true);
      expect(retrieveResult.data?.data['value'], 'updated');
      expect(retrieveResult.data?.data['platform'], 'web');
    });

    test('Should delete data on web', () async {
      // Create data
      await LocalDB.Post('delete-web-key', {'value': 'to-delete'});

      // Delete data
      final deleteResult = await LocalDB.Delete('delete-web-key');
      expect(deleteResult.isOk, true);

      // Verify deletion
      final retrieveResult = await LocalDB.GetById('delete-web-key');
      expect(retrieveResult.isOk, true);
      expect(retrieveResult.data, null);
    });

    test('Should handle GetAll operation on web', () async {
      // Create multiple records
      final testRecords = [
        {'key': 'web-record-1', 'data': {'type': 'web', 'value': 1}},
        {'key': 'web-record-2', 'data': {'type': 'web', 'value': 2}},
        {'key': 'web-record-3', 'data': {'type': 'web', 'value': 3}},
      ];

      for (final record in testRecords) {
        await LocalDB.Post(record['key'] as String, record['data'] as Map<String, dynamic>);
      }

      // Retrieve all records
      final getAllResult = await LocalDB.GetAll();
      expect(getAllResult.isOk, true);
      expect(getAllResult.data.length, 3);

      // Verify all records are present
      final retrievedKeys = getAllResult.data.map((record) => record.id).toSet();
      expect(retrievedKeys.contains('web-record-1'), true);
      expect(retrievedKeys.contains('web-record-2'), true);
      expect(retrievedKeys.contains('web-record-3'), true);
    });

    test('Should clear all data on web', () async {
      // Create test data
      await LocalDB.Post('clear-test-1', {'value': 'test1'});
      await LocalDB.Post('clear-test-2', {'value': 'test2'});

      // Clear all data
      final clearResult = await LocalDB.ClearData();
      expect(clearResult.isOk, true);

      // Verify data is cleared
      final getAllResult = await LocalDB.GetAll();
      expect(getAllResult.isOk, true);
      expect(getAllResult.data.length, 0);
    });

    test('Should handle complex JSON data on web', () async {
      final complexData = {
        'string': 'test value',
        'number': 123.45,
        'boolean': true,
        'array': [1, 2, 3, 'four'],
        'nested': {
          'inner': {'deep': 'value'},
          'list': [
            {'item': 1},
            {'item': 2}
          ]
        },
        'nullValue': null,
      };

      // Create complex data
      final createResult = await LocalDB.Post('complex-web-data', complexData);
      expect(createResult.isOk, true);

      // Retrieve and verify complex data
      final retrieveResult = await LocalDB.GetById('complex-web-data');
      expect(retrieveResult.isOk, true);
      
      final retrievedData = retrieveResult.data!.data;
      expect(retrievedData['string'], 'test value');
      expect(retrievedData['number'], 123.45);
      expect(retrievedData['boolean'], true);
      expect(retrievedData['array'], [1, 2, 3, 'four']);
      expect(retrievedData['nested']['inner']['deep'], 'value');
      expect(retrievedData['nullValue'], null);
    });

    test('Should handle database close and reconnection on web', () async {
      // Create initial data
      await LocalDB.Post('close-test', {'before': 'close'});

      // Close database
      await LocalDB.CloseDatabase();

      // Try to access data (should trigger reconnection)
      final result = await LocalDB.GetById('close-test');
      expect(result.isOk, true);
      expect(result.data?.data['before'], 'close');

      // Verify connection is valid after reconnection
      final isValid = await LocalDB.IsConnectionValid();
      expect(isValid, true);
    });

    test('Should prevent duplicate ID creation on web', () async {
      // Create initial record
      final createResult1 = await LocalDB.Post('duplicate-test', {'value': 'first'});
      expect(createResult1.isOk, true);

      // Try to create with same ID
      final createResult2 = await LocalDB.Post('duplicate-test', {'value': 'second'});
      expect(createResult2.isErr, true);
      
      // Verify original data is unchanged
      final retrieveResult = await LocalDB.GetById('duplicate-test');
      expect(retrieveResult.isOk, true);
      expect(retrieveResult.data?.data['value'], 'first');
    });

    test('Should handle concurrent operations on web', () async {
      // Create multiple concurrent operations
      final futures = List.generate(10, (index) =>
          LocalDB.Post('concurrent-web-$index', {'value': index, 'platform': 'web'})
      );

      final results = await Future.wait(futures);
      expect(results.every((result) => result.isOk), true);

      // Verify all data was stored
      final getAllResult = await LocalDB.GetAll();
      expect(getAllResult.isOk, true);
      expect(getAllResult.data.length, 10);
    });
  });
}