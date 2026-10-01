# Migrating to flutter_local_db 3.0

- [From 2.0 to 3.0](#from-20-to-30): one entry point, tables from your
  models, queries that run when awaited, `Result` everywhere.
- [From 1.x](#from-1x): 1.x files (LMDB 0.9) need an export from 1.6.

## From 2.0 to 3.0

The files of 2.0 open in 3.0 as they are (both use LMDB 1.0.2). What
changes is the Dart API.

### One entry point: `LocalDB`

`LocalDatabase` is gone. `LocalDB` opens the records of the key-value API
and the tables of the query API, in one file:

```dart
// 2.0
await LocalDB.init();
final db = await LocalDatabase.openNamed('app', tables: [users]);

// 3.0
final opened = await LocalDB.init(); // Result<(), DbError>
```

`LocalDB.init` takes an optional `path` (default: a `flutter_local_db`
directory in the documents directory on Android and iOS, the support
directory elsewhere) and `options` (`DbOptions`, formerly `LocalDbOptions`).
Tables are not listed: each defines itself the first time it is used. A
table first used inside a transaction answers `DbErrorCode.tableNotReady`;
`tables:` defines tables up front for that case. Transactions,
`atomicBatch` and `info` are on `LocalDB` too.

**Tables of 2.0 live in another file.** In 2.0, `LocalDatabase` opened its
own `<path>.lmdb`, apart from the key-value records. Copy those rows once
into the database of `LocalDB`:

```dart
final oldPath = '${(await getApplicationSupportDirectory()).path}/app';

// Listed here on purpose: a table belongs to the first database that
// defines it, and the old one, opened next, must not take `users`.
await LocalDB.init(tables: [users]);

final copied = await LocalDB.open(oldPath, tables: [users]).flatMap(
  (old) => users
      .all()
      .load(old)
      .flatMap((rows) => users.insert(rows).onConflictReplace())
      .flatMap((count) => old.close().map((_) => count)),
);
// Then delete '$oldPath.lmdb' once `copied` is Ok.
```

### Tables from your models

A table is no longer a class: it is one line built from the model the app
already has.

```dart
// 2.0
final class UsersTable extends Table<User> {
  UsersTable() : super('users');
  late final id = integer('id');
  late final city = text('city');
  late final age = integer('age');
  @override
  Column<Object> get primaryKey => id;
  @override
  List<Index> get indexes => [Index('by_city_age', [city, age])];
  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);
  @override
  Map<String, dynamic> toJson(User row) => row.toJson();
}

// 3.0, inside the model
static final table = DbTable<User>(
  'users',
  key: 'id',
  fromJson: User.fromJson,
  indexes: [Index(['city', 'age'])], // named by_city_age, as before
);
```

- The table lives in the model, as a `static` (`User.table`).
- `toJson` is implicit: the model's own `toJson()`. Pass `toJson:` only when
  the model names it otherwise.
- Columns become typed getters, as before (`users.city`), but you do not
  write them: enable the [db_dsl_lints](https://pub.dev/packages/db_dsl_lints)
  analyzer plugin (`plugins: db_dsl_lints: ^0.1.0` in
  `analysis_options.yaml`) and its quick fix *Write the query fields from
  the model* writes `extension UserFields on DbTable<User>` from the model's
  `toJson`, and flags it again when the model changes. Under it is
  `users.field<String>('city')`, which works for any type: enums (by name),
  `DateTime` (ISO 8601) and custom types with `encode:` / `decode:`.
- Indexes take field names. Without `name:`, an index is named after its
  fields (`by_city_age`, `unique_email`); give the 2.0 name to keep an
  existing index instead of rebuilding it.

**Dates stored by 2.0.** 2.0's `DateTimeColumn` stored UTC microseconds. In
3.0 a value is stored as your model writes it. To keep reading the
microseconds already stored, keep them in your model and say so on the
field:

```dart
extension UserFields on DbTable<User> {
  Field<DateTime> get createdAt => field(
    'created_at',
    encode: (date) => date.toUtc().microsecondsSinceEpoch,
    decode: (stored) => DateTime.fromMicrosecondsSinceEpoch(stored as int, isUtc: true),
  );
}
```

### Queries run when awaited

```dart
// 2.0
await users.insert([ana]).execute(db);
final adults = await users.filter(users.age.ge(18)).load(db);
final ana = await users.find(1).first(db);

// 3.0
await users.insert([ana]);
final adults = await users.filter(users.age.ge(18));
final ana = await users.find(1);
```

- Awaiting a query runs it on the database that opened its table, or on the
  transaction it is awaited in. `load(other)`, `execute(other)` and
  `first(other)` remain for another database of the app.
- `count()`, `exists()`, `sum(field)`, `avg`, `min`, `max`, `explain()`,
  `watch()` and `getResults()` take no database.
- Conditions combine with `.and()`, `.or()` and `.not()`; the operators
  `&`, `|` and `~` are gone.

### `Result` instead of exceptions

Every operation answers a `Result` (from result_controller): `Ok` with the
value, or `Err` with a `DbError`. `LocalDbException` and `LocalDbErrorCode`
are replaced by `DbError` and `DbErrorCode`, a sealed family
(`ConstraintError`, `SchemaError`, `TransactionError`, `StorageError`,
`EngineError`) to switch on:

```dart
// 2.0
try {
  await users.insert([ana]).execute(db);
} on LocalDbException catch (e) {
  if (e.code == LocalDbErrorCode.duplicateKey) showAlreadyExists();
}

// 3.0
switch (await users.insert([ana])) {
  case Ok():
    break;
  case Err(error: ConstraintError()):
    showAlreadyExists();
  case Err(:final error):
    report(error);
}
```

- `transaction` commits when its body answers `Ok` and rolls back on `Err`
  (in 2.0: on an exception). Queries awaited inside run on the transaction.
- The key-value API answers result_controller's `Result` instead of
  `LocalDbResult`; its methods and errors (`ErrorLocalDb`) are the same.
  `LocalDB.init` answers a `Result` instead of throwing.
- `LocalDbService` is no longer exported: `LocalDB` is the API.

## From 1.x

flutter_local_db 2.0 and 3.0 store data with **LMDB 1.0.2**. LMDB 1.0 cannot
read the files written by LMDB 0.9, which every 1.x version used, so the
database cannot be opened in place. Migrating means exporting from 1.x and
importing into 3.0. The steps below keep every record.

### 1. Ship 1.6 first: export while the app can still read

`LocalDB.exportAll()` exists since **1.6.0**. Release a version of your app on
flutter_local_db 1.6 that exports once and keeps the document somewhere 3.0
can read it, for example a file in the application support directory:

```dart
// App version on flutter_local_db ^1.6.0
final exported = await LocalDB.exportAll();
final json = exported.unwrapOr('');
if (json.isNotEmpty) {
  final dir = await getApplicationSupportDirectory();
  await File('${dir.path}/local_db_export.json').writeAsString(json);
}
```

The document (`LocalDbExport`) is plain JSON: every record's id and data. It
does not depend on the LMDB version.

### 2. Upgrade: detect, move aside, import

```yaml
dependencies:
  flutter_local_db: ^3.0.0
```

Opening a 1.x database answers `Err` with `DbErrorCode.legacyFormat` and
leaves the files untouched. Move them aside, open a fresh database and
import the document:

```dart
Future<Result<(), DbError>> openLocalDb() async {
  final opened = await LocalDB.init();

  if (opened case Err(error: DbError(code: DbErrorCode.legacyFormat))) {
    await LocalDB.moveLegacyDatabaseAside(); // keeps the old files as a backup
    final reopened = await LocalDB.init();
    final dir = await getApplicationSupportDirectory();
    final export = File('${dir.path}/local_db_export.json');

    if (await export.exists()) {
      await LocalDB.importAll(await export.readAsString());
    }

    return reopened;
  }

  return opened;
}
```

`importAll` writes each record with its id, replacing an existing record with
the same id, and answers how many records it imported.

### 3. Optional: move records to tables

The key-value API (`LocalDB.Post`, `GetById`, `Put`, `Delete`, `GetAll`,
`ClearData`) keeps working, and is the API on the web. On Android, iOS,
macOS, Linux and Windows, tables add indexes, queries and transactions. To
move records into a table:

```dart
final records = await LocalDB.GetAll();
final moved = await records.when<Future<Result<int, DbError>>>(
  ok: (all) => users
      .insert([for (final r in all) User.fromJson({'id': r.id, ...r.data})])
      .onConflictReplace(),
  err: (error) async => Err(DbError(DbErrorCode.storage, error.message)),
);
```

### Other changes since 1.x

- `ErrorLocalDb` implements `Exception`.
- `JsonSerializer` was removed; use `dart:convert`.
- The native library is bundled by a build hook: no CocoaPods, Gradle or CMake
  setup, and nothing to configure on Windows. Flutter 3.38 or later is
  required.
