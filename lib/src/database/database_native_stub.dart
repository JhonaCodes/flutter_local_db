import 'package:result_controller/result_controller.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'database_interface.dart';

/// Stub for DatabaseNative that provides initForTesting method signature
/// This allows the interface to compile on all platforms
class DatabaseNative implements DatabaseInterface {
  @override
  bool get isSupported => false;

  @override
  String get platformName => 'native-stub';

  /// Testing method that exists only for interface compatibility
  Future<void> initForTesting(String databaseName, String binaryPath) async {
    throw UnsupportedError('Native database testing not supported on this platform');
  }

  @override
  Future<void> initialize(String databaseName) async {
    throw UnsupportedError('Native database not supported on this platform');
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    return Err(ErrorLocalDb.databaseError('Native database not supported on this platform'));
  }

  @override
  Future<void> closeDatabase() async {
    // No-op
  }

  @override
  Future<bool> ensureConnectionValid() async {
    return false;
  }
}

/// Factory function for conditional imports
DatabaseInterface createDatabase() => DatabaseNative();