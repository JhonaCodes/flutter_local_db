# flutter_local_db

An embedded database for Flutter that stores the models your app already
has. One entry point, `LocalDB`: key-value records as simple as ever, and
tables with a query API modelled on [Diesel](https://diesel.rs) — indexes, a
query planner, joins, aggregates, transactions with savepoints and reactive
queries. The engine is
[offline_first_core](https://github.com/JhonaCodes/offline_first_core),
written in Rust on **LMDB 1.0.2**; the query language is
[db_dsl](https://pub.dev/packages/db_dsl).

```dart
await LocalDB.init();

final t = User.table;
await t.insert([ana, luis]);

final adults = await t
    .filter(t.city.eq('Lima').and(t.age.gt(30)))
    .order(t.age.desc())
    .limit(20); // Result<List<User>, DbError>
```

- **Your models, as they are.** A model carries its table in one line
  (`static final table = DbTable<User>(...)`) next to the `fromJson` and
  `toJson` it already has — the class your app decodes from its API. No
  table classes, no code generation, no macros.
- **Nothing to register.** `LocalDB.init()` takes no list of tables: each
  table defines itself the first time it is used.
- **Typed fields, written for you.** `t.city` and `t.age` come from an
  extension that the [db_dsl_lints](https://pub.dev/packages/db_dsl_lints)
  analyzer plugin writes from the model with one quick fix, and checks
  whenever the model changes.
- **Queries run when awaited**, on the database of the table or on the
  transaction around them: there is no `execute(db)` to write.
- **Indexes**: single, composite and unique, maintained in the same
  transaction as their rows and built over existing rows when added.
- **Queries**: `filter`, `orFilter`, `order`, `limit`, `offset`, `count`,
  `sum`, `avg`, `min`, `max`, projections, `groupBy` with `having`, inner and
  left joins, and `explain` to see the chosen index.
- **Transactions**: commit on `Ok`, rollback on `Err`, savepoints, read
  snapshots and atomic batches.
- **Reactive**: `watch` emits a query's rows again after every committed write
  to its table.
- **`Result` everywhere**: `Ok` with the value or `Err` with a typed
  `DbError`; nothing throws for an outcome.
- **Platforms**: Android, iOS, macOS, Linux and Windows. The library ships
  prebuilt and a build hook bundles it: nothing to configure. The web has the
  key-value API.
- **Off the UI isolate**: every call runs on a database isolate.

## Install

```yaml
dependencies:
  flutter_local_db: ^3.0.0
```

Flutter 3.38 or later (build hooks). There is no platform setup: the build
hook adds the native library of each target (Android ABIs, iOS device and
simulator, macOS, Linux and Windows on x64 and arm64) to the app.

## Open

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final opened = await LocalDB.init();

  runApp(opened.when(ok: (_) => const App(), err: (error) => StartupError(error)));
}
```

`LocalDB.init` opens the database of the app (in a `flutter_local_db`
directory of the documents directory on Android and iOS, the support
directory elsewhere; or at `path:`). Records and tables share one file.

Tables are not listed: a table defines itself the first time one of its
queries is awaited — a new table is created, and indexes added to or
removed from an existing one are built or dropped — and its queries run on
this database from then on. Concurrent first uses define it once.

A table used for the first time **inside a transaction** answers
`Err(DbErrorCode.tableNotReady)`: defining needs the database to itself,
which the transaction holds. Use the table once before (a screen usually
watches it first), or define it up front with
`LocalDB.init(tables: [users, posts])`, which also builds its indexes at
start-up.

## Records: key-value

No tables needed, on every platform including the web:

```dart
await LocalDB.init();

await LocalDB.Post('settings', {'theme': 'dark'});
final settings = await LocalDB.GetById('settings'); // Ok(null) when missing
await LocalDB.Put('settings', {'theme': 'light'});
await LocalDB.Delete('settings');
final all = await LocalDB.GetAll();
```

## Tables from your models

```dart
final class User {
  const User({this.id, required this.name, required this.city, required this.age});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int?,
    name: json['name'] as String,
    city: json['city'] as String,
    age: json['age'] as int,
  );

  // The table of this model: its name, its key and how to read a row.
  static final table = DbTable<User>(
    'users',
    key: 'id',
    fromJson: User.fromJson,
    autoIncrement: true,                 // optional: a null id is generated on insert
    indexes: [
      Index(['city', 'age']),            // optional
      Index.unique(['name']),
    ],
  );

  final int? id;
  final String name;
  final String city;
  final int age;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'city': city, 'age': age};
}
```

- The table is a `static` of the model: a query has no instance to inherit
  from, and Dart has no static inheritance, so this is the closest to "the
  class is the table" — without a global.
- `fromJson` is the one thing a table needs: Dart cannot call a constructor
  through a type, so it is passed once.
- `toJson` is implicit: a row is stored as your model writes itself (its
  `toJson()`, the method `jsonEncode` uses), with nested models, dates and
  enums converted the same way. Pass `toJson: (user) => user.toMap()` only
  when your model names it otherwise.
## Typed fields

Queries name fields as getters of the table, with the type the model
stores:

```dart
/// The fields of `User` for queries, read from its `toJson`.
extension UserFields on DbTable<User> {
  /// The stored `id`.
  Field<int> get id => field('id');

  /// The stored `name`.
  Field<String> get name => field('name');

  /// The stored `city`.
  Field<String> get city => field('city');

  /// The stored `age`.
  Field<int> get age => field('age');
}

final t = User.table;
await t.filter(t.city.eq('Lima'));  // t.cty or t.age.eq('x') do not compile
```

**You do not type this extension.** Enable the analyzer plugin in
`analysis_options.yaml` (not in `pubspec.yaml`) and restart the analysis
server:

```yaml
plugins:
  db_dsl_lints: ^0.1.0
```

Then `DbTable<User>(...)` is underlined — *'User' stores fields its table
cannot query: id, name, city, age* — and its quick fix, *Write the query
fields from the model* (Ctrl+. / ⌘. in VS Code, Alt+Enter in Android
Studio), writes the extension after the model. When the model gains,
renames or retypes a field, the table or the stale getter is flagged again
and one quick fix rewrites it. It is plain code in your file: no
`build_runner`, no `.g.dart`.

In CI, run `dart analyze` (it works in Flutter projects): `flutter analyze`
does not report plugin diagnostics yet (Flutter 3.47). See
[db_dsl_lints](https://pub.dev/packages/db_dsl_lints) for every check.

A field is a path in the stored rows, compared as a Dart type;
`field<V>(path)` is the building block of those getters and works on its
own too:

```dart
final zip = users.field<String>('address.zip');   // nested
final status = orders.field<Status>('status');    // enums, by name
final placed = orders.field<DateTime>('placed');  // ISO 8601, as toJson writes it
final total = orders.field<Money>(                // any type, as your model stores it
  'total',
  encode: (money) => money.cents,
  decode: (stored) => Money(stored as int),
);
```

ISO 8601 dates sort correctly when they are all UTC with the same
precision: store `toUtc()` dates, or numbers, to sort or range over them.

## Query

The examples below write `city`, `age`, `name`… for the typed fields of the
table (`users.city`, `users.age`, `users.name`).

| Diesel (Rust) | flutter_local_db |
|---|---|
| `users.filter(city.eq("Lima"))` | `users.filter(city.eq('Lima'))` |
| `.and(...)` / `.or(...)` / `not(...)` | `.and(...)` / `.or(...)` / `.not()` |
| `.or_filter(...)` | `.orFilter(...)` |
| `ne`, `gt`, `ge`, `lt`, `le` | `ne`, `gt`, `ge`, `lt`, `le` |
| `eq_any`, `ne_all` | `eqAny`, `neAll` |
| `between`, `not_between` | `between`, `notBetween` |
| `is_null`, `is_not_null` | `isNull()`, `isNotNull()` |
| `like`, `ilike` | `like`, `ilike` (text fields) |
| `.order(age.desc())`, `.then_order_by(...)` | `.order(age.desc())`, `.thenOrderBy(...)` |
| `.limit(n)`, `.offset(n)` | `.limit(n)`, `.offset(n)` |
| `.load(conn)`, `.first(conn)` | `await query`, `.first()` |
| `.count().get_result(conn)` | `.count()` |
| `users.find(id).first(conn)` | `await users.find(id)` |
| `sum`, `avg`, `min`, `max` | `.sum(field)`, `.avg(field)`, `.min(field)`, `.max(field)` |
| `group_by`, `having` | `.groupBy([city]).count('people').having(...)` |
| `inner_join`, `left_join` | `.innerJoin(posts, on: id, equals: authorId)`, `.leftJoin(...)` |

```dart
final page = await users
    .filter(city.eqAny(['Lima', 'Bogotá']))
    .orFilter(age.lt(18))
    .order(name.asc())
    .limit(50)
    .offset(100);

final ana = await users.find(1); // Ok(null) when missing
final average = await users.filter(city.eq('Lima')).avg(age);
```

Comparisons follow SQL: a value only compares with values of its kind, and
`NULL` or a missing field matches no comparison (use `isNull()`). Without
`order`, the order of the rows is unspecified.

## Write

```dart
await users.insert([ana, luis]);                  // the number of rows
final saved = await users.insert([nuevo]).getResults(); // rows with generated ids
await users.insert([ana]).onConflictDoNothing();
await users.insert([ana]).onConflictReplace();

await users.update().filter(city.eq('Lima')).set(age, 40);
await posts.update().filter(postId.eq('p1')).increment(views, 1);

await users.delete().filter(age.lt(18));

// Fails, changing nothing, unless exactly one row matches:
await users.delete().filter(id.eq(7)).expectAffectedRows(1);
```

An insert of an existing primary key answers `Err` with `duplicateKey`, and
a duplicate value of a unique index with `uniqueViolation`, unless
`onConflictDoNothing` or `onConflictReplace` says otherwise. Every statement
is atomic.

## Transactions

```dart
final result = await LocalDB.transaction<int>((tx) async {
  // Awaited inside, so they run on the transaction.
  final inserted = await users.insert([ana]);

  if (inserted case Err(:final error)) {
    return Err(error); // everything rolls back
  }

  // A savepoint: when it answers Err, only its own writes are undone.
  await tx.savepoint((_) => users.update().filter(id.eq(2)).set(age, 30));

  return users.all().count(); // sees the transaction's writes
}); // committed here when the body answered Ok

final snapshot = await LocalDB.readTransaction((tx) async {
  // One consistent view, while other writes go on.
  return users.all().count();
});

await LocalDB.atomicBatch([
  users.insert([ana]),
  users.update().filter(id.eq(2)).set(age, 30),
]); // all or nothing, in one round trip
```

- A write that fails inside a transaction makes it rollback-only: the commit
  answers `transactionAborted` even when the error was handled. Put
  recoverable work in a `savepoint`.
- Other writes of the database wait until the transaction ends. A transaction
  idle for longer than `idleTimeout` (30 s by default) is rolled back.

## Watch

```dart
StreamBuilder(
  stream: users.filter(city.eq('Lima')).order(name.asc()).watch(),
  builder: (context, snapshot) => switch (snapshot.data) {
    Ok(:final data) => UserList(users: data),
    _ => const SizedBox.shrink(),
  },
);
```

`watch` emits the rows at once and again after every committed write to the
table.

## Indexes and `explain`

The planner looks rows up by primary key, or picks the index with the most
leading `eq` fields plus a range on the next one, or an index that already
follows `order` (stopping after `limit`). `explain` shows the choice:

```dart
final plan = await users.filter(city.eq('Lima').and(age.gt(30))).order(age.desc()).explain();
// {table: users, access: index_scan, index: by_city_age,
//  descending: true, presorted: true, exact: true}
```

`exact: true` means the index alone decides the filter: rows are not checked
again, and `count` reads no row at all. Add an index when `explain` reports
`full_scan` for a query on a large table.

## Another database

Tables belong to the database of `LocalDB.init`. Another database of the
app is the exception: it defines the tables it is given, and is named on the
queries that go there:

```dart
switch (await LocalDB.open('${dir.path}/archive', tables: [users])) {
  case Ok(data: final archive):
    await users.insert([old]).execute(archive);
    final archived = await users.all().load(archive);
  case Err(:final error):
    report(error);
}
```

A table belongs to the first database that defines it. Give a table to
another database only after the app's database has used it (or list it in
`LocalDB.init(tables: [...])`); otherwise it stays with the other one, and
its unnamed queries go there.

## Durability

```dart
await LocalDB.init(
  options: const DbOptions(durability: Durability.noMetaSync),
);
```

| `Durability` | A committed transaction after a power loss |
|---|---|
| `full` (default) | is kept: data and metadata are flushed on every commit |
| `noMetaSync` | may be undone (the last one), never corrupted; one flush per commit instead of two |
| `noSync` | the last ones may be undone; flushing is left to the OS. An app crash loses nothing |

On Apple hardware a flush is `F_FULLFSYNC`, which takes milliseconds: group
writes in a transaction or `atomicBatch` rather than committing row by row.

The database file grows as needed: `DbOptions.initialSize` (64 MiB) and
`maxSize` (16 GiB) are address space reserved for the memory map, not disk.

## Errors

Every operation answers a `Result`. `DbError` is a sealed family, so a
`switch` handles every kind of failure:

```dart
switch (await users.insert([ana])) {
  case Ok(:final data):
    showSaved(data);
  case Err(error: ConstraintError()):   // duplicate key, unique index
    showAlreadyExists();
  case Err(error: TransactionError()):  // closed, aborted, expired
    retry();
  case Err(:final error):               // schema, storage, engine
    report(error);
}
```

`error.code` (`DbErrorCode`) names the exact cause: `duplicateKey`,
`uniqueViolation`, `affectedRowsMismatch`, `rowMapping`, `keyTooLarge`,
`mapFull`, `legacyFormat`, `notOpen`, `tableNotReady` and the rest listed in
the API docs.

## Platforms

| Platform | Architectures | Minimum |
|---|---|---|
| Android | arm64-v8a, armeabi-v7a, x86_64, x86 (16 KB pages) | API 21 |
| iOS | device arm64; simulator arm64, x86_64 | iOS 13 |
| macOS | arm64, x86_64 | macOS 10.15 |
| Linux | x86_64, arm64 | glibc 2.35 |
| Windows | x64, arm64 | Windows 10 |
| Web | key-value records on IndexedDB | — |

Tables need the native engine: on the web, `LocalDB.init(tables: ...)`
answers `unsupportedPlatform`, and a table query answers `notOpen`.

## Benchmarks

Same data and operations for every engine: 10 000 rows
(`id, name, email, age, city, active`) with an index on `(city, age)`. Each
cell is the median of 3 rounds, measured from Dart in a profile (AOT) build
of the [benchmark app](benchmark/) on an Apple M1 Max, macOS 26.7, Flutter
3.47.5. Rows are grouped by what a commit guarantees.

| Engine | Durability | Runs on | Insert 10k rows, 1 transaction (per row) | Insert, 1 transaction per row | Find by primary key | Indexed query, limit 50 | Indexed count | Update by key |
|---|---|---|---|---|---|---|---|---|
| flutter_local_db 3.0 (full) | data and metadata flushed per commit | database isolate | 7.1 µs | 9.28 ms | 45.8 µs | 107.5 µs | 68.9 µs | 9.37 ms |
| SQLite 3.53.4 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | calling isolate | 2.7 µs | 5.02 ms | 3.7 µs | 46.0 µs | 48.9 µs | 4.95 ms |
| drift 2 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | background isolate | 3.7 µs | 4.89 ms | 53.2 µs | 154.1 µs | 102.9 µs | 5.08 ms |
| flutter_local_db 3.0 (no_meta_sync) | data flushed per commit | database isolate | 6.4 µs | 5.10 ms | 48.0 µs | 112.3 µs | 70.8 µs | 5.55 ms |
| flutter_local_db 3.0 (no_sync) | no flush per commit | database isolate | 5.8 µs | 73.2 µs | 42.2 µs | 110.3 µs | 71.6 µs | 69.9 µs |
| SQLite 3.53.4 (synchronous=OFF) | no flush per commit (WAL) | calling isolate | 1.6 µs | 25.0 µs | 3.4 µs | 37.9 µs | 47.4 µs | 31.1 µs |
| Hive CE 2 | no flush per write | calling isolate | 2.3 µs | 61.4 µs | 0.4 µs | 17.8 µs | 445.5 µs | 42.5 µs |
| Sembast 3 | no flush per write | calling isolate | 41.1 µs | 149.6 µs | 1.3 µs | 69.3 µs | 1.40 ms | 147.9 µs |

How to read it:

- **Where the work runs decides the small operations.** sqlite3, Hive CE and
  Sembast run on the calling isolate: a lookup costs microseconds, and a slow
  query or a flush blocks the UI for as long as it takes. flutter_local_db and
  drift hand every call to another isolate, which costs a round trip of tens
  of microseconds and never blocks the UI. Against drift, the same design,
  flutter_local_db is faster on lookups, indexed queries and counts.
- **A durable LMDB commit flushes twice** (data, then the metadata page);
  SQLite in WAL mode flushes once. `noMetaSync` flushes once and matches it.
- **Hive CE and Sembast keep every row in memory.** Lookups are fast, and
  queries and counts scan all the rows.

Reproduce with `cd benchmark && flutter drive --profile -d macos --driver
test_driver/integration_test.dart --target integration_test/benchmark_test.dart`
(any device works; the table is saved to `benchmark/build/benchmark.md`).

## Migrating

- From **2.0**: one entry point (`LocalDB`), tables from your models,
  queries that run when awaited, `Result` instead of exceptions.
- From **1.x**: LMDB 1.0 cannot read the files of 1.x; export with
  `LocalDB.exportAll()` from a version of your app on 1.6, then import with
  `LocalDB.importAll()`.

Both are in [MIGRATION.md](MIGRATION.md).

## Roadmap

Not in 3.0, planned for later versions:

- Offline-first sync: a change log written in the same commit as each row,
  acknowledged by revision, with tombstones and conflict policies.
- A binary wire format and handles for the C ABI (the protocol is versioned,
  so the public API stays).
- Tables on the web.

## License

MIT. See [LICENSE](LICENSE).
