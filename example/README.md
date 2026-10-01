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
against the library bundled in the app, on any device (one file per run: a
second app launched by the same run loses its debug connection on desktop):

```sh
flutter test integration_test/app_test.dart -d macos
```

`integration_test/aot_bindings_test.dart` checks that every binding resolves
in an ahead-of-time build of a program that only takes their addresses;
run it, and the app, as they ship:

```sh
flutter drive --profile -d macos --driver test_driver/integration_test.dart --target integration_test/aot_bindings_test.dart
flutter drive --profile -d macos --driver test_driver/integration_test.dart --target integration_test/app_test.dart
```
