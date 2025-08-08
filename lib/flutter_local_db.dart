/// A high-performance cross-platform local database for Flutter
///
/// Provides unified database operations across all platforms:
/// - **Native platforms** (Android, iOS, macOS): Rust + LMDB via FFI
/// - **Web platform**: IndexedDB for persistent storage
///
/// Features:
/// - ✅ Unified API across all platforms
/// - ✅ High-performance native backend (10,000+ ops/sec)
/// - ✅ Web-optimized IndexedDB storage (persistent, non-volatile)
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
/// // ✅ CREATE a new record (fails if ID already exists)
/// final createResult = await LocalDB.Post('user-123', {
///   'name': 'John Doe',
///   'email': 'john@example.com',
///   'age': 30
/// });
///
/// createResult.when(
///   ok: (model) => print('✅ New user created: ${model.id}'),
///   err: (error) {
///     if (error.message.contains('already exists')) {
///       print('❌ User exists! Use Put to update instead.');
///     }
///   }
/// );
///
/// // ✅ UPDATE existing record (fails if ID doesn't exist)
/// final updateResult = await LocalDB.Put('user-123', {
///   'name': 'John Smith',  // Updated name
///   'age': 31              // Updated age
/// });
///
/// updateResult.when(
///   ok: (model) => print('✅ User updated: ${model.id}'),
///   err: (error) {
///     if (error.message.contains('does not exist')) {
///       print('❌ User not found! Use Post to create first.');
///     }
///   }
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
