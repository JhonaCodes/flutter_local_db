# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`flutter_local_db` is a cross-platform local database library for Flutter/Dart. Native platforms (Android, iOS, macOS, Linux, Windows) use **Rust + LMDB via FFI**. Web uses **IndexedDB**. The library exposes a REST-like API (Post/Get/Put/Delete) with Rust-style `Result<T, E>` error handling.

## Commands

```bash
# Install dependencies
flutter pub get

# Run unit tests
flutter test test/flutter_local_db_test.dart

# Run integration tests (requires a device/platform)
flutter test integration_test/ -d macos    # or: ios, android, linux, windows, chrome

# Lint
dart analyze

# Format
dart format lib/ test/
```

## Architecture

### Two API Layers

1. **`LocalDB`** (`lib/src/local_db.dart`) — Legacy static API. Wraps `LocalDbService` for backward compatibility. Methods use PascalCase: `Post()`, `GetById()`, `Put()`, `Delete()`, `GetAll()`, `ClearData()`.
2. **`LocalDbService`** (`lib/src/services/local_db_service.dart`) — Modern service API. Created via `LocalDbService.initialize()`. Preferred for new code.

Both return `LocalDbResult<T, E>` (sealed Ok/Err type) from `lib/src/models/local_db_result.dart`.

### Platform Abstraction (Conditional Imports)

Platform-specific code uses Dart conditional imports (`if (dart.library.js_interop)`). Each abstraction has three files:

| Concern | Factory (entry point) | Native impl | Web impl |
|---|---|---|---|
| Database operations | `core/database_core.dart` | `core/native/database_core_impl.dart` | `core/web/database_core_impl.dart` |
| Initialization | `core/initializer.dart` | `core/native/initializer_impl.dart` | `core/web/initializer_impl.dart` |
| Path resolution | `utils/path_helper.dart` | `utils/native/path_helper_impl.dart` | `utils/web/path_helper_impl.dart` |

The factory files export platform-specific implementations and should not contain logic themselves.

### FFI Layer (Native only)

- **`core/ffi_functions.dart`** — `FfiFunction` enum mapping Rust function names
- **`core/ffi_bindings.dart`** — Type-safe function pointer bindings (`LocalDbBindings`)
- **`core/library_loader.dart`** — Platform-specific native library (.so/.dylib/.dll) loading

The Rust backend crate is `offline_first_core`. Communication between Dart and Rust is JSON-based via `Pointer<Utf8>`.

### Data Model

`LocalDbModel` stores: `id`, `data` (Map<String, dynamic>), `createdAt`, `updatedAt`, `contentHash`.

### Error Handling

`LocalDbResult<T, E>` is a sealed class with `Ok` and `Err` subtypes. Use `when()` for pattern matching or `isOk`/`isErr` for checks. `ErrorLocalDb` has typed variants: initialization, notFound, validation, database, serialization, ffi, platform, unknown.

## Key Conventions

- The library is a **Flutter FFI plugin** — `pubspec.yaml` declares `ffiPlugin: true` for all native platforms
- Web platform is **not** declared in pubspec flutter plugin section (uses conditional imports only)
- Dart SDK `^3.10.0`, Flutter `>=3.35.0`
- Uses `package:logger_rs` for logging (Rust-style `Log.i()`, `Log.e()`, etc.)
- Current branch `web_local_db` is adding web (IndexedDB) support
