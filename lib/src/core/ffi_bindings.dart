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
import 'ffi_functions.dart';

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

/// Push data to database (insert new record)
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle, [json] - JSON data to insert
typedef PushDataNative =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> json);
typedef PushData = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> json);

/// Retrieve value by ID from database
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle, [id] - Record ID to retrieve
typedef GetByIdNative =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> id);
typedef GetById = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> id);

/// Delete record by ID from database
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle, [id] - Record ID to delete
typedef DeleteByIdNative =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> id);
typedef DeleteById = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> id);

/// Update existing record in database
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle, [json] - JSON data with updated record
typedef UpdateDataNative =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> json);
typedef UpdateData =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> json);

/// Clear all records from database
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle
typedef ClearAllRecordsNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef ClearAllRecords = Pointer<Utf8> Function(Pointer<Void> db);

/// Get all key-value pairs from database
///
/// Returns: JSON object string of all data or null on failure
/// Parameters: [db] - Database handle
typedef GetAllNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetAll = Pointer<Utf8> Function(Pointer<Void> db);

/// Reset database to clean state with new name
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle, [name] - New database name
typedef ResetDatabaseNative =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> name);
typedef ResetDatabase =
    Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> name);

/// Close database connection
///
/// Returns: JSON response string with result
/// Parameters: [db] - Database handle
typedef CloseDatabaseNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef CloseDatabase = Pointer<Utf8> Function(Pointer<Void> db);

/// Container for all FFI function bindings
///
/// Provides organized access to all native function bindings with
/// type safety and memory management helpers.
class LocalDbBindings {
  /// Database creation and management functions
  final CreateDb createDb;
  final CloseDatabase closeDatabase;
  final ResetDatabase resetDatabase;

  /// Data manipulation functions
  final PushData pushData;
  final GetById getById;
  final DeleteById deleteById;
  final UpdateData updateData;

  /// Bulk operations
  final GetAll getAll;
  final ClearAllRecords clearAllRecords;

  const LocalDbBindings({
    required this.createDb,
    required this.closeDatabase,
    required this.resetDatabase,
    required this.pushData,
    required this.getById,
    required this.deleteById,
    required this.updateData,
    required this.getAll,
    required this.clearAllRecords,
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
      createDb: lib.lookupFunction<CreateDbNative, CreateDb>(
        FfiFunction.createDb.fn,
      ),
      closeDatabase: lib.lookupFunction<CloseDatabaseNative, CloseDatabase>(
        FfiFunction.closeDatabase.fn,
      ),
      resetDatabase: lib.lookupFunction<ResetDatabaseNative, ResetDatabase>(
        FfiFunction.resetDatabase.fn,
      ),
      pushData: lib.lookupFunction<PushDataNative, PushData>(
        FfiFunction.pushData.fn,
      ),
      getById: lib.lookupFunction<GetByIdNative, GetById>(
        FfiFunction.getById.fn,
      ),
      deleteById: lib.lookupFunction<DeleteByIdNative, DeleteById>(
        FfiFunction.deleteById.fn,
      ),
      updateData: lib.lookupFunction<UpdateDataNative, UpdateData>(
        FfiFunction.updateData.fn,
      ),
      getAll: lib.lookupFunction<GetAllNative, GetAll>(FfiFunction.getAll.fn),
      clearAllRecords: lib
          .lookupFunction<ClearAllRecordsNative, ClearAllRecords>(
            FfiFunction.clearAllRecords.fn,
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

  /// Converts a Rust response string and frees memory
  ///
  /// Use this for strings returned by Rust functions.
  /// The Rust side automatically handles memory management.
  ///
  /// Example:
  /// ```dart
  /// final ptr = bindings.pushData(db, jsonPtr);
  /// final response = FfiUtils.fromCString(ptr);
  /// // No need to free - Rust handles it
  /// ```
  static String? convertRustResponse(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return null;
    return ptr.toDartString();
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
