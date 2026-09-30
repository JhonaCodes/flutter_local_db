# CLAUDE.md

Guidance for Claude Code (claude.ai/code) in this repository.

## Project

`flutter_local_db` is an embedded database for Flutter. Native platforms
(Android, iOS, macOS, Linux, Windows) call the Rust engine
[offline_first_core](https://github.com/JhonaCodes/offline_first_core) (LMDB
1.0.2 through natdb) over `dart:ffi`; the web has only the key-value API, on
IndexedDB.

## Commands

```bash
flutter pub get
flutter analyze
dart format lib test hook example/lib example/integration_test benchmark/lib
flutter test                                        # host tests, real engine
(cd example && flutter test integration_test -d macos)  # any device
```

## Architecture

- **Query API** (`lib/src/dsl/`, `lib/src/database/`): `Table<T>` with typed
  `Column`s builds JSON statements of the engine's wire protocol;
  `LocalDatabase` runs them, adds transactions, savepoints, `watch` and a
  write lock that keeps the worker isolate from deadlocking.
- **Key-value API** (`LocalDB`, `LocalDbService`, `lib/src/core/`): the 1.x
  API, with conditional imports for native (`core/native/`) and web
  (`core/web/`).
- **Native layer** (`lib/src/native/`): `bindings.dart` declares the C ABI
  with `@Native`, resolved against the code asset of `hook/build.dart`;
  `NativeWorker` runs every call on one worker isolate.
- **Native libraries** (`native/<os>/<architecture>/`): prebuilt, from an
  offline_first_core release. Replace them with `tool/update_native.sh
  <version>`, never by hand; the hook picks the file of the build target.

## Conventions

- No top-level functions or variables in `lib/`: `abstract final class` with
  static members. Entry points (`main` of the hook) are the exception.
- Everything committed is in English.
- Tests run against the real engine (the hook bundles the host library); do
  not mock the native layer.
