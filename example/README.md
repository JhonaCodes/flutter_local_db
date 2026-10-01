# flutter_local_db example

A task list built on `LocalDB` and the Diesel-style API of
[flutter_local_db](https://pub.dev/packages/flutter_local_db):

- [`lib/tasks.dart`](lib/tasks.dart): the `Task` model (a plain class with
  `fromJson` and `toJson`) carrying its table (auto-increment key, an index
  on `(done, id)`), its typed fields `TaskFields` — written by the quick fix
  of the db_dsl_lints plugin, enabled in `analysis_options.yaml` — and every
  query the app runs, awaited without a database to name. No table is
  listed: `LocalDB.init()` opens the database, and `tasks` defines itself
  on first use.
- [`lib/main.dart`](lib/main.dart): the UI, which renders `watch` streams.

```sh
flutter run -d macos   # or ios, android, linux, windows
```

`dart analyze` checks `TaskFields` against `Task` (`flutter analyze` does
not report plugin diagnostics yet).

`integration_test/app_test.dart` runs the tables and the key-value records
against the library bundled in the app, on any device:

```sh
flutter test integration_test -d macos
```
