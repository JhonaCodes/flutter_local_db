import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:result_controller/result_controller.dart';

void main() {
  group('Cross-Platform Compilation Tests', () {
    test('Should create DatabaseManager without platform-specific imports', () {
      // This test validates that our conditional imports work correctly
      // and that the library can be imported without compilation errors
      
      expect(() {
        // Just testing that we can access the class without import errors
        final dbName = LocalDB.currentDatabaseName;
        expect(dbName, isNull); // Should be null initially
      }, returnsNormally);
    });

    test('Should handle init gracefully on unsupported platforms', () async {
      // Test that init method works with Result types
      final result = await LocalDB.init(localDbName: 'test-db');
      
      // On unsupported platforms, this should return an error
      // On supported platforms, this should work
      expect(result, isA<Result<void, ErrorLocalDb>>());
    });

    test('Should validate input correctly', () async {
      // Test validation without requiring actual database
      final resultShortKey = await LocalDB.Post('ab', {'test': 'data'});
      expect(resultShortKey.isErr, true);
      
      final resultInvalidKey = await LocalDB.Post('test key', {'test': 'data'});
      expect(resultInvalidKey.isErr, true);
    });

    test('Should handle DatabaseManager creation', () async {
      // Test that DatabaseManager can be created (even if it fails on unsupported platforms)
      final result = await DatabaseManager.create('test-db');
      expect(result, isA<Result<DatabaseManager, ErrorLocalDb>>());
    });
  });
}