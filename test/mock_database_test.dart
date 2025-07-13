import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/core/result.dart';
import 'package:flutter_local_db/src/core/models.dart';
import 'package:flutter_local_db/src/database_factory.dart';

void main() {
  group('Mock Database Factory Tests', () {
    test('Should create appropriate database instance', () {
      final database = DatabaseFactory.create();
      expect(database, isNotNull);
      
      final info = DatabaseFactory.getPlatformInfo();
      expect(info.platform, isNotNull);
      expect(info.implementation, isNotNull);
      expect(info.backend, isNotNull);
    });

    test('Should validate database configuration', () {
      final validConfig = DbConfig(name: 'valid_db_name');
      final validationResult = DatabaseFactory.validateConfig(validConfig);
      
      validationResult.when(
        ok: (_) => expect(true, true),
        err: (error) => fail('Valid config should pass validation: ${error.message}'),
      );
    });

    test('Should reject invalid database names', () {
      final invalidConfigs = [
        DbConfig(name: ''),
        DbConfig(name: 'test@db'),
        DbConfig(name: 'test db'),
        DbConfig(name: 'test#db'),
      ];

      for (final config in invalidConfigs) {
        final validationResult = DatabaseFactory.validateConfig(config);
        validationResult.when(
          ok: (_) => fail('Should reject invalid config: ${config.name}'),
          err: (error) => expect(error.type, DbErrorType.validation),
        );
      }
    });

    test('Should validate configuration parameters', () {
      final invalidConfig1 = DbConfig(name: 'test', maxRecordsPerFile: -1);
      final result1 = DatabaseFactory.validateConfig(invalidConfig1);
      
      result1.when(
        ok: (_) => fail('Should reject negative maxRecordsPerFile'),
        err: (error) => expect(error.type, DbErrorType.validation),
      );

      final invalidConfig2 = DbConfig(name: 'test', backupEveryDays: -1);
      final result2 = DatabaseFactory.validateConfig(invalidConfig2);
      
      result2.when(
        ok: (_) => fail('Should reject negative backupEveryDays'),
        err: (error) => expect(error.type, DbErrorType.validation),
      );
    });

    test('Should provide platform information', () {
      final info = DatabaseFactory.getPlatformInfo();
      
      expect(info.platform, isNotEmpty);
      expect(info.implementation, isNotEmpty);
      expect(info.backend, isNotEmpty);
      
      // Platform should be either Native or Web
      final isValidPlatform = info.platform.contains('Native') || 
                             info.platform.contains('Web');
      expect(isValidPlatform, true);
    });
  });

  group('Result Pattern Tests', () {
    test('Should handle Ok results correctly', () {
      final okResult = Ok<String, String>('success');
      
      okResult.when(
        ok: (value) => expect(value, 'success'),
        err: (_) => fail('Should not call err for Ok result'),
      );
      
      expect(okResult.isOk, true);
      expect(okResult.isErr, false);
    });

    test('Should handle Err results correctly', () {
      final errResult = Err<String, String>('error');
      
      errResult.when(
        ok: (_) => fail('Should not call ok for Err result'),
        err: (error) => expect(error, 'error'),
      );
      
      expect(errResult.isOk, false);
      expect(errResult.isErr, true);
    });

    test('Should transform Ok results with map', () {
      final okResult = Ok<int, String>(42);
      final mappedResult = okResult.map((value) => value.toString());
      
      mappedResult.when(
        ok: (value) => expect(value, '42'),
        err: (_) => fail('Should not be error after map'),
      );
    });

    test('Should not transform Err results with map', () {
      final errResult = Err<int, String>('error');
      final mappedResult = errResult.map((value) => value.toString());
      
      mappedResult.when(
        ok: (_) => fail('Should remain error after map'),
        err: (error) => expect(error, 'error'),
      );
    });

    test('Should chain Ok results with flatMap', () {
      final okResult = Ok<int, String>(5);
      final chainedResult = okResult.flatMap((value) => Ok<String, String>('Value: $value'));
      
      chainedResult.when(
        ok: (value) => expect(value, 'Value: 5'),
        err: (_) => fail('Should not be error after flatMap'),
      );
    });

    test('Should handle Err in flatMap chain', () {
      final okResult = Ok<int, String>(5);
      final chainedResult = okResult.flatMap((value) => Err<String, String>('chain error'));
      
      chainedResult.when(
        ok: (_) => fail('Should be error after flatMap with Err'),
        err: (error) => expect(error, 'chain error'),
      );
    });
  });

  group('DbError Tests', () {
    test('Should create different types of DbError', () {
      final notFoundError = DbError.notFound('Record not found');
      expect(notFoundError.type, DbErrorType.notFound);
      expect(notFoundError.message, 'Record not found');

      final validationError = DbError.validationError('Invalid input');
      expect(validationError.type, DbErrorType.validation);
      expect(validationError.message, 'Invalid input');

      final connectionError = DbError.connectionError('Connection failed');
      expect(connectionError.type, DbErrorType.connection);
      expect(connectionError.message, 'Connection failed');
    });

    test('Should include stack trace and original error when provided', () {
      final originalError = Exception('Original exception');
      final stackTrace = StackTrace.current;
      
      final dbError = DbError.databaseError(
        'Database operation failed',
        originalError: originalError,
        stackTrace: stackTrace,
      );
      
      expect(dbError.originalError, originalError);
      expect(dbError.stackTrace, stackTrace);
    });
  });

  group('DbEntry Tests', () {
    test('Should create DbEntry with required fields', () {
      final entry = DbEntry(
        id: 'test-id',
        data: {'key': 'value'},
        hash: 'test-hash',
      );
      
      expect(entry.id, 'test-id');
      expect(entry.data['key'], 'value');
      expect(entry.hash, 'test-hash');
      expect(entry.sizeKb, null);
    });

    test('Should convert DbEntry to/from JSON', () {
      final originalEntry = DbEntry(
        id: 'test-id',
        data: {'key': 'value', 'number': 42},
        hash: 'test-hash',
        sizeKb: 1.5,
      );
      
      final json = originalEntry.toJson();
      final restoredEntry = DbEntry.fromJson(json);
      
      expect(restoredEntry.id, originalEntry.id);
      expect(restoredEntry.data, originalEntry.data);
      expect(restoredEntry.hash, originalEntry.hash);
      expect(restoredEntry.sizeKb, originalEntry.sizeKb);
    });

    test('Should create copy with updated fields', () {
      final originalEntry = DbEntry(
        id: 'original-id',
        data: {'key': 'original'},
        hash: 'original-hash',
      );
      
      final copiedEntry = originalEntry.copyWith(
        data: {'key': 'updated'},
        hash: 'updated-hash',
      );
      
      expect(copiedEntry.id, 'original-id'); // Should keep original
      expect(copiedEntry.data['key'], 'updated');
      expect(copiedEntry.hash, 'updated-hash');
    });

    test('Should compare DbEntry instances correctly', () {
      final entry1 = DbEntry(
        id: 'test-id',
        data: {'key': 'value'},
        hash: 'test-hash',
      );
      
      final entry2 = DbEntry(
        id: 'test-id',
        data: {'key': 'value'},
        hash: 'test-hash',
      );
      
      final entry3 = DbEntry(
        id: 'different-id',
        data: {'key': 'value'},
        hash: 'test-hash',
      );
      
      expect(entry1 == entry2, true);
      expect(entry1 == entry3, false);
      expect(entry1.hashCode == entry2.hashCode, true);
    });
  });

  group('DbConfig Tests', () {
    test('Should create DbConfig with defaults', () {
      final config = DbConfig(name: 'test_db');
      
      expect(config.name, 'test_db');
      expect(config.maxRecordsPerFile, 10000);
      expect(config.backupEveryDays, 7);
      expect(config.hashEncrypt, false);
    });

    test('Should create DbConfig with custom values', () {
      final config = DbConfig(
        name: 'custom_db',
        maxRecordsPerFile: 5000,
        backupEveryDays: 14,
        hashEncrypt: true,
      );
      
      expect(config.name, 'custom_db');
      expect(config.maxRecordsPerFile, 5000);
      expect(config.backupEveryDays, 14);
      expect(config.hashEncrypt, true);
    });

    test('Should convert DbConfig to/from JSON', () {
      final originalConfig = DbConfig(
        name: 'test_db',
        maxRecordsPerFile: 8000,
        backupEveryDays: 10,
        hashEncrypt: true,
      );
      
      final json = originalConfig.toJson();
      final restoredConfig = DbConfig.fromJson(json);
      
      expect(restoredConfig.name, originalConfig.name);
      expect(restoredConfig.maxRecordsPerFile, originalConfig.maxRecordsPerFile);
      expect(restoredConfig.backupEveryDays, originalConfig.backupEveryDays);
      expect(restoredConfig.hashEncrypt, originalConfig.hashEncrypt);
    });
  });
}