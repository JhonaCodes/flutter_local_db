import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import '../service/local_db_result.dart';
import 'database_interface.dart';

/// Stub implementation for unsupported platforms
/// This implementation throws appropriate errors for platforms
/// that don't have native or web database support
class DatabaseStub implements DatabaseInterface {
  DatabaseStub._();

  static final DatabaseStub instance = DatabaseStub._();

  @override
  bool get isSupported => false;

  @override
  String get platformName => 'unsupported';

  @override
  Future<void> initialize(String databaseName) async {
    throw UnsupportedError('Database is not supported on this platform');
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    return Err(ErrorLocalDb.databaseError('Database is not supported on this platform'));
  }

  @override
  Future<void> closeDatabase() async {
    // No-op for unsupported platforms
  }

  @override
  Future<bool> ensureConnectionValid() async {
    return false;
  }
}