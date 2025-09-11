// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            FFI FUNCTIONS ENUM                                ║
// ║                    Centralized FFI Function Name Management                  ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: ffi_functions.dart                                                  ║
// ║  Purpose: Centralized FFI function names for consistency                    ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides a single source of truth for all FFI function names used       ║
// ║    throughout the library. This ensures consistency between the Rust       ║
// ║    backend and Dart frontend bindings.                                      ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Enum containing all FFI function names exported from the Rust library
///
/// This enum provides a centralized location for all function names,
/// ensuring consistency across the codebase and preventing typos.
enum FfiFunction {
  /// Initialize database with given name
  createDb('create_db'),

  /// Insert or push data to database
  pushData('push_data'),

  /// Get all records from database
  getAll('get_all'),

  /// Get record by ID
  getById('get_by_id'),

  /// Delete record by ID
  deleteById('delete_by_id'),

  /// Update existing record
  updateData('update_data'),

  /// Clear all records from database
  clearAllRecords('clear_all_records'),

  /// Reset database to clean state
  resetDatabase('reset_database'),

  /// Close database connection
  closeDatabase('close_database');

  /// The actual function name as exported from Rust
  final String fn;

  const FfiFunction(this.fn);

  /// Returns a list of all function names
  static List<String> get allFunctionNames => 
      FfiFunction.values.map((f) => f.fn).toList();

  /// Validates if a function name exists
  static bool isValidFunction(String name) => 
      allFunctionNames.contains(name);
}