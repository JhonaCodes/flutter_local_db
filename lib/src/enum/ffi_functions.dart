/// Defines the functions that are available through the FFI bridge to the Rust backend.
/// These functions represent the core operations that can be performed on the database.
enum FFiFunctions {
  /// Creates a new database instance with the specified name
  /// Rust function: `create_db`
  createDb('create_db'),

  /// Inserts new data into the database
  /// Rust function: `push_data`
  pushData('push_data'),

  /// Retrieves a single record by its unique identifier
  /// Rust function: `get_by_id`
  getById('get_by_id'),

  /// Retrieves all records from the database
  /// Rust function: `get_all`
  getAll('get_all'),

  /// Updates an existing record in the database
  /// Rust function: `update_data`
  updateData('update_data'),

  /// Deletes a record by its unique identifier
  /// Rust function: `delete_by_id`
  delete('delete_by_id'),

  /// Clears all records from the database
  /// Rust function: `clear_all_records`
  clearAllRecords('clear_all_records'),

  /// Closes the database connection and frees resources
  /// Rust function: `close_database`
  closeDatabase('close_database'),

  /// Frees memory allocated for C string responses
  /// Rust function: `free_c_string`
  freeCString('free_c_string'),

  /// Validates that a database pointer is still valid
  /// Rust function: `is_database_valid`
  isDatabaseValid('is_database_valid');

  /// The corresponding C function name in the Rust FFI layer
  /// This name must match exactly with the function exported in the Rust code
  final String cName;

  /// Constructor that maps each enum value to its corresponding Rust function name
  const FFiFunctions(this.cName);
}
