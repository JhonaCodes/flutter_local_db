import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/flutter_local_db.dart';

/// Integration tests for LocalDB that run with `flutter test`.
///
/// These tests load the native library directly and use a local test directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test output directory (add to .gitignore)
  final testDbPath = '${Directory.current.path}/.test_output/test_db.lmdb';

  group('LocalDB Integration Tests', () {
    late LocalDbService service;

    setUpAll(() async {
      // Ensure test output directory exists
      final dir = Directory('${Directory.current.path}/.test_output');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Load native library directly from project
      _loadNativeLibrary();

      // Initialize with custom path (bypasses path_provider)
      final result = await LocalDbService.initializeWithPath(testDbPath);
      result.when(
        ok: (s) => service = s,
        err: (e) => throw Exception('Failed to initialize: ${e.message}'),
      );

      // Clear any existing data
      await service.clearAll();
    });

    tearDownAll(() async {
      await service.clearAll();
      service.close();
    });

    test('should initialize database successfully', () {
      expect(service.isInitialized, isTrue);
      print('Database initialized at: $testDbPath');
    });

    test('should POST (create) data', () async {
      final result = await service.store('user-001', LocalMethod.post, {
        'name': 'Alice',
        'age': 25,
        'email': 'alice@test.com',
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (model) {
          expect(model.id, equals('user-001'));
          expect(model.data['name'], equals('Alice'));
          print('POST OK: Created ${model.id}');
        },
        err: (e) => fail('POST failed: ${e.message}'),
      );
    });

    test('should GET (read) data by ID', () async {
      final result = await service.retrieve('user-001');

      expect(result.isOk, isTrue);
      result.when(
        ok: (model) {
          expect(model.id, equals('user-001'));
          expect(model.data['name'], equals('Alice'));
          expect(model.data['age'], equals(25));
          print('GET OK: ${model.id} -> ${model.data}');
        },
        err: (e) => fail('GET failed: ${e.message}'),
      );
    });

    test('should PUT (update) data', () async {
      final result = await service.store('user-001', LocalMethod.put, {
        'name': 'Alice Updated',
        'age': 26,
        'status': 'active',
      });

      expect(result.isOk, isTrue);
      result.when(
        ok: (model) {
          expect(model.data['name'], equals('Alice Updated'));
          expect(model.data['age'], equals(26));
          print('PUT OK: Updated ${model.id}');
        },
        err: (e) => fail('PUT failed: ${e.message}'),
      );
    });

    test('should GET ALL data', () async {
      // Add more records
      await service.store('user-002', LocalMethod.post, {'name': 'Bob'});
      await service.store('user-003', LocalMethod.post, {'name': 'Carol'});

      final result = await service.listAll();

      expect(result.isOk, isTrue);
      result.when(
        ok: (entries) {
          expect(entries.length, greaterThanOrEqualTo(3));
          print('GET ALL OK: ${entries.length} records');
          for (final entry in entries.entries) {
            print('  - ${entry.key}: ${entry.value.data}');
          }
        },
        err: (e) => fail('GET ALL failed: ${e.message}'),
      );
    });

    test('should DELETE data', () async {
      final deleteResult = await service.remove('user-002');
      expect(deleteResult.isOk, isTrue);
      print('DELETE OK: Removed user-002');

      // Verify deletion
      final getResult = await service.retrieve('user-002');
      expect(getResult.isErr, isTrue);
      print('Verified: user-002 no longer exists');
    });

    test('should CLEAR ALL data', () async {
      final clearResult = await service.clearAll();
      expect(clearResult.isOk, isTrue);

      final listResult = await service.listAll();
      listResult.when(
        ok: (entries) {
          expect(entries.length, equals(0));
          print('CLEAR ALL OK: Database is empty');
        },
        err: (e) => fail('List after clear failed: ${e.message}'),
      );
    });

    test('should handle complex nested data', () async {
      final complexData = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John Doe',
            'settings': {'theme': 'dark', 'notifications': true},
          },
        },
        'metadata': {'created': DateTime.now().toIso8601String()},
      };

      final storeResult = await service.store(
        'complex-001',
        LocalMethod.post,
        complexData,
      );
      expect(storeResult.isOk, isTrue);

      final getResult = await service.retrieve('complex-001');
      getResult.when(
        ok: (model) {
          expect(model.data['user']['profile']['name'], equals('John Doe'));
          expect(
            model.data['user']['profile']['settings']['theme'],
            equals('dark'),
          );
          print('Complex data OK: Nested structure preserved');
        },
        err: (e) => fail('Complex data failed: ${e.message}'),
      );
    });
  });
}

/// Load native library from project directory
void _loadNativeLibrary() {
  final projectDir = Directory.current.path;

  // Try different library paths based on platform/architecture
  final libraryPaths = [
    '$projectDir/macos/liboffline_first_core_arm64.dylib',
    '$projectDir/macos/liboffline_first_core_x86_64.dylib',
    '$projectDir/macos/liboffline_first_core.dylib',
    '$projectDir/linux/liboffline_first_core.so',
  ];

  for (final path in libraryPaths) {
    if (File(path).existsSync()) {
      try {
        DynamicLibrary.open(path);
        print('Loaded native library: $path');
        return;
      } catch (e) {
        print('Failed to load $path: $e');
      }
    }
  }

  throw Exception(
    'Could not find native library. Tried:\n${libraryPaths.join('\n')}',
  );
}
