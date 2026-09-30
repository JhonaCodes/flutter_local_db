# Migrating from 1.x to 2.0

flutter_local_db 2.0 stores data with **LMDB 1.0.2**. LMDB 1.0 cannot read the
files written by LMDB 0.9, which every 1.x version used, so a 2.0 app cannot
open a 1.x database in place. Migrating means exporting from 1.x and importing
into 2.0. The steps below keep every record.

## 1. Ship 1.6 first: export while the app can still read

`LocalDB.exportAll()` exists since **1.6.0**. Release a version of your app on
flutter_local_db 1.6 that exports once and keeps the document somewhere 2.0
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

## 2. Upgrade to 2.0: detect, move aside, import

```yaml
dependencies:
  flutter_local_db: ^2.0.0
```

Opening a 1.x database throws an error of type `legacyFormat` and leaves the
files untouched. Move them aside, open a fresh database and import the
document:

```dart
Future<void> openLocalDb() async {
  try {
    await LocalDB.init();
  } on ErrorLocalDb catch (e) {
    if (e.type != LocalDbErrorType.legacyFormat) rethrow;
    await LocalDB.moveLegacyDatabaseAside(); // keeps the old files as a backup
    await LocalDB.init();
    final dir = await getApplicationSupportDirectory();
    final export = File('${dir.path}/local_db_export.json');
    if (await export.exists()) {
      await LocalDB.importAll(await export.readAsString());
    }
  }
}
```

`importAll` writes each record with its id, replacing an existing record with
the same id, and returns how many records it imported.

## 3. Optional: move to the query API

The key-value API (`LocalDB.Post`, `GetById`, `Put`, `Delete`, `GetAll`,
`ClearData`) keeps working in 2.0 and is the API on the web. On Android, iOS,
macOS, Linux and Windows, `LocalDatabase` adds tables, indexes, queries and
transactions. To move records there, read them with `LocalDB.GetAll()` and
insert them into a table:

```dart
final records = (await LocalDB.GetAll()).unwrapOr([]);
await users
    .insert([for (final r in records) User.fromJson({'id': r.id, ...r.data})])
    .onConflictReplace()
    .execute(db);
```

The two APIs use separate files: `LocalDB` keeps its database, and each
`LocalDatabase.open(path: ...)` opens `<path>.lmdb`.

## Other changes

- `LocalDB.init()` throws the `ErrorLocalDb` itself (it wrapped it in a plain
  `Exception`), so `on ErrorLocalDb catch (e)` sees its `type`.
- `ErrorLocalDb` implements `Exception`.
- `JsonSerializer` was removed; use `dart:convert`.
- The native library is bundled by a build hook: no CocoaPods, Gradle or CMake
  setup, and nothing to configure on Windows. Flutter 3.38 or later is
  required.
