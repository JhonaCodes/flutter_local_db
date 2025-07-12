import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import '../core/log.dart';
import '../enum/ffi_functions.dart';
import '../enum/ffi_native_lib_location.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';
import 'database_interface.dart';

/// opaque extension
final class AppDbState extends Opaque {}

/// Connection information for hot reload resilience
class DatabaseConnection {
  final Pointer<AppDbState> pointer;
  final int generation;
  DateTime lastUsed;
  bool isValid;

  DatabaseConnection({
    required this.pointer,
    required this.generation,
    required this.isValid,
  }) : lastUsed = DateTime.now();

  void updateLastUsed() {
    lastUsed = DateTime.now();
  }

  bool get isStale {
    // Increase staleness threshold for more persistent connections
    return DateTime.now().difference(lastUsed).inMinutes > 30;
  }
}

/// Connection pool for managing database connections with hot reload support
class ConnectionPool {
  static final Map<String, DatabaseConnection> _connections = {};
  static int _currentGeneration = 1;
  // Persist the last used database name across hot restarts
  static String? _lastUsedDatabaseName;

  static DatabaseConnection? getConnection(String dbName) {
    final connection = _connections[dbName];
    if (connection != null && connection.isValid && !connection.isStale) {
      connection.updateLastUsed();
      return connection;
    }
    return null;
  }

  static void storeConnection(String dbName, DatabaseConnection connection) {
    _connections[dbName] = connection;
    _lastUsedDatabaseName = dbName; // Remember the last used database name
  }

  static void invalidateConnection(String dbName) {
    final connection = _connections[dbName];
    if (connection != null) {
      connection.isValid = false;
    }
  }

  static void removeConnection(String dbName) {
    _connections.remove(dbName);
  }

  static void cleanupStaleConnections() {
    _connections.removeWhere(
      (key, connection) => !connection.isValid || connection.isStale,
    );
  }

  static int get currentGeneration => _currentGeneration;
  static void incrementGeneration() => _currentGeneration++;

  static int get connectionCount => _connections.length;
  
  // Getter for last used database name (survives hot restart)
  static String? get lastUsedDatabaseName => _lastUsedDatabaseName;
}

/// Typedef for the rust functions
typedef PointerStringFFICallBack =
    Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBAck = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef PointerBoolFFICallBack =
    Pointer<Bool> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerBoolFFICallBackDirect =
    Pointer<Bool> Function(Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);

/// Native database implementation using FFI and Rust backend
/// This implementation is used for mobile and desktop platforms
class DatabaseNative implements DatabaseInterface {

  Result<DynamicLibrary, String>? _lib;
  Pointer<AppDbState>? _dbInstance;
  String? _lastDatabaseName;

  /// Functions registration (static to be shared across instances)
  static Pointer<AppDbState> Function(Pointer<Utf8>)? _createDatabase;
  static PointerStringFFICallBack? _post;
  static PointerListFFICallBack? _get;
  static PointerStringFFICallBack? _getById;
  static PointerStringFFICallBack? _put;
  static PointerBoolFFICallBack? _delete;
  static PointerBoolFFICallBackDirect? _clearAllRecords;
  static Pointer<Utf8> Function(Pointer<AppDbState>)? _closeDatabase;
  static void Function(Pointer<Utf8>)? _freeCString;
  static bool Function(Pointer<AppDbState>)? _isDatabaseValid;
  static bool Function(Pointer<AppDbState>, int)? _validateInstanceGeneration;
  static Pointer<Utf8> Function(Pointer<AppDbState>)? _pingDatabase;
  static int Function()? _getCurrentGeneration;

  @override
  bool get isSupported => !Platform.isLinux && !Platform.isWindows;

  @override
  String get platformName => 'native';

  @override
  String? get currentDatabaseName => _lastDatabaseName;

  Future<void> initForTesting(String databaseName, String libPath) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }

    // Reset function pointers for hot restart safety
    _resetFunctionPointers();

    _lastDatabaseName = databaseName;
    if (_lib == null) {
      _lib = Ok(DynamicLibrary.open(libPath));
    }

    if (_lib case Ok(data: final lib)) {
      _bindFunctions(lib);
      Log.i('Functions bound successfully');
    }

    await _init(databaseName);
    Log.i('Native database initialized successfully for testing');
  }

  static void _resetFunctionPointers() {
    _createDatabase = null;
    _post = null;
    _get = null;
    _getById = null;
    _put = null;
    _delete = null;
    _clearAllRecords = null;
    _closeDatabase = null;
    _freeCString = null;
    _isDatabaseValid = null;
    _validateInstanceGeneration = null;
    _pingDatabase = null;
    _getCurrentGeneration = null;
  }

  @override
  Future<void> initialize(String databaseName) async {
    try {
      Log.i('Initializing native DB on platform: ${Platform.operatingSystem}');

      // Close any existing connection first (hot restart safety)
      await _closeCurrentConnection();

      // Reset function pointers for hot restart safety
      _resetFunctionPointers();

      _lastDatabaseName = databaseName;

      // Force reload library for hot restart compatibility
      _lib = null;
      _lib = await _loadRustNativeLib();
      Log.i('Native library loaded: $_lib');

      if (_lib case Ok(data: final lib)) {
        _bindFunctions(lib);
        Log.i('Functions bound successfully');
      }

      final appDir = await getApplicationDocumentsDirectory();
      Log.i('Using app directory for database storage');

      await _init('${appDir.path}/$databaseName');
      Log.i('Native database initialized successfully');
    } catch (e, stack) {
      Log.e('Error initializing native database', error: e, stackTrace: stack);

      // Clean up state on failure
      _dbInstance = null;
      _resetFunctionPointers();
      rethrow;
    }
  }

  Future<Result<DynamicLibrary, String>> _loadRustNativeLib() async {
    if (Platform.isAndroid) {
      return Ok(DynamicLibrary.open(FFiNativeLibLocation.android.lib));
    }

    if (Platform.isMacOS) {
      final arch = await FFiNativeLibLocation.macos.toMacosArchPath();
      return Ok(DynamicLibrary.open(arch));
    }

    if (Platform.isIOS) {
      try {
        return Ok(DynamicLibrary.process());
      } catch (e) {
        try {
          return Ok(DynamicLibrary.open(FFiNativeLibLocation.ios.lib));
        } catch (error) {
          return Err("Error loading library on iOS: $error");
        }
      }
    }

    return Err("Unsupported platform: ${Platform.operatingSystem}");
  }

  static void _bindFunctions(DynamicLibrary lib) {
        _createDatabase = lib
            .lookupFunction<
              PointerAppDbStateCallBAck,
              PointerAppDbStateCallBAck
            >(FFiFunctions.createDb.cName);
        _post = lib
            .lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
              FFiFunctions.pushData.cName,
            );
        _get = lib
            .lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(
              FFiFunctions.getAll.cName,
            );
        _getById = lib
            .lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
              FFiFunctions.getById.cName,
            );
        _put = lib
            .lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
              FFiFunctions.updateData.cName,
            );
        _delete = lib
            .lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(
              FFiFunctions.delete.cName,
            );
        _clearAllRecords = lib
            .lookupFunction<
              PointerBoolFFICallBackDirect,
              PointerBoolFFICallBackDirect
            >(FFiFunctions.clearAllRecords.cName);
        _closeDatabase = lib
            .lookupFunction<
              Pointer<Utf8> Function(Pointer<AppDbState>),
              Pointer<Utf8> Function(Pointer<AppDbState>)
            >(FFiFunctions.closeDatabase.cName);
        _freeCString = lib
            .lookupFunction<
              Void Function(Pointer<Utf8>),
              void Function(Pointer<Utf8>)
            >(FFiFunctions.freeCString.cName);
        _isDatabaseValid = lib
            .lookupFunction<
              Bool Function(Pointer<AppDbState>),
              bool Function(Pointer<AppDbState>)
            >(FFiFunctions.isDatabaseValid.cName);
        _validateInstanceGeneration = lib
            .lookupFunction<
              Bool Function(Pointer<AppDbState>, Uint64),
              bool Function(Pointer<AppDbState>, int)
            >(FFiFunctions.validateInstanceGeneration.cName);
        _pingDatabase = lib
            .lookupFunction<
              Pointer<Utf8> Function(Pointer<AppDbState>),
              Pointer<Utf8> Function(Pointer<AppDbState>)
            >(FFiFunctions.pingDatabase.cName);
        _getCurrentGeneration = lib
            .lookupFunction<Uint64 Function(), int Function()>(
              FFiFunctions.getCurrentGeneration.cName,
            );
  }

  Future<void> _init(String dbName) async {
    try {
      // Ensure FFI functions are always bound before initialization
      if (_createDatabase == null || _post == null || _get == null) {
        Log.w('FFI functions not bound during _init, binding now...');
        if (_lib case Ok(data: final lib)) {
          _bindFunctions(lib);
        }
      }

      if (_createDatabase == null) {
        throw Exception(
          'Database functions not bound. Call _bindFunctions first.',
        );
      }

      // Try multiple times with different strategies for hot restart compatibility
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          Log.i('Database creation attempt $attempt');

          // For hot restart, try with a slightly different path each time
          String actualDbName = dbName;
          if (attempt > 1) {
            // Add a timestamp to make path unique for retry attempts
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final extension = dbName.endsWith('.db') ? '.db' : '';
            final baseName = extension.isEmpty
                ? dbName
                : dbName.substring(0, dbName.length - 3);
            actualDbName = '${baseName}_${timestamp}$extension';
            Log.i('Retry attempt $attempt with modified database name');
          }

          final dbNamePointer = actualDbName.toNativeUtf8();
          _dbInstance = _createDatabase!(dbNamePointer);
          calloc.free(dbNamePointer);

          if (_dbInstance != nullptr) {
            Log.i('Database instance created successfully on attempt $attempt');

            // Get current generation from Rust
            final generation = _getCurrentGeneration?.call() ?? 0;

            // Store connection in pool
            final connection = DatabaseConnection(
              pointer: _dbInstance!,
              generation: generation,
              isValid: true,
            );
            ConnectionPool.storeConnection(
              _lastDatabaseName ?? actualDbName,
              connection,
            );

            // Update the last database name to the successful one
            _lastDatabaseName = actualDbName.split('/').last;

            Log.i('Stored connection in pool with generation: $generation');
            return;
          }

          Log.w('Attempt $attempt failed - got null pointer');

          // Wait a bit before retrying
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 100 * attempt));
          }
        } catch (e) {
          Log.e('Attempt $attempt failed with error', error: e);
          if (attempt == 3) rethrow;
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }

      // If all attempts failed, try one last fallback strategy
      Log.w('All regular attempts failed, trying fallback strategy...');

      // Try with a completely fresh name and in-memory fallback if needed
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fallbackName = 'fallback_$timestamp.db';
        final dbNamePointer = fallbackName.toNativeUtf8();
        _dbInstance = _createDatabase!(dbNamePointer);
        calloc.free(dbNamePointer);

        if (_dbInstance != nullptr) {
          Log.i('Fallback database created successfully');
          _lastDatabaseName = fallbackName;
          return;
        }
      } catch (e) {
        Log.e('Fallback strategy also failed', error: e);
      }

      // Final failure
      throw Exception(
        'Failed to create database instance after all attempts including fallback. This is likely due to hot restart conflicts with the Rust binary. Please restart the application completely.',
      );
    } catch (error, stackTrace) {
      Log.e('Error in _init', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> ensureConnectionValid() async {
    // Cleanup stale connections periodically
    ConnectionPool.cleanupStaleConnections();

    // First, ensure FFI functions are bound
    if (_createDatabase == null || _post == null || _get == null) {
      Log.w('FFI functions not bound, attempting to rebind...');
      try {
        if (_lib case Ok(data: final lib)) {
          _bindFunctions(lib);
          Log.i('FFI functions rebound successfully');
        }
      } catch (e) {
        Log.e('Failed to rebind FFI functions', error: e);
        return false;
      }
    }

    // Check if we have a database name stored (indicates previous initialization)
    final dbNameToRestore = _lastDatabaseName ?? ConnectionPool.lastUsedDatabaseName;
    if (dbNameToRestore != null && (_dbInstance == null || _dbInstance == nullptr)) {
      Log.i('🔄 Hot restart detected - attempting to reconnect to existing database: $dbNameToRestore');
      
      // Restore the database name for the instance
      if (_lastDatabaseName == null) {
        _lastDatabaseName = dbNameToRestore;
        Log.i('🔄 Restored database name from connection pool: $dbNameToRestore');
      }
      
      return await _attemptReinitialization();
    }

    if (_dbInstance == null || _dbInstance == nullptr) {
      Log.w('Database connection invalid (null pointer), no previous database name stored');
      return false;
    }

    // Check connection pool first
    if (_lastDatabaseName != null) {
      final poolConnection = ConnectionPool.getConnection(_lastDatabaseName!);
      if (poolConnection != null && poolConnection.pointer == _dbInstance) {
        // Connection exists in pool and matches current instance
        try {
          // Validate with Rust using generation (less aggressive)
          if (_validateInstanceGeneration != null) {
            final isValidGeneration = _validateInstanceGeneration!(
              _dbInstance!,
              poolConnection.generation,
            );
            if (!isValidGeneration) {
              Log.d(
                'Database connection has different generation, but connection may still be valid',
              );
              // Don't immediately reinitialize - try ping first
            }
          }

          // Ping database to ensure it's responsive (primary validation)
          if (_pingDatabase != null) {
            try {
              final pingResult = _pingDatabase!(_dbInstance!);
              if (pingResult != nullptr) {
                _freeCString?.call(pingResult);
                Log.d('Database ping successful - connection healthy');
                poolConnection.updateLastUsed();
                return true;
              } else {
                Log.w('Database ping returned null - connection may be stale');
                // Only reinitialize if ping actually fails
                ConnectionPool.invalidateConnection(_lastDatabaseName!);
                await _closeCurrentConnection();
                return await _attemptReinitialization();
              }
            } catch (e) {
              Log.w('Database ping failed - will attempt reinitialization: $e');
              ConnectionPool.invalidateConnection(_lastDatabaseName!);
              await _closeCurrentConnection();
              return await _attemptReinitialization();
            }
          }
        } catch (e) {
          Log.e(
            'Error during enhanced validation, attempting to reinitialize',
            error: e,
          );
          ConnectionPool.invalidateConnection(_lastDatabaseName!);
          await _closeCurrentConnection();
          return await _attemptReinitialization();
        }
      }
    }

    // Fallback to legacy validation (less aggressive)
    try {
      if (_isDatabaseValid != null && !_isDatabaseValid!(_dbInstance!)) {
        Log.d('Legacy validation indicates connection issues - this may be normal');
        // Don't immediately reinitialize - just log and continue
        // The actual operations will fail if there's a real problem
      }
    } catch (e) {
      Log.d('Legacy validation threw exception - may not be critical: $e');
      // Don't reinitialize unless it's absolutely necessary
    }

    return true;
  }

  Future<void> _closeCurrentConnection() async {
    if (_dbInstance != null && _dbInstance != nullptr) {
      try {
        // Check if we have the function bound and the instance is valid
        if (_lib != null &&
            _lib!.isOk &&
            _isDatabaseValid != null &&
            _closeDatabase != null &&
            _freeCString != null) {
          try {
            if (_isDatabaseValid!(_dbInstance!)) {
              final closeResult = _closeDatabase!(_dbInstance!);
              if (closeResult != nullptr) {
                final resultStr = closeResult.cast<Utf8>().toDartString();
                Log.i('Database close result: $resultStr');
                _freeCString!(closeResult);
              }
            }
          } catch (e) {
            Log.e('Error validating or closing database', error: e);
          }
        }
      } catch (e) {
        Log.e('Error during database close', error: e);
      } finally {
        // Remove from connection pool
        if (_lastDatabaseName != null) {
          ConnectionPool.removeConnection(_lastDatabaseName!);
          Log.d('Removed connection from pool: $_lastDatabaseName');
        }
        _dbInstance = null; // Always reset to null, not nullptr
      }
    } else if (_dbInstance != null) {
      // If _dbInstance is not null but is nullptr, just reset it
      if (_lastDatabaseName != null) {
        ConnectionPool.removeConnection(_lastDatabaseName!);
      }
      _dbInstance = null;
    }
  }

  Future<bool> _attemptReinitialization() async {
    Log.d('Attempting database reinitialization...');

    if (_lastDatabaseName != null) {
      try {
        // Reset function pointers and rebind them
        _resetFunctionPointers();
        if (_lib case Ok(data: final lib)) {
          _bindFunctions(lib);
          Log.i('FFI functions rebound during reinitialization');
        }

        // Check if this is a testing scenario (database name contains full path)
        if (_lastDatabaseName!.contains('/') ||
            _lastDatabaseName!.contains('\\')) {
          // For testing, use the full path as is
          await _init(_lastDatabaseName!);
        } else {
          // For normal usage, prepend the app directory
          final appDir = await getApplicationDocumentsDirectory();
          await _init('${appDir.path}/$_lastDatabaseName');
        }
        Log.i('Database reinitialized successfully');
        return true;
      } catch (e) {
        Log.e('Failed to reinitialize database', error: e);
        return false;
      }
    } else {
      Log.w('Cannot reinitialize: no previous database name stored');
      return false;
    }
  }

  @override
  Future<void> closeDatabase() async {
    await _closeCurrentConnection();
    Log.i('Database manually closed');
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> post(
    LocalDbModel model,
  ) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    final jsonString = jsonEncode(model.toJson());
    final jsonPointer = jsonString.toNativeUtf8();

    try {
      if (_post == null || _freeCString == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final resultPushPointer = _post!(_dbInstance!, jsonPointer);
      final dataResult = resultPushPointer.cast<Utf8>().toDartString();

      _freeCString!(resultPushPointer);
      calloc.free(jsonPointer);

      final Map<String, dynamic> response = jsonDecode(dataResult);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(dataResult));
      }

      final modelData = LocalDbModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(response['Ok'])),
      );

      return Ok(modelData);
    } catch (error, stack) {
      Log.e('Error in post operation', error: error, stackTrace: stack);
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      if (_getById == null || _freeCString == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final idPtr = id.toNativeUtf8();
      final resultFfi = _getById!(_dbInstance!, idPtr);

      calloc.free(idPtr);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.notFound("No model found with id: $id"));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      _freeCString!(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }

      final modelData = LocalDbModel.fromJson(jsonDecode(response['Ok']));

      return Ok(modelData);
    } catch (error, stackTrace) {
      Log.e('Error in getById operation', error: error, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      if (_get == null || _freeCString == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final resultFfi = _get!(_dbInstance!);

      if (resultFfi == nullptr) {
        Log.e('NULL pointer returned from GetAll FFI call');
        return Err(
          ErrorLocalDb.notFound(
            'Failed to retrieve data: null pointer returned',
          ),
        );
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      _freeCString!(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }

      final List<dynamic> jsonList = jsonDecode(response['Ok']);

      final List<LocalDbModel> dataList = jsonList
          .map((json) => LocalDbModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return Ok(dataList);
    } catch (error, stackTrace) {
      Log.e('Error in getAll operation', error: error, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> put(
    LocalDbModel model,
  ) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      if (_put == null || _freeCString == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final jsonString = jsonEncode(model.toJson());
      final jsonPointer = jsonString.toNativeUtf8();
      final resultFfi = _put!(_dbInstance!, jsonPointer);
      final result = resultFfi.cast<Utf8>().toDartString();

      calloc.free(jsonPointer);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.notFound("No model found"));
      }

      _freeCString!(resultFfi);

      final Map<String, dynamic> response = jsonDecode(result);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(LocalDbModel.fromJson(jsonDecode(response['Ok'])));
    } catch (error, stackTrace) {
      Log.e('Error in put operation', error: error, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      if (_delete == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final idPtr = id.toNativeUtf8();
      final deleteResult = _delete!(_dbInstance!, idPtr);
      final result = deleteResult.cast<Utf8>().toDartString();
      calloc.free(idPtr);

      final Map<String, dynamic> response = jsonDecode(result);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(true);
    } catch (error, stackTrace) {
      Log.e('Error in delete operation', error: error, stackTrace: stackTrace);
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      if (_clearAllRecords == null) {
        return Err(ErrorLocalDb.databaseError('Database functions not bound'));
      }

      final resultFfi = _clearAllRecords!(_dbInstance!);
      final result = resultFfi != nullptr;
      return Ok(result);
    } catch (error, stackTrace) {
      Log.e(
        'Error in cleanDatabase operation',
        error: error,
        stackTrace: stackTrace,
      );
      return Err(
        ErrorLocalDb.fromRustError(
          error.toString(),
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
