// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              FFI BINDINGS                                    ║
// ║                    Foreign Function Interface Definitions                    ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: ffi_bindings.dart                                                   ║
// ║  Purpose: FFI type definitions and function signatures                      ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Defines all FFI type definitions and function signatures for             ║
// ║    interfacing with the Rust LMDB backend. Provides type-safe              ║
// ║    bindings for all database operations.                                    ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Type-safe FFI function signatures                                       ║
// ║    • Platform-agnostic type definitions                                      ║
// ║    • Memory management helpers                                               ║
// ║    • Pointer safety utilities                                                ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// FFI type definitions for database operations
///
/// These typedefs provide type-safe bindings to the Rust LMDB backend,
/// ensuring proper parameter types and return values for all operations.

/// Initialize database with given path
///
/// Returns: Database handle pointer or null on failure
/// Parameters: [path] - UTF-8 encoded database path
typedef CreateDbNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef CreateDb = Pointer<Void> Function(Pointer<Utf8> path);

/// Store key-value pair in database
///
/// Returns: 1 for success, 0 for failure
/// Parameters: [db] - Database handle, [key] - Record key, [value] - JSON data
typedef PutNative =
    Int32 Function(Pointer<Void> db, Pointer<Utf8> key, Pointer<Utf8> value);
typedef Put =
    int Function(Pointer<Void> db, Pointer<Utf8> key, Pointer<Utf8> value);

/// Retrieve value by key from database
///
/// Returns: JSON string pointer or null if not found
/// Parameters: [db] - Database handle, [key] - Record key to retrieve
typedef GetNative = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Get = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> key);

/// Delete record by key from database
///
/// Returns: 1 for success, 0 for failure
/// Parameters: [db] - Database handle, [key] - Record key to delete
typedef DeleteNative = Int32 Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Delete = int Function(Pointer<Void> db, Pointer<Utf8> key);

/// Check if key exists in database
///
/// Returns: 1 if exists, 0 if not found
/// Parameters: [db] - Database handle, [key] - Record key to check
typedef ExistsNative = Int32 Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Exists = int Function(Pointer<Void> db, Pointer<Utf8> key);

/// Get all keys from database
///
/// Returns: JSON array string of all keys or null on failure
/// Parameters: [db] - Database handle
typedef GetAllKeysNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetAllKeys = Pointer<Utf8> Function(Pointer<Void> db);

/// Get all key-value pairs from database
///
/// Returns: JSON object string of all data or null on failure
/// Parameters: [db] - Database handle
typedef GetAllNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetAll = Pointer<Utf8> Function(Pointer<Void> db);

/// Get database statistics
///
/// Returns: JSON string with database stats or null on failure
/// Parameters: [db] - Database handle
typedef GetStatsNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetStats = Pointer<Utf8> Function(Pointer<Void> db);

/// Clear all data from database
///
/// Returns: 1 for success, 0 for failure
/// Parameters: [db] - Database handle
typedef ClearNative = Int32 Function(Pointer<Void> db);
typedef Clear = int Function(Pointer<Void> db);

/// Close database and free resources
///
/// Returns: void
/// Parameters: [db] - Database handle to close
typedef CloseDbNative = Void Function(Pointer<Void> db);
typedef CloseDb = void Function(Pointer<Void> db);

/// Free string memory allocated by Rust
///
/// Returns: void
/// Parameters: [ptr] - String pointer to free
typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeString = void Function(Pointer<Utf8> ptr);

/// Container for all FFI function bindings
///
/// Provides organized access to all native function bindings with
/// type safety and memory management helpers.
class LocalDbBindings {
  /// Database creation and management functions
  final CreateDb createDb;
  final CloseDb closeDb;
  final Clear clear;
  final GetStats getStats;

  /// Data manipulation functions
  final Put put;
  final Get get;
  final Delete delete;
  final Exists exists;

  /// Bulk operations
  final GetAllKeys getAllKeys;
  final GetAll getAll;

  /// Memory management
  final FreeString freeString;

  const LocalDbBindings({
    required this.createDb,
    required this.closeDb,
    required this.clear,
    required this.getStats,
    required this.put,
    required this.get,
    required this.delete,
    required this.exists,
    required this.getAllKeys,
    required this.getAll,
    required this.freeString,
  });

  /// Creates bindings from a dynamic library
  ///
  /// Looks up all required functions in the provided library and
  /// creates type-safe Dart bindings for them.
  ///
  /// Example:
  /// ```dart
  /// final lib = DynamicLibrary.open('path/to/library');
  /// final bindings = LocalDbBindings.fromLibrary(lib);
  /// ```
  factory LocalDbBindings.fromLibrary(DynamicLibrary lib) {
    return LocalDbBindings(
      createDb: lib.lookupFunction<CreateDbNative, CreateDb>('create_db'),
      closeDb: lib.lookupFunction<CloseDbNative, CloseDb>('close_db'),
      clear: lib.lookupFunction<ClearNative, Clear>('clear'),
      getStats: lib.lookupFunction<GetStatsNative, GetStats>('get_stats'),
      put: lib.lookupFunction<PutNative, Put>('put'),
      get: lib.lookupFunction<GetNative, Get>('get'),
      delete: lib.lookupFunction<DeleteNative, Delete>('delete'),
      exists: lib.lookupFunction<ExistsNative, Exists>('exists'),
      getAllKeys: lib.lookupFunction<GetAllKeysNative, GetAllKeys>(
        'get_all_keys',
      ),
      getAll: lib.lookupFunction<GetAllNative, GetAll>('get_all'),
      freeString: lib.lookupFunction<FreeStringNative, FreeString>(
        'free_string',
      ),
    );
  }
}

/// Utility functions for working with FFI pointers and memory
class FfiUtils {
  /// Converts a Dart string to a UTF-8 pointer
  ///
  /// The returned pointer must be freed with [freeDartString] to prevent memory leaks.
  ///
  /// Example:
  /// ```dart
  /// final ptr = FfiUtils.toCString('hello world');
  /// // Use ptr with FFI functions
  /// FfiUtils.freeDartString(ptr);
  /// ```
  static Pointer<Utf8> toCString(String str) {
    return str.toNativeUtf8();
  }

  /// Converts a UTF-8 pointer to a Dart string
  ///
  /// Safely handles null pointers by returning null.
  ///
  /// Example:
  /// ```dart
  /// final str = FfiUtils.fromCString(ptr);
  /// if (str != null) {
  ///   print('Got string: $str');
  /// }
  /// ```
  static String? fromCString(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }

  /// Frees a Dart-allocated UTF-8 string
  ///
  /// Use this for strings allocated with [toCString].
  /// Do NOT use this for strings returned by Rust functions.
  ///
  /// Example:
  /// ```dart
  /// final ptr = FfiUtils.toCString('hello');
  /// // ... use ptr ...
  /// FfiUtils.freeDartString(ptr);
  /// ```
  static void freeDartString(Pointer<Utf8> ptr) {
    if (ptr != nullptr) {
      malloc.free(ptr);
    }
  }

  /// Frees a Rust-allocated UTF-8 string
  ///
  /// Use this for strings returned by Rust functions.
  /// Requires the bindings to call the Rust free_string function.
  ///
  /// Example:
  /// ```dart
  /// final ptr = bindings.get(db, keyPtr);
  /// final str = FfiUtils.fromCString(ptr);
  /// FfiUtils.freeRustString(ptr, bindings);
  /// ```
  static void freeRustString(Pointer<Utf8> ptr, LocalDbBindings bindings) {
    if (ptr != nullptr) {
      bindings.freeString(ptr);
    }
  }

  /// Checks if a pointer is null
  ///
  /// Convenient helper for null pointer checks.
  static bool isNull(Pointer ptr) {
    return ptr == nullptr;
  }

  /// Checks if a pointer is not null
  ///
  /// Convenient helper for non-null pointer checks.
  static bool isNotNull(Pointer ptr) {
    return ptr != nullptr;
  }
}

/// Constants for FFI operations
class FfiConstants {
  /// Success return code from native functions
  static const int success = 1;

  /// Failure return code from native functions
  static const int failure = 0;

  /// Maximum key length in bytes
  static const int maxKeyLength = 511;

  /// Maximum value size in bytes (16MB)
  static const int maxValueSize = 16 * 1024 * 1024;

  /// Default database file permissions (0644)
  static const int defaultFileMode = 0x1A4;

  /// Default database directory permissions (0755)
  static const int defaultDirMode = 0x1ED;
}
