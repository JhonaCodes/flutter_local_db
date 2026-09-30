import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:hive_ce/hive.dart';
import 'package:sembast/sembast_io.dart' as sembast;
import 'package:sqlite3/sqlite3.dart' as sql;

/// A database under benchmark. Every engine stores the same rows and answers
/// the same operations; see `Workload`.
abstract interface class Engine {
  /// Name shown in the results.
  String get name;

  /// When a committed write reaches the disk.
  String get durability;

  /// Where the database work runs: the calling isolate (blocking it) or
  /// another thread.
  String get runsOn;

  /// Opens a fresh database inside [directory].
  Future<void> open(String directory);

  /// Inserts [rows] in one transaction.
  Future<void> insertBatch(List<Map<String, Object?>> rows);

  /// Inserts one row in its own transaction.
  Future<void> insertOne(Map<String, Object?> row);

  /// The row with primary key [id].
  Future<Map<String, Object?>?> find(int id);

  /// Up to [limit] rows with `city = city AND age > minAge`.
  Future<int> query(String city, int minAge, int limit);

  /// Number of rows with `city = city`.
  Future<int> count(String city);

  /// Sets `age` of the row [id], in its own transaction.
  Future<void> updateAge(int id, int age);

  /// Closes the database.
  Future<void> close();
}

/// A row of the `users` table of flutter_local_db.
final class UserRow {
  /// Wraps the stored JSON.
  const UserRow(this.json);

  /// The stored JSON.
  final Map<String, dynamic> json;
}

/// The `users` table, with the index the query and the count use.
final class UsersTable extends Table<UserRow> {
  /// Creates the table definition.
  UsersTable() : super('users');

  /// Primary key.
  late final id = integer('id');

  /// City.
  late final city = text('city');

  /// Age.
  late final age = integer('age');

  @override
  Column<Object> get primaryKey => id;

  @override
  List<Index> get indexes => [
    Index('by_city_age', [city, age]),
  ];

  @override
  UserRow fromJson(Map<String, dynamic> json) => UserRow(json);

  @override
  Map<String, dynamic> toJson(UserRow row) => row.json;
}

/// flutter_local_db 2.0 through its Diesel-style API.
final class LocalDbEngine implements Engine {
  /// Opens with [mode].
  LocalDbEngine(this.mode);

  /// Durability of the commits.
  final Durability mode;

  final UsersTable _users = UsersTable();
  late LocalDatabase _db;

  @override
  String get name => 'flutter_local_db 2.0 (${mode.wire})';

  @override
  String get durability => switch (mode) {
    Durability.full => 'data and metadata flushed per commit',
    Durability.noMetaSync => 'data flushed per commit',
    Durability.noSync => 'no flush per commit',
  };

  @override
  String get runsOn => 'database isolate';

  @override
  Future<void> open(String directory) async {
    _db = await LocalDatabase.open(
      path: '$directory/localdb',
      tables: [_users],
      options: LocalDbOptions(durability: mode),
    );
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _users.insert([for (final row in rows) UserRow(row)]).execute(_db);

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _users.insert([UserRow(row)]).execute(_db);

  @override
  Future<Map<String, Object?>?> find(int id) async =>
      (await _users.find(id).first(_db))?.json;

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      (await _users
              .filter(_users.city.eq(city) & _users.age.gt(minAge))
              .limit(limit)
              .load(_db))
          .length;

  @override
  Future<int> count(String city) =>
      _users.filter(_users.city.eq(city)).count(_db);

  @override
  Future<void> updateAge(int id, int age) => _users
      .update()
      .filter(_users.id.eq(id))
      .set(_users.age, age)
      .execute(_db);

  @override
  Future<void> close() => _db.close();
}

/// SQLite through `package:sqlite3`, with prepared statements and an index on
/// `(city, age)`.
final class SqliteEngine implements Engine {
  /// With [durable], every commit is flushed (`synchronous=FULL`, and
  /// `fullfsync` on Apple); otherwise flushing is left to the OS
  /// (`synchronous=OFF`).
  SqliteEngine({required this.durable});

  /// Whether commits are flushed.
  final bool durable;

  late sql.Database _db;
  late sql.PreparedStatement _insert;
  late sql.PreparedStatement _find;
  late sql.PreparedStatement _query;
  late sql.PreparedStatement _count;
  late sql.PreparedStatement _update;

  @override
  String get name =>
      'SQLite ${sql.sqlite3.version.libVersion} '
      '(${durable ? 'synchronous=FULL' : 'synchronous=OFF'})';

  @override
  String get durability => durable
      ? 'WAL flushed per commit (fullfsync on Apple)'
      : 'no flush per commit (WAL)';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    _db = sql.sqlite3.open('$directory/sqlite.db');
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute(
      durable
          ? 'PRAGMA synchronous=FULL; PRAGMA fullfsync=ON'
          : 'PRAGMA synchronous=OFF',
    );
    _db.execute(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, '
      'age INTEGER, city TEXT, active INTEGER)',
    );
    _db.execute('CREATE INDEX by_city_age ON users (city, age)');
    _insert = _db.prepare('INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)');
    _find = _db.prepare('SELECT * FROM users WHERE id = ?');
    _query = _db.prepare(
      'SELECT * FROM users WHERE city = ? AND age > ? LIMIT ?',
    );
    _count = _db.prepare('SELECT COUNT(*) FROM users WHERE city = ?');
    _update = _db.prepare('UPDATE users SET age = ? WHERE id = ?');
  }

  List<Object?> _values(Map<String, Object?> row) => [
    row['id'],
    row['name'],
    row['email'],
    row['age'],
    row['city'],
    (row['active']! as bool) ? 1 : 0,
  ];

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) async {
    _db.execute('BEGIN');
    for (final row in rows) {
      _insert.execute(_values(row));
    }
    _db.execute('COMMIT');
  }

  @override
  Future<void> insertOne(Map<String, Object?> row) async =>
      _insert.execute(_values(row));

  @override
  Future<Map<String, Object?>?> find(int id) async {
    final result = _find.select([id]);
    return result.isEmpty ? null : Map.of(result.first);
  }

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      _query.select([city, minAge, limit]).length;

  @override
  Future<int> count(String city) async =>
      _count.select([city]).first.values.first! as int;

  @override
  Future<void> updateAge(int id, int age) async => _update.execute([age, id]);

  @override
  Future<void> close() async {
    for (final statement in [_insert, _find, _query, _count, _update]) {
      statement.close();
    }
    _db.close();
  }
}

/// Hive CE: an in-memory index of keys over an append-only file. Queries scan
/// the values, since Hive has no secondary indexes.
final class HiveEngine implements Engine {
  late Box<Map> _box;

  @override
  String get name => 'Hive CE 2';

  @override
  String get durability => 'no flush per write';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    Hive.init(directory);
    _box = await Hive.openBox<Map>('users');
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _box.putAll({for (final row in rows) row['id']! as int: row});

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _box.put(row['id']! as int, row);

  @override
  Future<Map<String, Object?>?> find(int id) async =>
      _box.get(id)?.cast<String, Object?>();

  @override
  Future<int> query(String city, int minAge, int limit) async => _box.values
      .where((row) => row['city'] == city && (row['age']! as int) > minAge)
      .take(limit)
      .length;

  @override
  Future<int> count(String city) async =>
      _box.values.where((row) => row['city'] == city).length;

  @override
  Future<void> updateAge(int id, int age) {
    final row = Map<String, Object?>.from(_box.get(id)!);
    row['age'] = age;
    return _box.put(id, row);
  }

  @override
  Future<void> close() => Hive.close();
}

/// Sembast: every record in memory, persisted to an append-only file.
final class SembastEngine implements Engine {
  late sembast.Database _db;
  final sembast.StoreRef<int, Map<String, Object?>> _store = sembast
      .intMapStoreFactory
      .store('users');

  @override
  String get name => 'Sembast 3';

  @override
  String get durability => 'no flush per write';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    _db = await sembast.databaseFactoryIo.openDatabase('$directory/sembast.db');
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _db.transaction((txn) async {
        for (final row in rows) {
          await _store.record(row['id']! as int).put(txn, row);
        }
      });

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _store.record(row['id']! as int).put(_db, row);

  @override
  Future<Map<String, Object?>?> find(int id) => _store.record(id).get(_db);

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      (await _store.find(
        _db,
        finder: sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('city', city),
            sembast.Filter.greaterThan('age', minAge),
          ]),
          limit: limit,
        ),
      )).length;

  @override
  Future<int> count(String city) =>
      _store.count(_db, filter: sembast.Filter.equals('city', city));

  @override
  Future<void> updateAge(int id, int age) =>
      _store.record(id).update(_db, {'age': age});

  @override
  Future<void> close() => _db.close();
}

/// A drift database without generated tables: the benchmark only runs SQL.
final class _DriftDatabase extends drift.GeneratedDatabase {
  _DriftDatabase(super.executor);

  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// drift on SQLite in a background isolate (`createInBackground`), durable
/// like [SqliteEngine] with `durable: true`.
final class DriftEngine implements Engine {
  late _DriftDatabase _db;

  @override
  String get name => 'drift 2 (synchronous=FULL)';

  @override
  String get durability => 'WAL flushed per commit (fullfsync on Apple)';

  @override
  String get runsOn => 'background isolate';

  @override
  Future<void> open(String directory) async {
    _db = _DriftDatabase(
      NativeDatabase.createInBackground(
        File('$directory/drift.db'),
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA synchronous=FULL');
          db.execute('PRAGMA fullfsync=ON');
        },
      ),
    );
    await _db.customStatement(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, '
      'age INTEGER, city TEXT, active INTEGER)',
    );
    await _db.customStatement('CREATE INDEX by_city_age ON users (city, age)');
  }

  static const String _insertSql =
      'INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)';

  List<Object?> _values(Map<String, Object?> row) => [
    row['id'],
    row['name'],
    row['email'],
    row['age'],
    row['city'],
    (row['active']! as bool) ? 1 : 0,
  ];

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _db.batch((batch) {
        for (final row in rows) {
          batch.customStatement(_insertSql, _values(row));
        }
      });

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _db.customStatement(_insertSql, _values(row));

  @override
  Future<Map<String, Object?>?> find(int id) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM users WHERE id = ?',
          variables: [drift.Variable.withInt(id)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      (await _db
              .customSelect(
                'SELECT * FROM users WHERE city = ? AND age > ? LIMIT ?',
                variables: [
                  drift.Variable.withString(city),
                  drift.Variable.withInt(minAge),
                  drift.Variable.withInt(limit),
                ],
              )
              .get())
          .length;

  @override
  Future<int> count(String city) async =>
      (await _db
              .customSelect(
                'SELECT COUNT(*) AS c FROM users WHERE city = ?',
                variables: [drift.Variable.withString(city)],
              )
              .getSingle())
          .read<int>('c');

  @override
  Future<void> updateAge(int id, int age) =>
      _db.customStatement('UPDATE users SET age = ? WHERE id = ?', [age, id]);

  @override
  Future<void> close() => _db.close();
}
