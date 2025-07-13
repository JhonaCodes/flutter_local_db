/// A high-performance cross-platform local database for Flutter
///
/// Provides unified database operations across all platforms:
/// - **Native platforms** (Android, iOS, macOS): Rust + LMDB via FFI
/// - **Web platform**: In-memory storage with localStorage persistence
///
/// Features:
/// - ✅ Unified API across all platforms
/// - ✅ High-performance native backend (10,000+ ops/sec)
/// - ✅ Web-optimized in-memory storage
/// - ✅ Result-based error handling
/// - ✅ JSON-serializable data storage
/// - ✅ Hot restart support
///
/// Example:
/// ```dart
/// import 'package:flutter_local_db/flutter_local_db.dart';
///
/// // Initialize database
/// await LocalDB.init();
///
/// // Create a record
/// final result = await LocalDB.Post('user-123', {
///   'name': 'John Doe',
///   'email': 'john@example.com',
///   'age': 30
/// });
///
/// result.when(
///   ok: (model) => print('Created user: ${model.id}'),
///   err: (error) => print('Error: ${error.message}')
/// );
///
/// // Retrieve the record
/// final getResult = await LocalDB.GetById('user-123');
/// getResult.when(
///   ok: (model) => print('User data: ${model?.data}'),
///   err: (error) => print('Not found: ${error.message}')
/// );
/// ```
library;

// Main API
export 'src/flutter_local_db.dart';

// Legacy compatibility exports
export 'src/model/local_db_request_model.dart';
export 'src/model/local_db_error_model.dart';
export 'src/service/local_db_result.dart'
    hide
        Ok,
        Err,
        ResultExtensions,
        FutureResultExtensions; // Hide to avoid conflicts

// Core types for advanced usage (preferred)
export 'src/core/result.dart';
export 'src/core/models.dart';
export 'src/database_factory.dart';
