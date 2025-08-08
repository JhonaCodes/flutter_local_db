import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/database_factory.dart';
import 'package:flutter_local_db/src/core/database.dart';
import 'package:flutter_local_db/src/core/models.dart';

void main() {
  group('Native Only Tests (No Web Dependencies)', () {
    test('should create database factory without web imports', () {
      final database = DatabaseFactory.create();
      expect(database, isA<Database>());
    });

    test('should validate database config', () {
      final config = DbConfig(name: 'test_db');
      final result = DatabaseFactory.validateConfig(config);

      result.when(
        ok: (_) => expect(true, isTrue), // Success case
        err: (error) => fail('Config validation should pass: ${error.message}'),
      );
    });

    test('should get platform info', () {
      final info = DatabaseFactory.getPlatformInfo();
      expect(info.platform, isNotNull);
      expect(info.implementation, isNotNull);
      expect(info.backend, isNotNull);

      // Should be native when running on VM
      expect(info.implementation, contains('Native'));
    });

    test('should create DbConfig with defaults', () {
      final config = DbConfig(name: 'test');
      expect(config.name, equals('test'));
      expect(config.maxRecordsPerFile, equals(1000));
      expect(config.backupEveryDays, equals(7));
    });

    test('should create DbEntry model', () {
      final entry = DbEntry(
        id: 'test-id',
        data: {'key': 'value'},
        hash: '123456',
      );

      expect(entry.id, equals('test-id'));
      expect(entry.data['key'], equals('value'));
      expect(entry.hash, equals('123456'));
    });

    test('should validate database names', () {
      expect(DatabaseValidator.isValidDatabaseName('valid_db_name'), isTrue);
      expect(DatabaseValidator.isValidDatabaseName('valid-db-name'), isTrue);
      expect(DatabaseValidator.isValidDatabaseName('validDbName123'), isTrue);

      expect(DatabaseValidator.isValidDatabaseName(''), isFalse);
      expect(DatabaseValidator.isValidDatabaseName('invalid@name'), isFalse);
      expect(DatabaseValidator.isValidDatabaseName('invalid name'), isFalse);
    });

    test('should validate keys', () {
      expect(DatabaseValidator.isValidKey('valid_key'), isTrue);
      expect(DatabaseValidator.isValidKey('valid-key'), isTrue);
      expect(DatabaseValidator.isValidKey('validKey123'), isTrue);
      expect(DatabaseValidator.isValidKey('123validKey'), isTrue);

      expect(DatabaseValidator.isValidKey(''), isFalse);
      expect(DatabaseValidator.isValidKey('ab'), isFalse); // Too short
      expect(DatabaseValidator.isValidKey('invalid@key'), isFalse);
      expect(DatabaseValidator.isValidKey('invalid key'), isFalse);
    });

    test('should validate data', () {
      expect(DatabaseValidator.isValidData({'key': 'value'}), isTrue);
      expect(DatabaseValidator.isValidData({'number': 123}), isTrue);
      expect(DatabaseValidator.isValidData({'bool': true}), isTrue);
      expect(
        DatabaseValidator.isValidData({
          'list': [1, 2, 3],
        }),
        isTrue,
      );
      expect(
        DatabaseValidator.isValidData({
          'nested': {'key': 'value'},
        }),
        isTrue,
      );

      expect(DatabaseValidator.isValidData({}), isFalse); // Empty
    });

    test('should get key validation error messages', () {
      expect(
        DatabaseValidator.getKeyValidationError(''),
        contains('at least 3 characters'),
      );
      expect(
        DatabaseValidator.getKeyValidationError('ab'),
        contains('at least 3 characters'),
      );
      expect(
        DatabaseValidator.getKeyValidationError('invalid@key'),
        contains('alphanumeric'),
      );
    });
  });
}
