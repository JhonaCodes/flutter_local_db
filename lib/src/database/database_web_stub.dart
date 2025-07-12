import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import '../service/local_db_result.dart';
import 'database_interface.dart';

/// Stub implementation for non-web platforms
/// This prevents web code from being compiled on mobile/desktop
class DatabaseWeb implements DatabaseInterface {
  DatabaseWeb._();

  static final DatabaseWeb instance = DatabaseWeb._();

  @override
  bool get isSupported => false;

  @override
  String get platformName => 'web-stub';

  @override
  Future<void> initialize(String databaseName) async {
    throw UnsupportedError('Web database is not supported on this platform');
  }

  @override
  Future<bool> ensureConnectionValid() async => false;

  @override
  Future<void> closeDatabase() async {}

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(
    LocalDbModel model,
  ) async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }

  @override
  Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(
    LocalDbModel model,
  ) async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    return Err(
      ErrorLocalDb.databaseError('Web database not supported on this platform'),
    );
  }
}
