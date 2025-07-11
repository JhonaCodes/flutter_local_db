/// A library for local database functionality.
///
/// This library exports core components for managing local database interactions:
/// - Local database implementation
/// - Response model for database operations
/// - Error and result types
library;

/// Exports the main local database implementation from 'src/local_db.dart'
export 'src/local_db.dart';

/// Exports the lifecycle manager widget for hot restart handling
export 'src/widgets/local_db_lifecycle_manager.dart';

/// Exports the database model for request/response
export 'src/model/local_db_request_model.dart';

/// Exports the error model
export 'src/model/local_db_error_model.dart';

/// Exports the result type for handling operations
export 'src/service/local_db_result.dart';
