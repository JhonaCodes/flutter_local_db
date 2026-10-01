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
dart format lib test hook example/lib example/integration_test example/test_driver benchmark/lib
flutter test                                        # host tests, real engine
(cd example && flutter test integration_test/app_test.dart -d macos)  # any device, one file per run
(cd example && flutter drive --profile -d macos --driver test_driver/integration_test.dart --target integration_test/aot_bindings_test.dart)  # ahead of time
```

## Architecture

- **One entry point, `LocalDB`** (`lib/src/local_db.dart`): `init` opens the
  tables (a db_dsl `Database` on the bundled engine) and the key-value
  records (`LocalDbService` → `lib/src/core/`, not exported) in one file.
  Records are the 1.x API, with conditional imports for native
  (`core/native/`) and web (`core/web/`, IndexedDB).
- **Query API**: from [db_dsl](../db_dsl), re-exported. A model carries its
  table (`static final table = DbTable<T>('name', key: ..., fromJson:
  T.fromJson)`); tables define themselves on the database of `LocalDB.init`
  on first use (no list); queries run when awaited, on the database of the
  table or the transaction around them. Typed fields (`t.done`) are an
  `extension <T>Fields on DbTable<T>` written and checked by the
  db_dsl_lints analyzer plugin — check it with `dart analyze`, since
  `flutter analyze` does not report plugin diagnostics.
- **Native layer** (`lib/src/native/`): `bindings.dart` declares the C ABI
  with `@Native`, resolved against the code asset of `hook/build.dart`;
  db_dsl's `NativeWorker` runs every call on one worker isolate, which stops
  when the last database closes.
- **Native libraries** (`native/<os>/<architecture>/`): prebuilt, from an
  offline_first_core release. Replace them with `tool/update_native.sh
  <version>`, never by hand; the hook picks the file of the build target.

## Conventions

- No top-level functions or variables in `lib/`: `abstract final class` with
  static members. Entry points (`main` of the hook) are the exception.
- Everything committed is in English.
- Tests run against the real engine (the hook bundles the host library); do
  not mock the native layer.
