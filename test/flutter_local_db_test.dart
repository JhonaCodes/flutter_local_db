import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:test/test.dart';

void main() {
  group('LocalDB Tests', () {
    setUp(() async {
      // Initialize database for each test
      await LocalDB.init('test_db');
      await LocalDB.ClearData(); // Start with clean state
    });

    tearDown(() async {
      // Clean up after each test
      await LocalDB.ClearData();
      await LocalDB.close();
    });

    test('should initialize database successfully', () async {
      await LocalDB.init('init_test_db');
      expect(LocalDB.isInitialized, isTrue);
      await LocalDB.close();
    });

    test('should insert and retrieve data', () async {
      const testKey = 'test-key-001';
      final testData = {'name': 'Test User', 'age': 25};
      
      // Insert data
      final insertResult = await LocalDB.Post(testKey, testData);
      insertResult.when(
        ok: (insertedEntry) {
          expect(insertedEntry.id, equals(testKey));
          expect(insertedEntry.data['name'], equals('Test User'));
        },
        err: (error) => fail('Insert failed: $error'),
      );
      
      // Retrieve data
      final getResult = await LocalDB.GetById(testKey);
      getResult.when(
        ok: (retrievedEntry) {
          expect(retrievedEntry, isNotNull);
          expect(retrievedEntry!.id, equals(testKey));
          expect(retrievedEntry.data['name'], equals('Test User'));
        },
        err: (error) => fail('Get failed: $error'),
      );
    });

    test('should update existing data', () async {
      const testKey = 'update-test-key';
      final originalData = {'status': 'pending', 'count': 1};
      final updatedData = {'status': 'completed', 'count': 5};
      
      // Insert original data
      await LocalDB.Post(testKey, originalData);
      
      // Update data
      final updateResult = await LocalDB.Put(testKey, updatedData);
      updateResult.when(
        ok: (entry) => expect(entry.data['status'], equals('completed')),
        err: (error) => fail('Update failed: $error'),
      );
      
      // Verify update
      final getResult = await LocalDB.GetById(testKey);
      getResult.when(
        ok: (entry) {
          expect(entry, isNotNull);
          expect(entry!.data['status'], equals('completed'));
          expect(entry.data['count'], equals(5));
        },
        err: (error) => fail('Get failed: $error'),
      );
    });

    test('should delete data', () async {
      const testKey = 'delete-test-key';
      final testData = {'temp': 'data'};
      
      // Insert data
      await LocalDB.Post(testKey, testData);
      
      // Verify it exists
      final beforeDelete = await LocalDB.GetById(testKey);
      beforeDelete.when(
        ok: (entry) => expect(entry, isNotNull),
        err: (error) => fail('Get before delete failed: $error'),
      );
      
      // Delete data
      final deleteResult = await LocalDB.Delete(testKey);
      deleteResult.when(
        ok: (success) => expect(success, isTrue),
        err: (error) => fail('Delete failed: $error'),
      );
      
      // Verify it's gone
      final afterDelete = await LocalDB.GetById(testKey);
      afterDelete.when(
        ok: (entry) => expect(entry, isNull),
        err: (error) => fail('Get after delete failed: $error'),
      );
    });

    test('should get all entries', () async {
      final testEntries = {
        'key-1': {'type': 'user', 'name': 'Alice'},
        'key-2': {'type': 'user', 'name': 'Bob'},
        'key-3': {'type': 'admin', 'name': 'Carol'},
      };
      
      // Insert multiple entries
      for (final entry in testEntries.entries) {
        await LocalDB.Post(entry.key, entry.value);
      }
      
      // Get all entries
      final getAllResult = await LocalDB.GetAll();
      getAllResult.when(
        ok: (allEntries) {
          expect(allEntries.length, equals(3));
          
          // Verify all entries are present
          final retrievedIds = allEntries.map((e) => e.id).toSet();
          expect(retrievedIds, containsAll(['key-1', 'key-2', 'key-3']));
        },
        err: (error) => fail('GetAll failed: $error'),
      );
    });

    test('should clear all data', () async {
      // Insert some test data
      await LocalDB.Post('clear-test-1', {'data': 'test1'});
      await LocalDB.Post('clear-test-2', {'data': 'test2'});
      
      // Verify data exists
      final beforeClear = await LocalDB.GetAll();
      beforeClear.when(
        ok: (entries) => expect(entries.length, greaterThan(0)),
        err: (error) => fail('GetAll before clear failed: $error'),
      );
      
      // Clear all data
      final clearResult = await LocalDB.ClearData();
      clearResult.when(
        ok: (success) => expect(success, isTrue),
        err: (error) => fail('Clear failed: $error'),
      );
      
      // Verify database is empty
      final afterClear = await LocalDB.GetAll();
      afterClear.when(
        ok: (entries) => expect(entries.length, equals(0)),
        err: (error) => fail('GetAll after clear failed: $error'),
      );
    });

    test('should handle non-existent key', () async {
      const nonExistentKey = 'non-existent-key-12345';
      
      final getResult = await LocalDB.GetById(nonExistentKey);
      getResult.when(
        ok: (entry) => expect(entry, isNull),
        err: (error) => fail('Get non-existent failed: $error'),
      );
    });

    test('should handle invalid key validation', () async {
      var errorReceived = false;
      
      // Test short key (less than 3 characters)  
      final shortKeyResult = await LocalDB.Post('ab', {'data': 'test'});
      shortKeyResult.when(
        ok: (entry) => fail('Short key should not succeed'),
        err: (error) => errorReceived = true,
      );
      expect(errorReceived, isTrue);
      
      // Test key with invalid characters
      errorReceived = false;
      final invalidKeyResult = await LocalDB.Post('test@key!', {'data': 'test'});
      invalidKeyResult.when(
        ok: (entry) => fail('Invalid key should not succeed'),
        err: (error) => errorReceived = true,
      );
      expect(errorReceived, isTrue);
    });

    test('should handle complex nested data', () async {
      const testKey = 'complex-data-key';
      final complexData = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John Doe',
            'settings': {
              'theme': 'dark',
              'notifications': true,
            }
          }
        },
        'metadata': {
          'created': '2024-01-01',
          'tags': 'test,complex,nested' // Use string instead of array for compatibility
        }
      };
      
      // Insert complex data
      final insertResult = await LocalDB.Post(testKey, complexData);
      insertResult.when(
        ok: (entry) => expect(entry.data['user']['profile']['name'], equals('John Doe')),
        err: (error) => fail('Insert complex data failed: $error'),
      );
      
      // Retrieve and verify complex data
      final getResult = await LocalDB.GetById(testKey);
      getResult.when(
        ok: (entry) {
          expect(entry, isNotNull);
          expect(entry!.data['user']['profile']['name'], equals('John Doe'));
          expect(entry.data['metadata']['tags'], equals('test,complex,nested'));
          expect(entry.data['user']['profile']['settings']['theme'], equals('dark'));
        },
        err: (error) => fail('Get complex data failed: $error'),
      );
    });
  });
}