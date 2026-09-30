import 'dart:async';

import 'package:path/path.dart' as p;

import '../dsl/statements.dart';
import '../dsl/table.dart';
import 'bridge.dart';
import 'engine_bridge.dart';
import 'errors.dart';

/// How commits reach stable storage.
enum Durability {
  /// Every commit is flushed before it completes (default). A committed
  /// transaction survives a power loss.
  full('full'),

  /// Skips flushing the metadata page: a system crash may undo the last
  /// transaction, never corrupt the database.
  noMetaSync('no_meta_sync'),

  /// Leaves flushing to the operating system: a system crash may undo the
  /// last transactions. An app crash loses nothing.
  noSync('no_sync');

  const Durability(this.wire);

  /// The value sent to the engine.
  final String wire;
}

/// Options for opening a [LocalDatabase]. They apply when the database is
/// first opened in the process.
final class LocalDbOptions {
  /// Options with the engine defaults.
  const LocalDbOptions({
    this.maxTables = 1024,
    this.initialSize = 64 << 20,
    this.maxSize = 16 << 30,
    this.durability = Durability.full,
  });

  /// Maximum number of tables plus indexes.
  final int maxTables;

  /// Initial size of the memory map, in bytes (address space, not disk).
  final int initialSize;

  /// The map doubles when full, up to this size in bytes.
  final int maxSize;

  /// How commits reach stable storage.
  final Durability durability;

  /// The `OpenOptions` of the engine.
  Map<String, Object?> toJson() => {
    'max_dbs': maxTables,
    'initial_map_size': initialSize,
    'max_map_size': maxSize,
    'durability': durability.wire,
  };
}

/// A local database queried Diesel-style, backed by the native engine
/// offline_first_core (Rust + LMDB 1.0).
///
/// ```dart
/// final db = await LocalDatabase.open(path: '${dir.path}/app', tables: [skills]);
///
/// await skills.insert([Skill(id: 'rust-review', language: 'rust', priority: 3)]).execute(db);
///
/// final top = await skills
///     .filter(skills.language.eq('rust') & skills.priority.ge(2))
///     .order(skills.priority.desc())
///     .limit(20)
///     .load(db);
///
/// await db.transaction((tx) async {
///   await skills.update().filter(skills.id.eq('rust-review')).set(skills.priority, 5).execute(tx);
/// });
/// ```
///
/// Every call runs in a background isolate. Statements executed on the
/// database run in their own transaction; use [transaction] to group them.
final class LocalDatabase implements QueryExecutor {
  LocalDatabase._(this._bridge, this.path);

  /// Base path of the database; its files live in `<path>.lmdb`.
  final String path;

  final EngineBridge _bridge;
  final _WriteLock _writes = _WriteLock();
  final StreamController<Set<String>> _changes =
      StreamController<Set<String>>.broadcast();
  bool _closed = false;

  static final Object _transactionZone = Object();

  /// Opens (or creates) the database stored in `<path>.lmdb` and defines
  /// [tables] (adding or removing indexes of existing ones).
  ///
  /// Throws [LocalDbException] with [LocalDbErrorCode.legacyFormat] for a
  /// database written by flutter_local_db 1.x, and
  /// [LocalDbErrorCode.unsupportedPlatform] on the web.
  static Future<LocalDatabase> open({
    required String path,
    List<Table<Object?>> tables = const [],
    LocalDbOptions options = const LocalDbOptions(),
  }) async {
    final bridge = await EngineBridges.open(path, options.toJson());
    final database = LocalDatabase._(bridge, path);
    for (final table in tables) {
      await database.defineTable(table);
    }
    return database;
  }

  /// Opens the database [name] in the application support directory.
  static Future<LocalDatabase> openNamed(
    String name, {
    List<Table<Object?>> tables = const [],
    LocalDbOptions options = const LocalDbOptions(),
  }) async {
    final directory = await EngineBridges.applicationSupportDirectory();
    return open(
      path: p.join(directory, name),
      tables: tables,
      options: options,
    );
  }

  void _checkUsable() {
    if (_closed) {
      throw const LocalDbException(
        LocalDbErrorCode.closed,
        'The database is closed',
      );
    }
    if (identical(Zone.current[_transactionZone], this)) {
      throw const LocalDbException(
        LocalDbErrorCode.transactionReentrancy,
        'The database was used inside one of its own transactions; use the '
        'transaction object instead',
      );
    }
  }

  Future<Map<String, Object?>> _request(
    String operation, [
    Map<String, Object?> fields = const {},
  ]) => _bridge.request({'v': 1, 'op': operation, ...fields});

  void _notify(Set<String> tables) {
    if (tables.isNotEmpty && !_changes.isClosed) {
      _changes.add(tables);
    }
  }

  static bool _isWrite(Map<String, Object?> statement) =>
      const {'insert', 'update', 'delete'}.contains(statement['op']);

  @override
  Future<Map<String, Object?>> executeStatement(
    Map<String, Object?> statement,
  ) {
    _checkUsable();
    if (!_isWrite(statement)) {
      return _request('execute', {'statement': statement});
    }
    return _writes.run(() async {
      final result = await _request('execute', {'statement': statement});
      _notify({statement['table']! as String});
      return result;
    });
  }

  /// Defines [table], or adds and removes indexes of an existing one (new
  /// indexes are built over the existing rows).
  Future<void> defineTable(Table<Object?> table) {
    _checkUsable();
    return _writes.run(
      () => _request('define_table', {'table': table.toDefinition()}),
    );
  }

  /// Drops the table [name] with all its rows. Returns whether it existed.
  Future<bool> dropTable(String name) {
    _checkUsable();
    return _writes.run(() async {
      final dropped =
          (await _request('drop_table', {'name': name}))['dropped']! as bool;
      _notify({name});
      return dropped;
    });
  }

  /// Definitions of the tables of this database.
  Future<List<Map<String, Object?>>> tables() async {
    _checkUsable();
    final result = await _request('tables');
    return [
      ...(result['tables']! as List<Object?>).cast<Map<String, Object?>>(),
    ];
  }

  /// Runs [statements] in order in one transaction: all of them are
  /// committed, or none is. Returns the rows each one affected.
  Future<List<int>> atomicBatch(List<WriteStatement> statements) {
    _checkUsable();
    return _writes.run(() async {
      final result = await _request('batch', {
        'statements': [for (final statement in statements) statement.toJson()],
      });
      _notify({for (final statement in statements) statement.tableName});
      return [
        for (final entry in result['results']! as List<Object?>)
          (entry! as Map<String, Object?>)['affected']! as int,
      ];
    });
  }

  /// Runs [body] in a write transaction: it commits when [body] completes and
  /// rolls back when it throws. The result is returned after the commit.
  ///
  /// Inside [body], run statements on `tx` (using the database directly
  /// throws [LocalDbErrorCode.transactionReentrancy]). A write that fails
  /// makes the transaction rollback-only; wrap recoverable work in
  /// [Transaction.savepoint]. Other writes of this database wait until the
  /// transaction ends. After [idleTimeout] without a statement, the engine
  /// rolls the transaction back.
  Future<R> transaction<R>(
    Future<R> Function(Transaction tx) body, {
    Duration idleTimeout = const Duration(seconds: 30),
  }) {
    _checkUsable();
    return _writes.run(() async {
      final id =
          (await _request('begin', {
                'mode': 'write',
                'timeout_ms': idleTimeout.inMilliseconds,
              }))['transaction']!
              as int;
      final tx = Transaction._(this, id);
      final R result;
      try {
        result = await runZoned(
          () => body(tx),
          zoneValues: {_transactionZone: this},
        );
      } catch (_) {
        tx._closed = true;
        await _rollbackQuietly(id);
        rethrow;
      }
      tx._closed = true;
      await _request('commit', {'transaction': id});
      _notify(tx._touched);
      return result;
    });
  }

  /// Runs [body] against one consistent read-only snapshot.
  Future<R> readTransaction<R>(
    Future<R> Function(ReadTransaction tx) body, {
    Duration idleTimeout = const Duration(seconds: 30),
  }) async {
    _checkUsable();
    final id =
        (await _request('begin', {
              'mode': 'read',
              'timeout_ms': idleTimeout.inMilliseconds,
            }))['transaction']!
            as int;
    final tx = ReadTransaction._(this, id);
    try {
      return await body(tx);
    } finally {
      tx._closed = true;
      await _rollbackQuietly(id);
    }
  }

  Future<void> _rollbackQuietly(int id) async {
    try {
      await _request('rollback', {'transaction': id});
    } on LocalDbException {
      // Already closed or expired: nothing is left to roll back.
    }
  }

  /// The plan the engine chooses for [query].
  Future<Map<String, Object?>> explain(SelectQuery<Object?> query) async {
    _checkUsable();
    final result = await _request('explain', {'query': query.toQueryJson()});
    return result['plan']! as Map<String, Object?>;
  }

  /// The rows of [query] now, and again after every committed write of this
  /// database to its table.
  Stream<List<T>> watch<T>(SelectQuery<T> query) {
    late final StreamController<List<T>> controller;
    StreamSubscription<Set<String>>? changes;
    var loading = false;
    var stale = false;

    Future<void> reload() async {
      if (loading) {
        stale = true;
        return;
      }
      loading = true;
      do {
        stale = false;
        try {
          final rows = await query.load(this);
          if (!controller.isClosed) {
            controller.add(rows);
          }
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      } while (stale && !controller.isClosed);
      loading = false;
    }

    controller = StreamController<List<T>>(
      onListen: () {
        changes = _changes.stream
            .where((tables) => tables.contains(query.table.tableName))
            .listen((_) => reload());
        reload();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  /// Tables written by each commit of this database (for custom reactivity).
  Stream<Set<String>> get changes => _changes.stream;

  /// Size of the memory map, LMDB version and number of tables.
  Future<Map<String, Object?>> info() {
    _checkUsable();
    return _request('info');
  }

  /// Waits for running writes and releases the database.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    await _writes.run(() async {
      _closed = true;
      await _bridge.close();
    });
    await _changes.close();
  }
}

/// A write transaction (see [LocalDatabase.transaction]).
final class Transaction implements QueryExecutor {
  Transaction._(this._database, this._id);

  final LocalDatabase _database;
  final int _id;
  final Set<String> _touched = {};
  bool _closed = false;

  @override
  Future<Map<String, Object?>> executeStatement(
    Map<String, Object?> statement,
  ) async {
    if (_closed) {
      throw const LocalDbException(
        LocalDbErrorCode.transactionClosed,
        'The transaction is closed',
      );
    }
    final result = await _database._request('tx_execute', {
      'transaction': _id,
      'statement': statement,
    });
    if (LocalDatabase._isWrite(statement)) {
      _touched.add(statement['table']! as String);
    }
    return result;
  }

  /// Runs [body] in a savepoint: when it throws, only its writes are rolled
  /// back and the error is rethrown; the transaction stays usable.
  Future<R> savepoint<R>(Future<R> Function(Transaction tx) body) async {
    await _database._request('savepoint', {'transaction': _id});
    final touched = {..._touched};
    try {
      final result = await body(this);
      await _database._request('release', {'transaction': _id});
      return result;
    } catch (_) {
      _touched
        ..clear()
        ..addAll(touched);
      try {
        await _database._request('rollback_to', {'transaction': _id});
      } on LocalDbException {
        // The transaction ended; the error below explains why.
      }
      rethrow;
    }
  }
}

/// A read-only snapshot (see [LocalDatabase.readTransaction]).
final class ReadTransaction implements QueryExecutor {
  ReadTransaction._(this._database, this._id);

  final LocalDatabase _database;
  final int _id;
  bool _closed = false;

  @override
  Future<Map<String, Object?>> executeStatement(
    Map<String, Object?> statement,
  ) {
    if (_closed) {
      throw const LocalDbException(
        LocalDbErrorCode.transactionClosed,
        'The transaction is closed',
      );
    }
    return _database._request('tx_execute', {
      'transaction': _id,
      'statement': statement,
    });
  }
}

/// Serializes the writes of one database: a transaction holds the engine's
/// writer, so a write sent meanwhile from outside it would wait inside the
/// worker and block the transaction's own statements.
final class _WriteLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }
}
