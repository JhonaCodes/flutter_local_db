import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for LocalDB components that don't require FFI.
///
/// For full integration tests that test the actual database operations,
/// use the integration tests in the integration_test directory:
///
/// ```bash
/// # Run on macOS
/// flutter test integration_test/local_db_test.dart -d macos
///
/// # Run on iOS simulator
/// flutter test integration_test/local_db_test.dart -d <ios-simulator-id>
///
/// # Run on Android emulator
/// flutter test integration_test/local_db_test.dart -d <android-emulator-id>
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDbModel Unit Tests', () {
    test('should create model with required fields', () {
      final model = LocalDbModel(
        id: 'test-id',
        data: {'name': 'Test', 'value': 123},
      );

      expect(model.id, equals('test-id'));
      expect(model.data['name'], equals('Test'));
      expect(model.data['value'], equals(123));
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
      expect(model.contentHash, isNotNull);
    });

    test('should serialize to JSON and back', () {
      final original = LocalDbModel(
        id: 'json-test',
        data: {'key': 'value', 'number': 42},
      );

      final json = original.toJson();
      final restored = LocalDbModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.data['key'], equals(original.data['key']));
      expect(restored.data['number'], equals(original.data['number']));
    });

    test('should serialize to Map and back', () {
      final original = LocalDbModel(
        id: 'map-test',
        data: {'nested': {'deep': 'value'}},
      );

      final map = original.toMap();
      final restored = LocalDbModel.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.data['nested']['deep'], equals('value'));
    });

    test('should create copy with updated data', () {
      final original = LocalDbModel(
        id: 'copy-test',
        data: {'original': true},
      );

      final updated = original.copyWith(data: {'updated': true});

      expect(updated.id, equals(original.id));
      expect(updated.data['updated'], isTrue);
      expect(original.data['original'], isTrue);
    });

    test('should merge data correctly', () {
      final original = LocalDbModel(
        id: 'merge-test',
        data: {'a': 1, 'b': 2},
      );

      final merged = original.mergeData({'b': 3, 'c': 4});

      expect(merged.data['a'], equals(1));
      expect(merged.data['b'], equals(3));
      expect(merged.data['c'], equals(4));
    });

    test('should get nested field safely', () {
      final model = LocalDbModel(
        id: 'field-test',
        data: {
          'user': {
            'profile': {'name': 'John'},
          },
        },
      );

      expect(model.getField<String>('user.profile.name'), equals('John'));
      expect(model.getField<String>('user.missing.path'), isNull);
      expect(model.getField<String>('nonexistent'), isNull);
    });

    test('should validate content hash', () {
      final model = LocalDbModel(
        id: 'hash-test',
        data: {'value': 'test'},
      );

      expect(model.isContentHashValid, isTrue);
    });
  });

  group('LocalDbResult Unit Tests', () {
    test('Ok should contain success value', () {
      final result = Ok<String, String>('success');

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.okOrNull, equals('success'));
      expect(result.errOrNull, isNull);
    });

    test('Err should contain error value', () {
      final result = Err<String, String>('error');

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.okOrNull, isNull);
      expect(result.errOrNull, equals('error'));
    });

    test('when should call correct callback', () {
      var okCalled = false;
      var errCalled = false;

      final okResult = Ok<int, String>(42);
      okResult.when(
        ok: (value) {
          okCalled = true;
          expect(value, equals(42));
        },
        err: (_) => errCalled = true,
      );

      expect(okCalled, isTrue);
      expect(errCalled, isFalse);

      okCalled = false;
      errCalled = false;

      final errResult = Err<int, String>('error');
      errResult.when(
        ok: (_) => okCalled = true,
        err: (error) {
          errCalled = true;
          expect(error, equals('error'));
        },
      );

      expect(okCalled, isFalse);
      expect(errCalled, isTrue);
    });

    test('map should transform success values', () {
      final result = Ok<int, String>(10);
      final mapped = result.map((value) => value * 2);

      expect(mapped.isOk, isTrue);
      expect(mapped.okOrNull, equals(20));
    });

    test('mapErr should transform error values', () {
      final result = Err<int, String>('error');
      final mapped = result.mapErr((error) => 'mapped: $error');

      expect(mapped.isErr, isTrue);
      expect(mapped.errOrNull, equals('mapped: error'));
    });
  });

  group('ErrorLocalDb Unit Tests', () {
    test('should create database error', () {
      final error = ErrorLocalDb.databaseError('Test error', context: 'test');

      expect(error.type, equals(LocalDbErrorType.database));
      expect(error.message, equals('Test error'));
      expect(error.context, equals('test'));
    });

    test('should create not found error', () {
      final error = ErrorLocalDb.notFound('Not found', context: 'key123');

      expect(error.type, equals(LocalDbErrorType.notFound));
      expect(error.message, equals('Not found'));
    });

    test('should create validation error', () {
      final error = ErrorLocalDb.validationError('Invalid input');

      expect(error.type, equals(LocalDbErrorType.validation));
      expect(error.message, equals('Invalid input'));
    });

    test('should format to string correctly', () {
      final error = ErrorLocalDb.databaseError('Test', context: 'ctx');
      final str = error.toString();

      expect(str, contains('database'));
      expect(str, contains('Test'));
    });
  });
}
