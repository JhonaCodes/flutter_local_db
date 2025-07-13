import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/platform/web/web_database.dart';
import 'package:flutter_local_db/src/core/models.dart';
import 'package:flutter_local_db/src/core/result.dart';

void main() {
  group('WebDatabase Tests', () {
    late WebDatabase database;

    setUp(() {
      database = WebDatabase();
    });

    test('Should initialize WebDatabase successfully', () async {
      final config = DbConfig(name: 'test_web_db');
      final result = await database.initialize(config);
      
      result.when(
        ok: (_) => expect(true, true),
        err: (error) => fail('Initialization should succeed: ${error.message}'),
      );
    });

    test('Should insert and retrieve data from WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      final testData = {'name': 'John', 'age': 30};
      final insertResult = await database.insert('user-123', testData);

      insertResult.when(
        ok: (entry) {
          expect(entry.id, 'user-123');
          expect(entry.data['name'], 'John');
          expect(entry.data['age'], 30);
        },
        err: (error) => fail('Insert should succeed: ${error.message}'),
      );

      final getResult = await database.get('user-123');
      getResult.when(
        ok: (entry) {
          expect(entry.id, 'user-123');
          expect(entry.data['name'], 'John');
          expect(entry.data['age'], 30);
        },
        err: (error) => fail('Get should succeed: ${error.message}'),
      );
    });

    test('Should prevent duplicate keys in WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      final testData = {'test': 'data'};
      await database.insert('duplicate-key', testData);

      final duplicateResult = await database.insert('duplicate-key', testData);
      duplicateResult.when(
        ok: (_) => fail('Should not allow duplicate keys'),
        err: (error) => expect(error.message.contains('already exists'), true),
      );
    });

    test('Should update existing data in WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      final originalData = {'value': 'original'};
      await database.insert('update-key', originalData);

      final updatedData = {'value': 'updated'};
      final updateResult = await database.update('update-key', updatedData);

      updateResult.when(
        ok: (entry) {
          expect(entry.data['value'], 'updated');
        },
        err: (error) => fail('Update should succeed: ${error.message}'),
      );
    });

    test('Should delete data from WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      await database.insert('delete-key', {'test': 'data'});
      
      final deleteResult = await database.delete('delete-key');
      deleteResult.when(
        ok: (_) => expect(true, true),
        err: (error) => fail('Delete should succeed: ${error.message}'),
      );

      final getResult = await database.get('delete-key');
      getResult.when(
        ok: (_) => fail('Should not find deleted data'),
        err: (error) => expect(error.type, DbErrorType.notFound),
      );
    });

    test('Should clear all data from WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      // Insert multiple records
      await database.insert('key1', {'data': '1'});
      await database.insert('key2', {'data': '2'});
      await database.insert('key3', {'data': '3'});

      final clearResult = await database.clear();
      clearResult.when(
        ok: (_) => expect(true, true),
        err: (error) => fail('Clear should succeed: ${error.message}'),
      );

      final getAllResult = await database.getAll();
      getAllResult.when(
        ok: (entries) => expect(entries.length, 0),
        err: (error) => fail('GetAll should succeed after clear: ${error.message}'),
      );
    });

    test('Should get all data from WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      await database.insert('key1', {'value': 1});
      await database.insert('key2', {'value': 2});
      await database.insert('key3', {'value': 3});

      final getAllResult = await database.getAll();
      getAllResult.when(
        ok: (entries) {
          expect(entries.length, 3);
          final ids = entries.map((e) => e.id).toSet();
          expect(ids.contains('key1'), true);
          expect(ids.contains('key2'), true);
          expect(ids.contains('key3'), true);
        },
        err: (error) => fail('GetAll should succeed: ${error.message}'),
      );
    });

    test('Should get all keys from WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      await database.insert('key1', {'value': 1});
      await database.insert('key2', {'value': 2});

      final getAllKeysResult = await database.getAllKeys();
      getAllKeysResult.when(
        ok: (keys) {
          expect(keys.length, 2);
          expect(keys.contains('key1'), true);
          expect(keys.contains('key2'), true);
        },
        err: (error) => fail('GetAllKeys should succeed: ${error.message}'),
      );
    });

    test('Should validate connection in WebDatabase', () async {
      expect(await database.isConnectionValid(), false);

      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);
      
      expect(await database.isConnectionValid(), true);
    });

    test('Should handle invalid keys in WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

      final invalidKeys = ['', 'a', 'ab', 'test@key', 'test space'];
      
      for (final key in invalidKeys) {
        final result = await database.insert(key, {'test': 'data'});
        result.when(
          ok: (_) => fail('Should reject invalid key: $key'),
          err: (error) => expect(error.type, DbErrorType.validation),
        );
      }
    });

    test('Should close WebDatabase properly', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);
      
      await database.insert('test-key', {'test': 'data'});
      await database.close();
      
      expect(await database.isConnectionValid(), false);
    });

    test('Should handle complex data structures in WebDatabase', () async {
      final config = DbConfig(name: 'test_web_db');
      await database.initialize(config);

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

      final insertResult = await database.insert('complex-data', complexData);
      insertResult.when(
        ok: (entry) {
          expect(entry.data['nested']['field2']['subfield'], 'value2');
          expect(entry.data['array'], [1, 2, 3]);
        },
        err: (error) => fail('Should handle complex data: ${error.message}'),
      );
    });
  });
}