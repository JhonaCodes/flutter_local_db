# flutter_local_db example

A task list built on the Diesel-style API of
[flutter_local_db](https://pub.dev/packages/flutter_local_db):

- [`lib/tasks.dart`](lib/tasks.dart): the `Task` model, the `TasksTable`
  definition (auto-increment key, an index on `(done, created_at)`) and every
  query the app runs.
- [`lib/main.dart`](lib/main.dart): the UI, which renders `watch` streams.

```sh
flutter run -d macos   # or ios, android, linux, windows
```

`integration_test/app_test.dart` runs the query API and the key-value API
against the library bundled in the app, on any device:

```sh
flutter test integration_test -d macos
```
