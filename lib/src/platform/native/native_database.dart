import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/database.dart';
import '../../core/result.dart';
import '../../core/models.dart';
import '../../core/log.dart';
import '../../enum/ffi_functions.dart';
import '../../enum/ffi_native_lib_location.dart';

/// Opaque type representing the native database state
final class AppDbState extends Opaque {}

/// FFI Native function signatures (C side)
typedef _CreateDatabaseNative = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef _PostDataNative = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _GetByIdNative = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _PutDataNative = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _DeleteNative = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _GetAllNative = Pointer<Utf8> Function(Pointer<AppDbState>);
typedef _ClearAllNative = Pointer<Utf8> Function(Pointer<AppDbState>);

/// FFI Dart function signatures (Dart side)
typedef _CreateDatabaseDart = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef _PostDataDart = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _GetByIdDart = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _PutDataDart = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _DeleteDart = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef _GetAllDart = Pointer<Utf8> Function(Pointer<AppDbState>);
typedef _ClearAllDart = Pointer<Utf8> Function(Pointer<AppDbState>);

/// Native database implementation using FFI with Rust/LMDB backend
///
/// Provides high-performance local database operations for native platforms
/// (Android, iOS, macOS) using a Rust backend with LMDB storage.
///
/// Example:
/// ```dart
/// final database = NativeDatabase();
/// await database.initialize(DbConfig(name: 'my_app'));
///
/// final result = await database.insert('user-1', {'name': 'John'});
/// result.when(
///   ok: (entry) => Log.i('Saved: ${entry.id}'),
///   err: (error) => Log.e('Failed: ${error.message}')
/// );
/// ```
class NativeDatabase implements Database {
  DynamicLibrary? _lib;
  Pointer<AppDbState>? _dbInstance;
  String? _lastDatabaseName;
  bool _isInitialized = false;

  /// FFI function bindings - typed according to Dart FFI best practices
  late final _CreateDatabaseDart _createDatabase;
  late final _PostDataDart _postData;
  late final _GetAllDart _getAllData;
  late final _GetByIdDart _getDataById;
  late final _PutDataDart _putData;
  late final _DeleteDart _deleteData;
  late final _ClearAllDart _clearAllRecords;

  @override
  Future<DbResult<void>> initialize(DbConfig config) async {
    try {
      Log.i('NativeDatabase.initialize started: ${config.name}');

      _lastDatabaseName = config.name;

      // Load native library if not already loaded
      if (_lib == null) {
        final libResult = await _loadNativeLibrary();
        if (libResult.isErr) {
          final error = libResult.errorOrNull!;
          return Err(
            DbError.connectionError('Failed to load native library: $error'),
          );
        }
        _lib = libResult.data;
        Log.i('Native library loaded successfully');
      }

      // Bind FFI functions
      _bindFunctions();
      Log.d('FFI functions bound successfully');

      // Get database directory
      final dbPath = await _getDatabasePath(config.name);
      Log.d('Database path: $dbPath');

      // Initialize database instance
      await _initializeDatabase(dbPath);

      _isInitialized = true;
      Log.i('NativeDatabase initialized successfully');
      return const Ok(null);
    } catch (e, stackTrace) {
      Log.e(
        'Failed to initialize NativeDatabase',
        error: e,
        stackTrace: stackTrace,
      );
      return Err(
        DbError.connectionError(
          'Database initialization failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<DbEntry>> insert(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(
        DbError.validationError(DatabaseValidator.getKeyValidationError(key)),
      );
    }

    if (!DatabaseValidator.isValidData(data)) {
      return Err(
        DbError.validationError('The provided data format is invalid'),
      );
    }

    try {
      Log.d('NativeDatabase.insert: $key');

      // Check if key already exists
      final existsResult = await get(key);
      if (existsResult.isOk) {
        return Err(
          DbError.validationError(
            "❌ Record creation failed: ID '$key' already exists.\n" +
                "💡 Solution: Use LocalDB.Put('$key', data) to UPDATE the existing record, " +
                "or choose a different ID for LocalDB.Post().",
          ),
        );
      }

      // Create entry with timestamp hash
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Convert to JSON and call FFI
      final jsonString = jsonEncode(entry.toJson());
      final jsonPointer = jsonString.toNativeUtf8();

      try {
        final resultPointer = _postData(_dbInstance!, jsonPointer);
        final resultString = resultPointer.cast<Utf8>().toDartString();

        calloc.free(resultPointer);
        calloc.free(jsonPointer);

        // Parse response
        final response = jsonDecode(resultString) as Map<String, dynamic>;

        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        final responseData =
            jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final resultEntry = _mapToDbEntry(responseData);

        Log.i('Record inserted successfully: $key');
        return Ok(resultEntry);
      } catch (e) {
        calloc.free(jsonPointer);
        throw e;
      }
    } catch (e, stackTrace) {
      Log.e('Failed to insert record: $key', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'Insert operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<DbEntry>> get(String key) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(
        DbError.validationError(DatabaseValidator.getKeyValidationError(key)),
      );
    }

    try {
      Log.d('NativeDatabase.get: $key');

      final keyPointer = key.toNativeUtf8();

      try {
        final resultPointer = _getDataById(_dbInstance!, keyPointer);
        calloc.free(keyPointer);

        if (resultPointer == nullptr) {
          return Err(DbError.notFound("No record found with key: $key"));
        }

        final resultString = resultPointer.cast<Utf8>().toDartString();
        malloc.free(resultPointer);

        final response = jsonDecode(resultString) as Map<String, dynamic>;

        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        final responseData =
            jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final entry = _mapToDbEntry(responseData);

        Log.d('Record retrieved successfully: $key');
        return Ok(entry);
      } catch (e) {
        calloc.free(keyPointer);
        throw e;
      }
    } catch (e, stackTrace) {
      Log.e('Failed to get record: $key', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'Get operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<DbEntry>> update(
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    try {
      Log.d('NativeDatabase.update: $key');

      // Verify record exists
      final existsResult = await get(key);
      if (existsResult.isErr) {
        return Err(
          DbError.notFound(
            "❌ Record update failed: ID '$key' does not exist.\n" +
                "💡 Solution: Use LocalDB.Post('$key', data) to CREATE a new record, " +
                "or verify the ID exists with LocalDB.GetById('$key').",
          ),
        );
      }

      // Create updated entry
      final entry = DbEntry(
        id: key,
        data: data,
        hash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Convert to JSON and call FFI
      final jsonString = jsonEncode(entry.toJson());
      final jsonPointer = jsonString.toNativeUtf8();

      try {
        final resultPointer = _putData(_dbInstance!, jsonPointer);
        final resultString = resultPointer.cast<Utf8>().toDartString();

        calloc.free(jsonPointer);
        malloc.free(resultPointer);

        final response = jsonDecode(resultString) as Map<String, dynamic>;

        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        final responseData =
            jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final resultEntry = _mapToDbEntry(responseData);

        Log.i('Record updated successfully: $key');
        return Ok(resultEntry);
      } catch (e) {
        calloc.free(jsonPointer);
        throw e;
      }
    } catch (e, stackTrace) {
      Log.e('Failed to update record: $key', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'Update operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<void>> delete(String key) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(
        DbError.validationError(DatabaseValidator.getKeyValidationError(key)),
      );
    }

    try {
      Log.d('NativeDatabase.delete: $key');

      final keyPointer = key.toNativeUtf8();

      try {
        final resultPointer = _deleteData(_dbInstance!, keyPointer);
        final resultString = resultPointer.cast<Utf8>().toDartString();

        calloc.free(keyPointer);

        final response = jsonDecode(resultString) as Map<String, dynamic>;

        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        Log.i('Record deleted successfully: $key');
        return const Ok(null);
      } catch (e) {
        calloc.free(keyPointer);
        throw e;
      }
    } catch (e, stackTrace) {
      Log.e('Failed to delete record: $key', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'Delete operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<List<DbEntry>>> getAll() async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    try {
      Log.d('NativeDatabase.getAll');

      final resultPointer = _getAllData(_dbInstance!);

      if (resultPointer == nullptr) {
        Log.w('GetAll returned null pointer');
        return Err(
          DbError.databaseError(
            'Failed to retrieve data: null pointer returned',
          ),
        );
      }

      final resultString = resultPointer.cast<Utf8>().toDartString();
      malloc.free(resultPointer);

      final response = jsonDecode(resultString) as Map<String, dynamic>;

      if (!response.containsKey('Ok')) {
        return Err(_parseRustError(resultString));
      }

      final jsonList = jsonDecode(response['Ok'] as String) as List<dynamic>;
      final entries = jsonList
          .map((json) => _mapToDbEntry(Map<String, dynamic>.from(json as Map)))
          .toList();

      Log.i('Retrieved ${entries.length} records');
      return Ok(entries);
    } catch (e, stackTrace) {
      Log.e('Failed to get all records', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'GetAll operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<DbResult<List<String>>> getAllKeys() async {
    // Get all entries and extract keys
    final allResult = await getAll();
    return allResult.map(
      (entries) => entries.map((entry) => entry.id).toList(),
    );
  }

  @override
  Future<DbResult<void>> clear() async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    try {
      Log.d('NativeDatabase.clear');

      final resultPointer = _clearAllRecords(_dbInstance!);
      final success = resultPointer != nullptr;

      if (resultPointer != nullptr) {
        malloc.free(resultPointer);
      }

      if (success) {
        Log.i('Database cleared successfully');
        return const Ok(null);
      } else {
        return Err(DbError.databaseError('Failed to clear database'));
      }
    } catch (e, stackTrace) {
      Log.e('Failed to clear database', error: e, stackTrace: stackTrace);
      return Err(
        DbError.databaseError(
          'Clear operation failed: ${e.toString()}',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<bool> isConnectionValid() async {
    // Basic state check
    if (!_isInitialized || _dbInstance == null || _dbInstance == nullptr) {
      return false;
    }

    // Advanced validation: test the actual FFI connection
    try {
      return await _testConnection();
    } catch (e) {
      Log.w('Connection validity test failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    Log.i('NativeDatabase.close - cleaning up resources');

    // Safely clear database instance
    if (_dbInstance != null && _dbInstance != nullptr) {
      try {
        // Note: We don't call a close function on Rust side because LMDB handles it
        // We just need to release our reference to the pointer
        Log.d('Releasing database instance pointer');
      } catch (e) {
        Log.w('Error during database cleanup: $e');
      }
    }

    _dbInstance = null;
    _isInitialized = false;

    // Keep _lastDatabaseName for potential recovery
    Log.d('Database connection closed and resources cleaned');
  }

  /// Loads the native library for the current platform
  /// 
  /// Implements platform-specific library loading following Dart FFI best practices:
  /// - Uses DynamicLibrary.process() for iOS (statically linked)
  /// - Architecture-specific loading for macOS (ARM64/x86_64)
  /// - Proper error handling and fallbacks
  Future<Result<DynamicLibrary, String>> _loadNativeLibrary() async {
    try {
      late final String libraryPath;
      late final String platformName;

      if (Platform.isAndroid) {
        platformName = 'Android';
        libraryPath = FFiNativeLibLocation.android.lib;
        Log.d('Loading $platformName library: $libraryPath');
        return Ok(DynamicLibrary.open(libraryPath));
      }

      if (Platform.isIOS) {
        platformName = 'iOS';
        Log.d('Loading $platformName library via process()');
        try {
          // iOS uses static linking - library is embedded in the main executable
          return Ok(DynamicLibrary.process());
        } catch (e) {
          Log.w('DynamicLibrary.process() failed, trying explicit path: $e');
          libraryPath = FFiNativeLibLocation.ios.lib;
          return Ok(DynamicLibrary.open(libraryPath));
        }
      }

      if (Platform.isMacOS) {
        platformName = 'macOS';
        Log.d('Loading $platformName library with architecture detection');
        try {
          // Try architecture-specific library first (better practice)
          final archPath = await FFiNativeLibLocation.macos.toMacosArchPath();
          Log.d('Attempting architecture-specific library: $archPath');
          return Ok(DynamicLibrary.open(archPath));
        } catch (e) {
          Log.w('Architecture-specific loading failed, using fallback: $e');
          libraryPath = FFiNativeLibLocation.macos.lib;
          return Ok(DynamicLibrary.open(libraryPath));
        }
      }

      if (Platform.isLinux) {
        platformName = 'Linux';
        libraryPath = FFiNativeLibLocation.linux.lib;
        Log.d('Loading $platformName library: $libraryPath');
        return Ok(DynamicLibrary.open(libraryPath));
      }

      if (Platform.isWindows) {
        platformName = 'Windows';
        libraryPath = FFiNativeLibLocation.windows.lib;
        Log.d('Loading $platformName library: $libraryPath');
        return Ok(DynamicLibrary.open(libraryPath));
      }

      final unsupportedPlatform = Platform.operatingSystem;
      Log.e('Unsupported platform detected: $unsupportedPlatform');
      return Err("Unsupported platform: $unsupportedPlatform");
      
    } catch (e, stackTrace) {
      final errorMsg = "Failed to load native library: $e";
      Log.e(errorMsg, error: e, stackTrace: stackTrace);
      return Err(errorMsg);
    }
  }

  /// Binds FFI functions from the native library using Dart FFI best practices
  /// 
  /// Separates native (C) and Dart function types for better type safety
  /// and follows the recommended pattern from dart.dev/interop/c-interop
  void _bindFunctions() {
    if (_lib == null) {
      throw StateError('Native library not loaded - cannot bind functions');
    }

    try {
      Log.d('Binding FFI functions with proper type safety');

      // Create Database
      _createDatabase = _lib!
          .lookupFunction<_CreateDatabaseNative, _CreateDatabaseDart>(
            FFiFunctions.createDb.cName,
          );

      // Post Data (Insert)
      _postData = _lib!
          .lookupFunction<_PostDataNative, _PostDataDart>(
            FFiFunctions.postData.cName,
          );

      // Get All Data
      _getAllData = _lib!
          .lookupFunction<_GetAllNative, _GetAllDart>(
            FFiFunctions.getAll.cName,
          );

      // Get Data By ID
      _getDataById = _lib!
          .lookupFunction<_GetByIdNative, _GetByIdDart>(
            FFiFunctions.getById.cName,
          );

      // Put Data (Update)
      _putData = _lib!
          .lookupFunction<_PutDataNative, _PutDataDart>(
            FFiFunctions.putData.cName,
          );

      // Delete Data
      _deleteData = _lib!
          .lookupFunction<_DeleteNative, _DeleteDart>(
            FFiFunctions.delete.cName,
          );

      // Clear All Records
      _clearAllRecords = _lib!
          .lookupFunction<_ClearAllNative, _ClearAllDart>(
            FFiFunctions.clearAllRecords.cName,
          );

      Log.d('All ${FFiFunctions.values.length} FFI functions bound successfully');
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to bind FFI functions: $e';
      Log.e(errorMsg, error: e, stackTrace: stackTrace);
      throw Exception(errorMsg);
    }
  }

  /// Gets the database file path for the given name
  Future<String> _getDatabasePath(String name) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$name';
    } catch (e) {
      Log.w('Failed to get documents directory, using support directory: $e');
      final appDir = await getApplicationSupportDirectory();
      return '${appDir.path}/$name';
    }
  }

  /// Initializes the database instance
  Future<void> _initializeDatabase(String dbPath) async {
    // Rust expects .lmdb extension
    final lmdbPath = '$dbPath.lmdb';
    Log.d('Creating database instance at: $lmdbPath');

    final pathPointer = lmdbPath.toNativeUtf8();

    try {
      _dbInstance = _createDatabase(pathPointer);

      if (_dbInstance == nullptr) {
        throw Exception(
          'Failed to create database instance. Returned null pointer.',
        );
      }

      Log.d('Database instance created successfully');
    } finally {
      calloc.free(pathPointer);
    }
  }

  /// Ensures the database connection is valid, reinitializing if needed
  ///
  /// This method provides robust hot reload support by:
  /// - Detecting invalid FFI pointers after hot reload
  /// - Automatically reinitializing database connection
  /// - Preserving data persistence across reloads
  Future<bool> _ensureConnectionValid() async {
    // First level check: basic state validation
    if (!_isInitialized || _dbInstance == null || _dbInstance == nullptr) {
      Log.w('Database connection invalid - performing recovery');
      return await _recoverConnection();
    }

    // Second level check: FFI pointer validity
    try {
      // Test the connection with a non-destructive operation
      // This will fail if FFI pointer is stale after hot reload
      final testResult = await _testConnection();
      if (!testResult) {
        Log.w('Database connection test failed - FFI pointer may be stale');
        _isInitialized = false; // Mark as invalid
        return await _recoverConnection();
      }
    } catch (e) {
      Log.w('Database connection validation error: $e - attempting recovery');
      _isInitialized = false;
      return await _recoverConnection();
    }

    return true;
  }

  /// Recovers database connection using saved configuration
  Future<bool> _recoverConnection() async {
    if (_lastDatabaseName != null) {
      try {
        Log.i('Recovering database connection: $_lastDatabaseName');

        // Clear current invalid state
        _dbInstance = null;
        _isInitialized = false;

        // Reinitialize with saved config
        final config = DbConfig(name: _lastDatabaseName!);
        final result = await initialize(config);

        if (result.isOk) {
          Log.i('Database connection recovered successfully');
          return true;
        } else {
          Log.e('Database recovery failed: ${result.errorOrNull?.message}');
          return false;
        }
      } catch (e) {
        Log.e('Failed to recover database connection', error: e);
        return false;
      }
    }

    Log.e('Cannot recover database - no saved configuration');
    return false;
  }

  /// Tests database connection validity without side effects
  Future<bool> _testConnection() async {
    if (_dbInstance == null || _dbInstance == nullptr) {
      return false;
    }

    try {
      // Perform a lightweight operation to test FFI connection
      // We'll use get_all operation which doesn't modify data
      final resultPointer = _getAllData(_dbInstance!);

      if (resultPointer == nullptr) {
        Log.d('Connection test failed: null pointer returned');
        return false;
      }

      // If we got a valid pointer, the connection is working
      malloc.free(resultPointer);
      Log.d('Database connection test passed');
      return true;
    } catch (e) {
      // Any exception means the FFI connection is broken
      Log.d('Connection test failed with exception: $e');
      return false;
    }
  }

  /// Parses a Rust error response
  DbError _parseRustError(String errorResponse) {
    try {
      final response = jsonDecode(errorResponse) as Map<String, dynamic>;

      // Handle Rust error format: {"ErrorType": "message"}
      if (response.containsKey('NotFound')) {
        final errorMessage = response['NotFound'] as String;
        return DbError.notFound(errorMessage);
      }

      if (response.containsKey('ValidationError')) {
        final errorMessage = response['ValidationError'] as String;
        return DbError.validationError(errorMessage);
      }

      if (response.containsKey('SerializationError')) {
        final errorMessage = response['SerializationError'] as String;
        return DbError.serializationError(errorMessage);
      }

      if (response.containsKey('DatabaseError')) {
        final errorMessage = response['DatabaseError'] as String;
        return DbError.databaseError(errorMessage);
      }

      // Fallback for legacy format {"Err": "message"}
      if (response.containsKey('Err')) {
        final errorData = response['Err'] as String;
        return DbError.databaseError('Rust error: $errorData');
      }

      // Unknown error format
      final firstKey = response.keys.first;
      final firstValue = response[firstKey] as String;
      return DbError.databaseError('Rust error ($firstKey): $firstValue');
    } catch (e) {
      // Fallback if JSON parsing fails
    }
    return DbError.databaseError('Unknown Rust error: $errorResponse');
  }

  /// Maps LocalDbModel format to DbEntry
  DbEntry _mapToDbEntry(Map<String, dynamic> data) {
    return DbEntry(
      id: data['id'] as String,
      data: Map<String, dynamic>.from(data['data'] as Map),
      hash: data['hash'] as String,
    );
  }
}
