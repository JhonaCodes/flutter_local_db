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

/// FFI function signatures
typedef PointerStringFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBack = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef PointerBoolFFICallBack = Pointer<Bool> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerBoolFFICallBackDirect = Pointer<Bool> Function(Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);

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

  /// FFI function bindings
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerListFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;
  late final PointerBoolFFICallBack _delete;
  late final PointerBoolFFICallBackDirect _clearAllRecords;

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
          return Err(DbError.connectionError('Failed to load native library: $error'));
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
      Log.e('Failed to initialize NativeDatabase', error: e, stackTrace: stackTrace);
      return Err(DbError.connectionError(
        'Database initialization failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> insert(String key, Map<String, dynamic> data) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    if (!DatabaseValidator.isValidData(data)) {
      return Err(DbError.validationError('The provided data format is invalid'));
    }

    try {
      Log.d('NativeDatabase.insert: $key');

      // Check if key already exists
      final existsResult = await get(key);
      if (existsResult.isOk) {
        return Err(DbError.validationError(
          "Cannot create new record: ID '$key' already exists. Use update method to modify existing records."
        ));
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
        final resultPointer = _post(_dbInstance!, jsonPointer);
        final resultString = resultPointer.cast<Utf8>().toDartString();

        calloc.free(resultPointer);
        calloc.free(jsonPointer);

        // Parse response
        final response = jsonDecode(resultString) as Map<String, dynamic>;
        
        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        final responseData = jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final resultEntry = _mapToDbEntry(responseData);

        Log.i('Record inserted successfully: $key');
        return Ok(resultEntry);

      } catch (e) {
        calloc.free(jsonPointer);
        throw e;
      }

    } catch (e, stackTrace) {
      Log.e('Failed to insert record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Insert operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> get(String key) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    try {
      Log.d('NativeDatabase.get: $key');

      final keyPointer = key.toNativeUtf8();
      
      try {
        final resultPointer = _getById(_dbInstance!, keyPointer);
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

        final responseData = jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final entry = _mapToDbEntry(responseData);

        Log.d('Record retrieved successfully: $key');
        return Ok(entry);

      } catch (e) {
        calloc.free(keyPointer);
        throw e;
      }

    } catch (e, stackTrace) {
      Log.e('Failed to get record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Get operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<DbEntry>> update(String key, Map<String, dynamic> data) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    try {
      Log.d('NativeDatabase.update: $key');

      // Verify record exists
      final existsResult = await get(key);
      if (existsResult.isErr) {
        return Err(DbError.notFound(
          "Record '$key' not found. Use insert method to create new records."
        ));
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
        final resultPointer = _put(_dbInstance!, jsonPointer);
        final resultString = resultPointer.cast<Utf8>().toDartString();

        calloc.free(jsonPointer);
        malloc.free(resultPointer);

        final response = jsonDecode(resultString) as Map<String, dynamic>;
        
        if (!response.containsKey('Ok')) {
          return Err(_parseRustError(resultString));
        }

        final responseData = jsonDecode(response['Ok'] as String) as Map<String, dynamic>;
        final resultEntry = _mapToDbEntry(responseData);

        Log.i('Record updated successfully: $key');
        return Ok(resultEntry);

      } catch (e) {
        calloc.free(jsonPointer);
        throw e;
      }

    } catch (e, stackTrace) {
      Log.e('Failed to update record: $key', error: e, stackTrace: stackTrace);
      return Err(DbError.databaseError(
        'Update operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<void>> delete(String key) async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    if (!DatabaseValidator.isValidKey(key)) {
      return Err(DbError.validationError(DatabaseValidator.getKeyValidationError(key)));
    }

    try {
      Log.d('NativeDatabase.delete: $key');

      final keyPointer = key.toNativeUtf8();
      
      try {
        final resultPointer = _delete(_dbInstance!, keyPointer);
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
      return Err(DbError.databaseError(
        'Delete operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<List<DbEntry>>> getAll() async {
    if (!await _ensureConnectionValid()) {
      return Err(DbError.connectionError('Database connection is invalid'));
    }

    try {
      Log.d('NativeDatabase.getAll');

      final resultPointer = _get(_dbInstance!);

      if (resultPointer == nullptr) {
        Log.w('GetAll returned null pointer');
        return Err(DbError.databaseError('Failed to retrieve data: null pointer returned'));
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
      return Err(DbError.databaseError(
        'GetAll operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<DbResult<List<String>>> getAllKeys() async {
    // Get all entries and extract keys
    final allResult = await getAll();
    return allResult.map((entries) => entries.map((entry) => entry.id).toList());
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
      return Err(DbError.databaseError(
        'Clear operation failed: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<bool> isConnectionValid() async {
    return _isInitialized && _dbInstance != null && _dbInstance != nullptr;
  }

  @override
  Future<void> close() async {
    Log.i('NativeDatabase.close');
    _dbInstance = null;
    _isInitialized = false;
  }

  /// Loads the native library for the current platform
  Future<Result<DynamicLibrary, String>> _loadNativeLibrary() async {
    try {
      if (Platform.isAndroid) {
        Log.d('Loading Android library');
        return Ok(DynamicLibrary.open(FFiNativeLibLocation.android.lib));
      }

      if (Platform.isMacOS) {
        Log.d('Loading macOS library');
        try {
          final arch = await FFiNativeLibLocation.macos.toMacosArchPath();
          return Ok(DynamicLibrary.open(arch));
        } catch (e) {
          Log.w('Failed to load architecture-specific library, trying default: $e');
          return Ok(DynamicLibrary.open(FFiNativeLibLocation.macos.lib));
        }
      }

      if (Platform.isIOS) {
        Log.d('Loading iOS library');
        try {
          return Ok(DynamicLibrary.process());
        } catch (e) {
          return Ok(DynamicLibrary.open(FFiNativeLibLocation.ios.lib));
        }
      }

      return Err("Unsupported platform: ${Platform.operatingSystem}");

    } catch (e) {
      return Err("Error loading library: $e");
    }
  }

  /// Binds FFI functions from the native library
  void _bindFunctions() {
    if (_lib == null) {
      throw StateError('Library not loaded');
    }

    try {
      _createDatabase = _lib!.lookupFunction<PointerAppDbStateCallBack, PointerAppDbStateCallBack>(
        FFiFunctions.createDb.cName
      );
      
      _post = _lib!.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
        FFiFunctions.pushData.cName
      );
      
      _get = _lib!.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(
        FFiFunctions.getAll.cName
      );
      
      _getById = _lib!.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
        FFiFunctions.getById.cName
      );
      
      _put = _lib!.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(
        FFiFunctions.updateData.cName
      );
      
      _delete = _lib!.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(
        FFiFunctions.delete.cName
      );
      
      _clearAllRecords = _lib!.lookupFunction<PointerBoolFFICallBackDirect, PointerBoolFFICallBackDirect>(
        FFiFunctions.clearAllRecords.cName
      );

      Log.d('All FFI functions bound successfully');

    } catch (e) {
      throw Exception('Failed to bind FFI functions: $e');
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
        throw Exception('Failed to create database instance. Returned null pointer.');
      }

      Log.d('Database instance created successfully');

    } finally {
      calloc.free(pathPointer);
    }
  }

  /// Ensures the database connection is valid, reinitializing if needed
  Future<bool> _ensureConnectionValid() async {
    if (!_isInitialized || _dbInstance == null || _dbInstance == nullptr) {
      Log.w('Database connection invalid, attempting to reestablish');
      
      if (_lastDatabaseName != null) {
        try {
          final config = DbConfig(name: _lastDatabaseName!);
          final result = await initialize(config);
          return result.isOk;
        } catch (e) {
          Log.e('Failed to reestablish database connection', error: e);
          return false;
        }
      }
      return false;
    }
    return true;
  }

  /// Parses a Rust error response
  DbError _parseRustError(String errorResponse) {
    try {
      final response = jsonDecode(errorResponse) as Map<String, dynamic>;
      if (response.containsKey('Err')) {
        final errorData = response['Err'] as String;
        return DbError.databaseError('Rust error: $errorData');
      }
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