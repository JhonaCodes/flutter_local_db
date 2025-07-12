import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/service/local_db_result.dart';

void main() {
  group('LocalDbResult System Tests - 100% Pure Dart', () {
    group('Ok Construction and Basic Properties', () {
      test('Should create Ok result with data', () {
        final result = Ok<String, Exception>('success');

        expect(result.isOk, true);
        expect(result.isErr, false);
        expect(result.data, 'success');
        expect(result.errorOrNull, null);
      });

      test('Should create Ok with different data types', () {
        final stringResult = Ok<String, String>('test');
        final intResult = Ok<int, String>(42);
        final listResult = Ok<List<int>, String>([1, 2, 3]);
        final mapResult = Ok<Map<String, dynamic>, String>({'key': 'value'});

        expect(stringResult.data, 'test');
        expect(intResult.data, 42);
        expect(listResult.data, [1, 2, 3]);
        expect(mapResult.data, {'key': 'value'});
      });
    });

    group('Err Construction and Basic Properties', () {
      test('Should create Err result with error', () {
        final result = Err<String, Exception>(Exception('failed'));

        expect(result.isOk, false);
        expect(result.isErr, true);
        expect(result.errorOrNull, isA<Exception>());
        expect(() => result.data, throwsStateError);
      });

      test('Should create Err with different error types', () {
        final stringErr = Err<String, String>('error message');
        final exceptionErr = Err<String, Exception>(Exception('exception'));
        final intErr = Err<String, int>(404);

        expect(stringErr.errorOrNull, 'error message');
        expect(exceptionErr.errorOrNull, isA<Exception>());
        expect(intErr.errorOrNull, 404);
      });
    });

    group('Pattern Matching with when()', () {
      test('Should pattern match Ok results', () {
        final result = Ok<String, Exception>('success');

        final output = result.when(
          ok: (data) => 'Got: $data',
          err: (error) => 'Error: $error',
        );

        expect(output, 'Got: success');
      });

      test('Should pattern match Err results', () {
        final result = Err<String, String>('failure');

        final output = result.when(
          ok: (data) => 'Got: $data',
          err: (error) => 'Error: $error',
        );

        expect(output, 'Error: failure');
      });

      test('Should handle complex pattern matching', () {
        final results = [
          Ok<int, String>(10),
          Err<int, String>('invalid'),
          Ok<int, String>(20),
        ];

        final sum = results.fold<int>(0, (acc, result) {
          return result.when(ok: (value) => acc + value, err: (_) => acc);
        });

        expect(sum, 30);
      });
    });

    group('Map Transformations', () {
      test('Should map Ok values', () {
        final result = Ok<int, String>(5);
        final mapped = result.map((value) => value * 2);

        expect(mapped.isOk, true);
        expect(mapped.data, 10);
      });

      test('Should not transform Err values with map', () {
        final result = Err<int, String>('error');
        final mapped = result.map((value) => value * 2);

        expect(mapped.isErr, true);
        expect(mapped.errorOrNull, 'error');
      });

      test('Should chain multiple map operations', () {
        final result = Ok<int, String>(
          5,
        ).map((x) => x * 2).map((x) => x + 1).map((x) => x.toString());

        expect(result.isOk, true);
        expect(result.data, '11');
      });

      test('Should preserve error through map chain', () {
        final result = Err<int, String>(
          'original error',
        ).map((x) => x * 2).map((x) => x + 1).map((x) => x.toString());

        expect(result.isErr, true);
        expect(result.errorOrNull, 'original error');
      });
    });

    group('FlatMap Operations', () {
      test('Should flatMap Ok values successfully', () {
        final result = Ok<int, String>(5);
        final flatMapped = result.flatMap(
          (value) => value > 0
              ? Ok<String, String>('positive')
              : Err<String, String>('negative'),
        );

        expect(flatMapped.isOk, true);
        expect(flatMapped.data, 'positive');
      });

      test('Should flatMap to error when condition fails', () {
        final result = Ok<int, String>(-5);
        final flatMapped = result.flatMap(
          (value) => value > 0
              ? Ok<String, String>('positive')
              : Err<String, String>('negative'),
        );

        expect(flatMapped.isErr, true);
        expect(flatMapped.errorOrNull, 'negative');
      });

      test('Should not execute flatMap on Err', () {
        final result = Err<int, String>('original error');
        bool wasExecuted = false;

        final flatMapped = result.flatMap((value) {
          wasExecuted = true;
          return Ok<String, String>('should not reach');
        });

        expect(wasExecuted, false);
        expect(flatMapped.isErr, true);
        expect(flatMapped.errorOrNull, 'original error');
      });

      test('Should chain flatMap operations', () {
        final result = Ok<int, String>(10)
            .flatMap(
              (x) => x > 5
                  ? Ok<int, String>(x * 2)
                  : Err<int, String>('too small'),
            )
            .flatMap(
              (x) => x < 30
                  ? Ok<String, String>('valid: $x')
                  : Err<String, String>('too large'),
            );

        expect(result.isOk, true);
        expect(result.data, 'valid: 20');
      });
    });

    group('Extension Methods', () {
      test('Should mapError on Err results', () {
        final result = Err<String, int>(404);
        final mapped = result.mapError((code) => 'HTTP Error: $code');

        expect(mapped.isErr, true);
        expect(mapped.errorOrNull, 'HTTP Error: 404');
      });

      test('Should not mapError on Ok results', () {
        final result = Ok<String, int>('success');
        final mapped = result.mapError((code) => 'HTTP Error: $code');

        expect(mapped.isOk, true);
        expect(mapped.data, 'success');
      });

      test('Should recover from errors', () {
        final result = Err<String, String>('network error');
        final recovered = result.recover(
          (error) => error.contains('network')
              ? Ok<String, String>('offline mode')
              : Err<String, String>(error),
        );

        expect(recovered.isOk, true);
        expect(recovered.data, 'offline mode');
      });

      test('Should not recover from Ok results', () {
        final result = Ok<String, String>('success');
        final recovered = result.recover(
          (error) => Ok<String, String>('should not reach'),
        );

        expect(recovered.isOk, true);
        expect(recovered.data, 'success');
      });

      test('Should getOrElse with function', () {
        final okResult = Ok<String, int>('success');
        final errResult = Err<String, int>(404);

        expect(okResult.getOrElse((code) => 'Error $code'), 'success');
        expect(errResult.getOrElse((code) => 'Error $code'), 'Error 404');
      });

      test('Should getOrDefault with value', () {
        final okResult = Ok<String, String>('success');
        final errResult = Err<String, String>('error');

        expect(okResult.getOrDefault('default'), 'success');
        expect(errResult.getOrDefault('default'), 'default');
      });
    });

    group('Equality and Hashing', () {
      test('Should compare Ok results correctly', () {
        final result1 = Ok<String, int>('test');
        final result2 = Ok<String, int>('test');
        final result3 = Ok<String, int>('different');

        expect(result1, equals(result2));
        expect(result1, isNot(equals(result3)));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('Should compare Err results correctly', () {
        final result1 = Err<String, int>(404);
        final result2 = Err<String, int>(404);
        final result3 = Err<String, int>(500);

        expect(result1, equals(result2));
        expect(result1, isNot(equals(result3)));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('Should not equal Ok and Err', () {
        final okResult = Ok<String, String>('test');
        final errResult = Err<String, String>('test');

        expect(okResult, isNot(equals(errResult)));
      });
    });

    group('toString() Representation', () {
      test('Should represent Ok results correctly', () {
        final result = Ok<String, int>('success');
        expect(result.toString(), 'Ok(success)');
      });

      test('Should represent Err results correctly', () {
        final result = Err<String, int>(404);
        expect(result.toString(), 'Err(404)');
      });

      test('Should handle complex data in toString', () {
        final listResult = Ok<List<int>, String>([1, 2, 3]);
        final mapResult = Err<String, Map<String, int>>({'code': 500});

        expect(listResult.toString(), 'Ok([1, 2, 3])');
        expect(mapResult.toString(), 'Err({code: 500})');
      });
    });

    group('Data Access Methods', () {
      test('Should access data safely with whenData', () {
        final result = Ok<String, int>('test');
        final data = result.whenData((value) => value.toUpperCase());

        expect(data, 'TEST');
      });

      test('Should throw on whenData for Err', () {
        final result = Err<String, int>(404);

        expect(
          () => result.whenData((value) => value.toUpperCase()),
          throwsStateError,
        );
      });

      test('Should handle error with whenError', () {
        final errResult = Err<String, int>(404);
        final okResult = Ok<String, int>('success');

        expect(errResult.whenError((code) => 'Error: $code'), 'Error: 404');
        expect(okResult.whenError((code) => 'Error: $code'), null);
      });
    });

    group('Edge Cases and Complex Scenarios', () {
      test('Should handle null values correctly', () {
        final okWithNull = Ok<String?, int>(null);
        final errWithNull = Err<String, int?>(null);

        expect(okWithNull.isOk, true);
        expect(okWithNull.data, null);
        expect(errWithNull.isErr, true);
        expect(errWithNull.errorOrNull, null);
      });

      test('Should handle deeply nested structures', () {
        final nestedData = {
          'user': {
            'profile': {
              'settings': {'theme': 'dark', 'notifications': true},
            },
          },
        };

        final result = Ok<Map<String, dynamic>, String>(nestedData);
        final theme = result.map(
          (data) => data['user']['profile']['settings']['theme'] as String,
        );

        expect(theme.data, 'dark');
      });

      test('Should handle Result with custom classes', () {
        final user = User('John', 25);
        final result = Ok<User, String>(user);

        final greeting = result.map((u) => 'Hello, ${u.name}!');
        expect(greeting.data, 'Hello, John!');

        final adult = result.flatMap(
          (u) =>
              u.age >= 18 ? Ok<bool, String>(true) : Err<bool, String>('Minor'),
        );
        expect(adult.data, true);
      });

      test('Should compose multiple operations safely', () {
        // Simular una cadena de operaciones típica en una app real
        final result = validateUser('john@email.com')
            .flatMap(fetchUserData)
            .map(transformUserData)
            .recover((error) => Ok<String, String>('Guest User'));

        expect(result.isOk, true);
        expect(result.data, 'User: john@email.com (verified)');
      });

      test('Should handle error propagation in chains', () {
        final result = validateUser('invalid-email')
            .flatMap(fetchUserData)
            .map(transformUserData)
            .recover(
              (error) => error == 'Invalid email'
                  ? Ok<String, String>('Guest')
                  : Err<String, String>(error),
            );

        expect(result.isOk, true);
        expect(result.data, 'Guest');
      });
    });
  });

  group('Future Result Extensions Tests', () {
    test('Should map Future Result values', () async {
      final futureResult = Future.value(Ok<int, String>(5));
      final mapped = await futureResult.map((value) => value * 2);

      expect(mapped.isOk, true);
      expect(mapped.data, 10);
    });

    test('Should flatMap Future Result values', () async {
      final futureResult = Future.value(Ok<int, String>(5));
      final flatMapped = await futureResult.flatMap(
        (value) async => Future.value(Ok<String, String>('Value: $value')),
      );

      expect(flatMapped.isOk, true);
      expect(flatMapped.data, 'Value: 5');
    });

    test('Should preserve errors in Future chains', () async {
      final futureResult = Future.value(Err<int, String>('error'));
      final mapped = await futureResult.map((value) => value * 2);

      expect(mapped.isErr, true);
      expect(mapped.errorOrNull, 'error');
    });
  });
}

// Helper classes and functions for testing
class User {
  final String name;
  final int age;

  User(this.name, this.age);

  @override
  String toString() => 'User($name, $age)';
}

LocalDbResult<String, String> validateUser(String email) {
  if (email.contains('@') && email.contains('.')) {
    return Ok(email);
  }
  return Err('Invalid email');
}

LocalDbResult<String, String> fetchUserData(String email) {
  // Simular fetch de datos del usuario
  if (email == 'john@email.com') {
    return Ok(email);
  }
  return Err('User not found');
}

String transformUserData(String email) {
  return 'User: $email (verified)';
}
