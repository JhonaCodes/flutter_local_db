/// The one entry point of flutter_local_db.
library;

import 'package:db_dsl/db_dsl.dart';

import 'database/local_engine.dart';
import 'models/local_db_error.dart';
import 'models/local_db_model.dart';
import 'services/local_db_service.dart';
import 'utils/local_db_export.dart';
import 'utils/path_helper.dart';

/// The database of the app: key-value records and typed tables, in one file.
///
/// Key-value records work as in 1.x, without declaring anything:
///
/// ```dart
/// await LocalDB.init();
/// await LocalDB.Post('settings', {'theme': 'dark'});
/// final settings = await LocalDB.GetById('settings');
/// ```
///
/// Typed tables add Diesel-style queries (from db_dsl). Nothing lists
/// them: a table defines itself here the first time it is used, and its
/// queries run here when awaited, with no database to name:
///
/// ```dart
/// await LocalDB.init();
/// final users = User.table;
/// await users.insert([ada, grace]);
/// final adults = await users.filter(users.age.ge(18)).order(users.name.asc());
/// ```
///
/// Why one class: an app has one database, and one place to open, use and
/// close it. Another database of the same app is the exception: open it
/// with [open] and name it on the queries that go there.
///
/// Records and tables share `<path>.lmdb` on Android, iOS, macOS, Linux and
/// Windows (records live in the LMDB database `main`, each table in
/// `t:<name>`, so they never collide). On the web only the key-value API
/// exists, on IndexedDB.
abstract final class LocalDB {
  static LocalDbService? _service;
  static Database? _database;

  /// Opens the database of the app, at [path] (default: a
  /// `flutter_local_db` directory in the app's documents directory on
  /// Android and iOS, its support directory elsewhere).
  ///
  /// Tables need not be listed: each defines itself here the first time it
  /// is used. [tables] defines them up front — new ones are created, new
  /// indexes are built over existing rows, removed indexes are dropped —
  /// for a table whose first use is inside a transaction (which answers
  /// [DbErrorCode.tableNotReady] otherwise), or to build indexes at
  /// start-up. Calling it again adds [tables] to the open database.
  ///
  /// [DbErrorCode.legacyFormat] means the files were written by
  /// flutter_local_db 1.x (see [moveLegacyDatabaseAside]). On the web,
  /// [tables] answer [DbErrorCode.unsupportedPlatform].
  static Future<Result<(), DbError>> init({
    String? path,
    List<DbTable<Object?>> tables = const [],
    DbOptions options = const DbOptions(),
  }) async {
    if (_service != null) {
      return _define(tables);
    }

    if (!LocalEngine.available && tables.isNotEmpty) {
      return Err(_webHasNoTables);
    }

    return (await _location(path)).when(
      ok: (location) => _open(location, tables, options),
      err: (error) async => Err(error),
    );
  }

  /// Opens another database of the app at [path], besides the one of
  /// [init]. Its queries run there only when it is named:
  /// `users.all().load(archive)`, `users.insert([ada]).execute(archive)`.
  ///
  /// A table already defined by the database of [init] stays that
  /// database's; a table defined here first becomes this one's.
  static Future<Result<Database, DbError>> open(
    String path, {
    List<DbTable<Object?>> tables = const [],
    DbOptions options = const DbOptions(),
  }) => Database.open(
    LocalEngine.engine,
    path: path,
    tables: tables,
    options: options,
  );

  /// Runs [body] in a write transaction: it commits when [body] answers
  /// `Ok` and rolls back when it answers `Err`. Queries awaited inside run
  /// on the transaction.
  static Future<Result<R, DbError>> transaction<R>(
    Future<Result<R, DbError>> Function(Transaction tx) body, {
    Duration idleTimeout = BeginRequest.defaultIdleTimeout,
  }) => _withDatabase(
    (database) => database.transaction(body, idleTimeout: idleTimeout),
  );

  /// Runs [body] on one consistent read-only snapshot. Queries awaited
  /// inside read the snapshot.
  static Future<Result<R, DbError>> readTransaction<R>(
    Future<Result<R, DbError>> Function(ReadTransaction tx) body, {
    Duration idleTimeout = BeginRequest.defaultIdleTimeout,
  }) => _withDatabase(
    (database) => database.readTransaction(body, idleTimeout: idleTimeout),
  );

  /// Runs [writes] in one transaction: all of them commit, or none does.
  /// Answers the rows each one affected.
  static Future<Result<List<int>, DbError>> atomicBatch(
    List<WriteQuery> writes,
  ) => _withDatabase((database) => database.atomicBatch(writes));

  /// Facts about the database and its engine.
  static Future<Result<EngineInfo, DbError>> info() =>
      _withDatabase((database) => database.info());

  /// Whether [init] succeeded and [close] was not called since.
  static bool get isInitialized => _service?.isInitialized ?? false;

  /// Releases the database; [init] opens it again.
  static Future<Result<(), DbError>> close() async {
    _service?.close();
    _service = null;

    final database = _database;
    _database = null;

    if (database == null) {
      return Ok(());
    }

    return database.close();
  }

  // Key-value records, as in 1.x.

  /// Stores [data] under [key], replacing a record with the same key.
  ///
  /// [lastUpdate] is accepted for compatibility and ignored, as in 1.x.
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel, ErrorLocalDb>> Post(
    String key,
    Map<String, dynamic> data, {
    String? lastUpdate,
  }) => _withService((service) => service.store(key, LocalMethod.post, data));

  /// The record [key], or `null` when there is none.
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel?, ErrorLocalDb>> GetById(String key) =>
      _withService(
        (service) async => (await service.retrieve(key)).when(
          ok: Ok.new,
          err: (error) => switch (error.type) {
            LocalDbErrorType.notFound => Ok(null),
            _ => Err(error),
          },
        ),
      );

  /// Replaces the record [key].
  // ignore: non_constant_identifier_names
  static Future<Result<LocalDbModel, ErrorLocalDb>> Put(
    String key,
    Map<String, dynamic> data,
  ) => _withService((service) => service.store(key, LocalMethod.put, data));

  /// Deletes the record [key]; succeeds when there was none.
  // ignore: non_constant_identifier_names
  static Future<Result<bool, ErrorLocalDb>> Delete(String key) => _withService(
    (service) async => (await service.remove(key)).map((_) => true),
  );

  /// Every record.
  // ignore: non_constant_identifier_names
  static Future<Result<List<LocalDbModel>, ErrorLocalDb>> GetAll() =>
      _withService(
        (service) async =>
            (await service.listAll()).map((all) => all.values.toList()),
      );

  /// Deletes every record (not the tables).
  // ignore: non_constant_identifier_names
  static Future<Result<bool, ErrorLocalDb>> ClearData() => _withService(
    (service) async => (await service.clearAll()).map((_) => true),
  );

  /// Every record as a portable JSON document (see [LocalDbExport]), for
  /// [importAll].
  static Future<Result<String, ErrorLocalDb>> exportAll() async =>
      (await GetAll()).map(LocalDbExport.encode);

  /// Restores the records of a document written by [exportAll] (for example
  /// by the 1.6 version of the app), replacing records with the same key.
  /// Answers how many records were imported.
  static Future<Result<int, ErrorLocalDb>> importAll(String json) =>
      _withService(
        (service) async => LocalDbExport.decode(json).when(
          ok: (records) async {
            for (final record in records) {
              final stored = await service.store(
                record.id,
                LocalMethod.put,
                record.data,
              );

              if (stored case Err(:final error)) {
                return Err(error);
              }
            }

            return Ok(records.length);
          },
          err: (error) async => Err(error),
        ),
      );

  /// Moves the files of a 1.x database at [path] (default: the one of
  /// [init]), which LMDB 1.0 cannot read, to a backup directory next to
  /// them, so that [init] creates a new database. Answers the backup
  /// location.
  ///
  /// ```dart
  /// final opened = await LocalDB.init();
  ///
  /// if (opened case Err(error: DbError(code: DbErrorCode.legacyFormat))) {
  ///   await LocalDB.moveLegacyDatabaseAside();
  ///   await LocalDB.init();
  ///   await LocalDB.importAll(exportSavedByVersion16);
  /// }
  /// ```
  static Future<Result<String, ErrorLocalDb>> moveLegacyDatabaseAside({
    String? path,
  }) async => switch (path) {
    final String given => PathHelper.moveAside(given),
    null => (await PathHelper.getDefaultDatabasePath()).when(
      ok: PathHelper.moveAside,
      err: (error) async => Err(error),
    ),
  };

  /// Opens the tables (where the native engine runs) and the records.
  ///
  /// The tables open first: the first open of the files fixes their options
  /// (durability, map size), so [options] must reach the engine before the
  /// key-value layer opens the same files with its defaults.
  static Future<Result<(), DbError>> _open(
    String path,
    List<DbTable<Object?>> tables,
    DbOptions options,
  ) async {
    if (!LocalEngine.available) {
      return _openRecords(path, null);
    }

    return (await open(path, tables: tables, options: options)).when(
      ok: (database) => _openRecords(path, database),
      err: (error) async => Err(error),
    );
  }

  /// Opens the records next to the open [database], if any; on failure the
  /// database is closed again.
  static Future<Result<(), DbError>> _openRecords(
    String path,
    Database? database,
  ) async => (await LocalDbService.initializeWithPath(path)).when(
    ok: (service) {
      _service = service;
      _database = database;
      return Ok(());
    },
    err: (error) async {
      await database?.close();
      return Err(_asDbError(error));
    },
  );

  /// Adds [tables] to the open database.
  static Future<Result<(), DbError>> _define(
    List<DbTable<Object?>> tables,
  ) async => switch ((tables, _database)) {
    ([], _) => Ok(()),
    (_, final Database database) => await database.defineTables(tables),
    (_, null) => Err(_webHasNoTables),
  };

  /// [path], or the default location of the platform.
  static Future<Result<String, DbError>> _location(String? path) async =>
      switch (path) {
        final String given => Ok(given),
        null => (await PathHelper.getDefaultDatabasePath()).mapError(
          _asDbError,
        ),
      };

  static Future<Result<T, ErrorLocalDb>> _withService<T>(
    Future<Result<T, ErrorLocalDb>> Function(LocalDbService service) action,
  ) => switch (_service) {
    final LocalDbService service => action(service),
    null => Future.value(
      Err(ErrorLocalDb.databaseError('Database not initialized')),
    ),
  };

  static Future<Result<T, DbError>> _withDatabase<T>(
    Future<Result<T, DbError>> Function(Database database) action,
  ) => switch ((_database, _service)) {
    (final Database database, _) => action(database),
    (null, LocalDbService()) => Future.value(Err(_webHasNoTables)),
    (null, null) => Future.value(
      Err(
        DbError(DbErrorCode.notOpen, 'LocalDB is not open: call LocalDB.init'),
      ),
    ),
  };

  static DbError get _webHasNoTables => DbError(
    DbErrorCode.unsupportedPlatform,
    'Tables need the native engine, which does not run on the web; the web '
    'has the key-value API of LocalDB',
  );

  /// The [DbError] of a failure of the key-value layer while opening.
  static DbError _asDbError(ErrorLocalDb error) => DbError(switch (error.type) {
    LocalDbErrorType.legacyFormat => DbErrorCode.legacyFormat,
    LocalDbErrorType.platform => DbErrorCode.unsupportedPlatform,
    LocalDbErrorType.ffi => DbErrorCode.nativeLibrary,
    LocalDbErrorType.initialization ||
    LocalDbErrorType.notFound ||
    LocalDbErrorType.validation ||
    LocalDbErrorType.database ||
    LocalDbErrorType.serialization ||
    LocalDbErrorType.unknown => DbErrorCode.storage,
  }, error.message);
}

/// How the key-value layer writes a record.
enum LocalMethod {
  /// Create or replace.
  post,

  /// Replace.
  put,

  /// Replace an existing record.
  update,
}
