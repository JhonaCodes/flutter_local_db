# flutter_local_db

An embedded database for Flutter with a query API modelled on
[Diesel](https://diesel.rs): typed tables, secondary indexes, a query planner,
transactions with savepoints and reactive queries. The engine is
[offline_first_core](https://github.com/JhonaCodes/offline_first_core), written
in Rust on **LMDB 1.0.2** through [natdb](https://crates.io/crates/natdb).

- **Tables** of JSON rows with a primary key, typed columns and optional
  auto-increment keys. No code generation.
- **Indexes**: single, composite and unique, maintained in the same
  transaction as their rows and built over existing rows when added.
- **Queries**: `filter`, `orFilter`, `order`, `limit`, `offset`, `count`,
  `sum`, `avg`, `min`, `max`, and `explain` to see the chosen index.
- **Transactions**: commit on success, rollback on error, savepoints, read
  snapshots and atomic batches.
- **Reactive**: `watch` emits a query's rows again after every committed write
  to its table.
- **Platforms**: Android, iOS, macOS, Linux and Windows. The library ships
  prebuilt and a build hook bundles it: nothing to configure.
- **Off the UI isolate**: every call runs on a database isolate.

```dart
final db = await LocalDatabase.openNamed('app', tables: [users]);

await users.insert([User(id: 1, name: 'Ana', city: 'Lima', age: 31)]).execute(db);

final adults = await users
    .filter(users.city.eq('Lima') & users.age.ge(18))
    .order(users.age.desc())
    .limit(20)
    .load(db);
```

## Install

```yaml
dependencies:
  flutter_local_db: ^2.0.0
```

Flutter 3.38 or later (build hooks). There is no platform setup: the build
hook adds the native library of each target (Android ABIs, iOS device and
simulator, macOS, Linux and Windows on x64 and arm64) to the app.

## Define a table

A table maps a Dart class to rows. Columns name the fields that queries use;
the row itself is whatever `toJson` returns.

```dart
final class User {
  const User({this.id, required this.name, required this.city, required this.age});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    city: json['city'] as String,
    age: json['age'] as int,
  );

  final int? id;
  final String name;
  final String city;
  final int age;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'city': city, 'age': age};
}

final class UsersTable extends Table<User> {
  UsersTable() : super('users');

  late final id = integer('id');
  late final name = text('name');
  late final city = text('city');
  late final age = integer('age');

  @override
  Column<Object> get primaryKey => id;

  @override
  bool get autoIncrement => true; // a null id is generated on insert

  @override
  List<Index> get indexes => [
    Index('by_city_age', [city, age]),
    Index.unique('by_name', [name]),
  ];

  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);

  @override
  Map<String, dynamic> toJson(User row) => row.toJson();
}

final users = UsersTable();
```

Column types: `text`, `integer`, `real`, `boolean` and `dateTime` (stored as
UTC microseconds, so it sorts; convert with `DateTimeColumn.toStorage` and
`fromStorage` in your `toJson`/`fromJson`). A column name can be a dotted path
into nested objects (`text('address.city')`).

## Open

```dart
// In the application support directory:
final db = await LocalDatabase.openNamed('app', tables: [users]);

// Or at a path of your choice (files go to '<path>.lmdb'):
final db = await LocalDatabase.open(path: '${dir.path}/app', tables: [users]);
```

`open` defines the tables: a new table is created, and indexes added to or
removed from an existing table are built or dropped. Open each database once
and share the `LocalDatabase` object: a second object on the same path shares
the files but not the write queue, so its writes can wait behind the other's
transactions.

## Query

| Diesel (Rust) | flutter_local_db |
|---|---|
| `users.filter(city.eq("Lima"))` | `users.filter(users.city.eq('Lima'))` |
| `.and(...)` / `.or(...)` / `not(...)` | `a & b` / `a \| b` / `~a` |
| `.or_filter(...)` | `.orFilter(...)` |
| `ne`, `gt`, `ge`, `lt`, `le` | `ne`, `gt`, `ge`, `lt`, `le` |
| `eq_any`, `ne_all` | `eqAny`, `neAll` |
| `between`, `not_between` | `between`, `notBetween` |
| `is_null`, `is_not_null` | `isNull()`, `isNotNull()` |
| `like`, `ilike` | `like`, `ilike` (text columns) |
| `.order(age.desc())`, `.then_order_by(...)` | `.order(users.age.desc())`, `.thenOrderBy(...)` |
| `.limit(n)`, `.offset(n)` | `.limit(n)`, `.offset(n)` |
| `.load(conn)`, `.first(conn)` | `.load(db)`, `.first(db)` |
| `.count().get_result(conn)` | `.count(db)` |
| `users.find(id).first(conn)` | `users.find(id).first(db)` |
| `sum`, `avg`, `min`, `max` | `.sum(col, db)`, `.avg(col, db)`, `.min(col, db)`, `.max(col, db)` |

```dart
final page = await users
    .filter(users.city.eqAny(['Lima', 'Bogotá']))
    .orFilter(users.age.lt(18))
    .order(users.name.asc())
    .limit(50)
    .offset(100)
    .load(db);

final ana = await users.find(1).first(db); // null when missing
final average = await users.filter(users.city.eq('Lima')).avg(users.age, db);
```

Comparisons follow SQL: a value only compares with values of its kind, and
`NULL` or a missing field matches no comparison (use `isNull()`). Without
`order`, the order of the rows is unspecified.

## Write

```dart
await users.insert([ana, luis]).execute(db);              // returns the count
final saved = await users.insert([nuevo]).getResults(db); // rows with generated ids
await users.insert([ana]).onConflictDoNothing().execute(db);
await users.insert([ana]).onConflictReplace().execute(db);

await users
    .update()
    .filter(users.city.eq('Lima'))
    .set(users.age, 40)
    .execute(db);

await users.delete().filter(users.age.lt(18)).execute(db);

// Fails, changing nothing, unless exactly one row matches:
await users.delete().filter(users.id.eq(7)).expectAffectedRows(1).execute(db);
```

An insert of an existing primary key fails with `duplicateKey`, and a
duplicate value of a unique index with `uniqueViolation`, unless
`onConflictDoNothing` or `onConflictReplace` says otherwise. Every statement
is atomic.

## Transactions

```dart
final total = await db.transaction((tx) async {
  await users.insert([ana]).execute(tx);
  await tx.savepoint((sp) async {
    // A failure here rolls back only the savepoint, and rethrows.
    await users.update().filter(users.id.eq(2)).set(users.age, 30).execute(sp);
  });
  return users.all().count(tx); // reads see the transaction's writes
}); // committed here; an exception rolls everything back

final snapshot = await db.readTransaction((tx) async {
  // One consistent view, while other writes go on.
  return (await users.all().count(tx), await users.all().max(users.age, tx));
});

await db.atomicBatch([
  users.insert([ana]),
  users.update().filter(users.id.eq(2)).set(users.age, 30),
]); // all or nothing, in one round trip
```

- Inside `transaction`, run statements on `tx`. Using `db` there fails with
  `transactionReentrancy` instead of deadlocking.
- A write that fails inside a transaction makes it rollback-only: the commit
  fails with `transactionAborted` even when the error was caught. Put
  recoverable work in a `savepoint`.
- Other writes of the database wait until the transaction ends. A transaction
  idle for longer than `idleTimeout` (30 s by default) is rolled back.

## Watch

```dart
StreamBuilder<List<User>>(
  stream: users.filter(users.city.eq('Lima')).order(users.name.asc()).watch(db),
  builder: (context, snapshot) => UserList(users: snapshot.data ?? const []),
);
```

`watch` emits the rows at once and again after every committed write to the
table. `db.changes` streams the tables each commit wrote.

## Indexes and `explain`

The planner looks rows up by primary key, or picks the index with the most
leading `eq` columns plus a range on the next one, or an index that already
follows `order` (stopping after `limit`). `explain` shows the choice:

```dart
final plan = await users
    .filter(users.city.eq('Lima') & users.age.gt(30))
    .order(users.age.desc())
    .explain(db);
// {table: users, access: index_scan, index: by_city_age,
//  descending: true, presorted: true, exact: true}
```

`exact: true` means the index alone decides the filter: rows are not checked
again, and `count` reads no row at all. Add an index when `explain` reports
`full_scan` for a query on a large table.

## Durability

```dart
final db = await LocalDatabase.open(
  path: path,
  options: const LocalDbOptions(durability: Durability.noMetaSync),
);
```

| `Durability` | A committed transaction after a power loss |
|---|---|
| `full` (default) | is kept: data and metadata are flushed on every commit |
| `noMetaSync` | may be undone (the last one), never corrupted; one flush per commit instead of two |
| `noSync` | the last ones may be undone; flushing is left to the OS. An app crash loses nothing |

On Apple hardware a flush is `F_FULLFSYNC`, which takes milliseconds: group
writes in a transaction or `atomicBatch` rather than committing row by row.

The database file grows as needed: `LocalDbOptions.initialSize` (64 MiB) and
`maxSize` (16 GiB) are address space reserved for the memory map, not disk.

## Errors

Failures throw `LocalDbException` with a `code` (`LocalDbErrorCode`):
`duplicateKey`, `uniqueViolation`, `affectedRowsMismatch`, `tableNotFound`,
`invalidSchema`, `schemaMismatch`, `missingPrimaryKey`, `keyTooLarge`,
`mapFull`, `transactionAborted`, `transactionReentrancy`,
`transactionExpired`, `closed`, `legacyFormat`, `unsupportedPlatform`,
`nativeLibrary` and the rest listed in the API docs.

## Platforms

| Platform | Architectures | Minimum |
|---|---|---|
| Android | arm64-v8a, armeabi-v7a, x86_64, x86 (16 KB pages) | API 21 |
| iOS | device arm64; simulator arm64, x86_64 | iOS 13 |
| macOS | arm64, x86_64 | macOS 10.15 |
| Linux | x86_64, arm64 | glibc 2.35 |
| Windows | x64, arm64 | Windows 10 |
| Web | key-value `LocalDB` API on IndexedDB | — |

The query API needs the native engine: on the web, `LocalDatabase.open`
throws `unsupportedPlatform`.

## Benchmarks

Same data and operations for every engine: 10 000 rows
(`id, name, email, age, city, active`) with an index on `(city, age)`. Each
cell is the median of 3 rounds, measured from Dart in a profile (AOT) build
of the [benchmark app](benchmark/) on an Apple M1 Max, macOS 26.7, Flutter
3.47.5. Rows are grouped by what a commit guarantees.

| Engine | Durability | Runs on | Insert 10k rows, 1 transaction (per row) | Insert, 1 transaction per row | Find by primary key | Indexed query, limit 50 | Indexed count | Update by key |
|---|---|---|---|---|---|---|---|---|
| flutter_local_db 2.0 (full) | data and metadata flushed per commit | database isolate | 6.4 µs | 10.65 ms | 29.7 µs | 101.5 µs | 64.5 µs | 10.63 ms |
| SQLite 3.53.4 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | calling isolate | 2.2 µs | 5.14 ms | 4.1 µs | 42.4 µs | 49.4 µs | 5.30 ms |
| drift 2 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | background isolate | 3.2 µs | 5.09 ms | 43.9 µs | 138.1 µs | 95.6 µs | 5.40 ms |
| flutter_local_db 2.0 (no_meta_sync) | data flushed per commit | database isolate | 6.5 µs | 5.00 ms | 33.6 µs | 108.7 µs | 70.5 µs | 5.35 ms |
| flutter_local_db 2.0 (no_sync) | no flush per commit | database isolate | 5.3 µs | 77.0 µs | 36.6 µs | 109.3 µs | 70.0 µs | 72.9 µs |
| SQLite 3.53.4 (synchronous=OFF) | no flush per commit (WAL) | calling isolate | 1.6 µs | 26.2 µs | 3.5 µs | 41.0 µs | 47.4 µs | 32.8 µs |
| Hive CE 2 | no flush per write | calling isolate | 2.3 µs | 40.6 µs | 0.5 µs | 18.1 µs | 468.5 µs | 48.4 µs |
| Sembast 3 | no flush per write | calling isolate | 37.5 µs | 133.7 µs | 1.5 µs | 70.2 µs | 1.38 ms | 139.2 µs |

How to read it:

- **Where the work runs decides the small operations.** sqlite3, Hive CE and
  Sembast run on the calling isolate: a lookup costs microseconds, and a slow
  query or a flush blocks the UI for as long as it takes. flutter_local_db and
  drift hand every call to another isolate, which costs a round trip of about
  30 µs here and never blocks the UI. Against drift, the same design,
  flutter_local_db is faster on lookups, indexed queries and counts.
- **A durable LMDB commit flushes twice** (data, then the metadata page);
  SQLite in WAL mode flushes once. `noMetaSync` flushes once and matches it.
- **Hive CE and Sembast keep every row in memory.** Lookups are fast, and
  queries and counts scan all the rows.

Reproduce with `cd benchmark && flutter drive --profile -d macos --driver
test_driver/integration_test.dart --target integration_test/benchmark_test.dart`
(any device works; the table is saved to `benchmark/build/benchmark.md`).

## Key-value API

`LocalDB` is the 1.x API: string keys and JSON values, on every platform
including the web (IndexedDB).

```dart
await LocalDB.init();
await LocalDB.Post('user-1', {'name': 'Ana'});
final user = await LocalDB.GetById('user-1'); // LocalDbResult<LocalDbModel?, ErrorLocalDb>
await LocalDB.Put('user-1', {'name': 'Ana María'});
await LocalDB.Delete('user-1');
final all = await LocalDB.GetAll();
```

Results are `LocalDbResult` (`Ok` or `Err`), handled with `when`, `isOk` or
`unwrapOr`. `LocalDbModel.createdAt` and `updatedAt` are not stored: keep your
own timestamps in the data.

## Migrating from 1.x

2.0 stores data with LMDB 1.0, which cannot read the files of 1.x. Export with
`LocalDB.exportAll()` from a version of your app on 1.6, then import with
`LocalDB.importAll()` in 2.0: see [MIGRATION.md](MIGRATION.md).

## Roadmap

Not in 2.0, planned for later versions:

- Offline-first sync: a change log written in the same commit as each row,
  acknowledged by revision, with tombstones and conflict policies.
- Joins, associations and `GROUP BY` aggregates.
- A binary wire format and handles for the C ABI (the protocol is versioned,
  so the public API stays).
- Schema files with generated table classes.
- The query API on the web.

## License

MIT. See [LICENSE](LICENSE).
