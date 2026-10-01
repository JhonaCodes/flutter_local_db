part of 'local_db.dart';

/// The offline-first sync of the database of [LocalDB.init]: the
/// operations of db_dsl's `DbSync`, for the tables declared with
/// `syncWith`.
///
/// ```dart
/// static final table = DbTable<Note>('notes', key: 'id', fromJson: Note.fromJson, syncWith: 'primary');
///
/// await Note.table.insert([draft]);        // records its change, same commit
/// final batch = await LocalDB.sync.claim('primary');
/// ```
///
/// Why a facade: the app has one database, opened by [LocalDB.init], and
/// one entry point; on the web, which has no tables, every operation
/// answers [DbErrorCode.unsupportedPlatform].
final class LocalDbSync {
  const LocalDbSync._();

  /// See `DbSync.claim`.
  Future<Result<ClaimedBatch, DbError>> claim(
    String remote, {
    ClaimLimits limits = const ClaimLimits(),
  }) => LocalDB._withDatabase(
    (database) => database.sync.claim(remote, limits: limits),
  );

  /// See `DbSync.applyPushResult`.
  Future<Result<PushOutcome, DbError>> applyPushResult(
    String remote,
    PushResult result,
  ) => LocalDB._withDatabase(
    (database) => database.sync.applyPushResult(remote, result),
  );

  /// See `DbSync.release`.
  Future<Result<int, DbError>> release(
    String remote,
    int leaseId, {
    String reason = 'released',
  }) => LocalDB._withDatabase(
    (database) => database.sync.release(remote, leaseId, reason: reason),
  );

  /// See `DbSync.retry`.
  Future<Result<int, DbError>> retry(String remote, List<String> mutationIds) =>
      LocalDB._withDatabase(
        (database) => database.sync.retry(remote, mutationIds),
      );

  /// See `DbSync.applyRemote`.
  Future<Result<ApplyOutcome, DbError>> applyRemote(
    String remote,
    RemotePage page,
  ) => LocalDB._withDatabase(
    (database) => database.sync.applyRemote(remote, page),
  );

  /// See `DbSync.resolveConflict`.
  Future<Result<(), DbError>> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) => LocalDB._withDatabase(
    (database) => database.sync.resolveConflict(conflict, resolution),
  );

  /// See `DbSync.stateOf`.
  Future<Result<EntitySyncState?, DbError>> stateOf(
    DbTable<Object?> table,
    Object key,
  ) => LocalDB._withDatabase((database) => database.sync.stateOf(table, key));

  /// See `DbSync.pending`.
  Future<Result<PendingChanges, DbError>> pending(
    String remote, {
    DbTable<Object?>? table,
    int? limit,
  }) => LocalDB._withDatabase(
    (database) => database.sync.pending(remote, table: table, limit: limit),
  );

  /// See `DbSync.conflicts`.
  Future<Result<List<SyncConflict>, DbError>> conflicts(String remote) =>
      LocalDB._withDatabase((database) => database.sync.conflicts(remote));

  /// See `DbSync.status`.
  Future<Result<RemoteSyncStatus, DbError>> status(String remote) =>
      LocalDB._withDatabase((database) => database.sync.status(remote));
}
