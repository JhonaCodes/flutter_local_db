import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:result_controller/result_controller.dart';

import '../enum/ffi_functions.dart';
import '../enum/ffi_native_lib_location.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'database_interface.dart';

/// opaque extension
final class AppDbState extends Opaque {}

/// Typedef for the rust functions
typedef PointerStringFFICallBack = Pointer<Utf8> Function(
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBAck = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef PointerBoolFFICallBack = Pointer<Bool> Function(
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerBoolFFICallBackDirect = Pointer<Bool> Function(Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);

/// Native database implementation using FFI and Rust backend
/// This implementation is used for mobile and desktop platforms
class DatabaseNative implements DatabaseInterface {

  Result<DynamicLibrary, String>? _lib;
  Pointer<AppDbState>? _dbInstance;
  String? _lastDatabaseName;

  /// Functions registration
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerListFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;
  late final PointerBoolFFICallBack _delete;
  late final PointerBoolFFICallBackDirect _clearAllRecords;
  late final Pointer<Utf8> Function(Pointer<AppDbState>) _closeDatabase;
  late final void Function(Pointer<Utf8>) _freeCString;
  late final bool Function(Pointer<AppDbState>) _isDatabaseValid;

  @override
  bool get isSupported => !Platform.isLinux && !Platform.isWindows;

  @override
  String get platformName => 'native';

  Future<void> initForTesting(String databaseName, String libPath) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }
    _lastDatabaseName = databaseName;
    if (_lib == null) {
      _lib = Ok(DynamicLibrary.open(libPath));
    }
    
    _bindFunctions();
    log('Functions bound successfully');

    final initResult = await _init(databaseName);
    if (initResult.isErr) {
      throw Exception('Failed to initialize test database: ${initResult.errorOrNull}');
    }
    log('Native database initialized successfully for testing');
  }

  @override
  Future<void> initialize(String databaseName) async {
    log('Initializing native DB on platform: ${Platform.operatingSystem}');

    _lastDatabaseName = databaseName;

    if (_lib == null || _lib!.isErr) {
      _lib = await _loadRustNativeLib();
      if (_lib!.isErr) {
        throw Exception('Failed to load native library: ${_lib!.errorOrNull}');
      }
      log('Native library loaded successfully');
    }
    
    _bindFunctions();
    log('Functions bound successfully');

    final appDir = await getApplicationDocumentsDirectory();
    log('Using app directory: ${appDir.path}');

    final initResult = await _init('${appDir.path}/$databaseName');
    if (initResult.isErr) {
      throw Exception('Failed to initialize database: ${initResult.errorOrNull}');
    }
    log('Native database initialized successfully');
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

    return Err('Unsupported platform for native database: ${Platform.operatingSystem}');
  }

  void _bindFunctions() {
    if (_lib == null || _lib!.isErr) {
      throw Exception('Library not loaded');
    }
    
    final lib = _lib!.data!;
    try {
      _createDatabase = lib.lookupFunction<Pointer<AppDbState> Function(Pointer<Utf8>),
          Pointer<AppDbState> Function(Pointer<Utf8>)>(FFiFunctions.createDb.cName);

      _post = lib.lookupFunction<PointerStringFFICallBack,
          PointerStringFFICallBack>(FFiFunctions.pushData.cName);

      _get = lib.lookupFunction<PointerListFFICallBack,
          PointerListFFICallBack>(FFiFunctions.getAll.cName);

      _getById = lib.lookupFunction<PointerStringFFICallBack,
          PointerStringFFICallBack>(FFiFunctions.getById.cName);

      _put = lib.lookupFunction<PointerStringFFICallBack,
          PointerStringFFICallBack>(FFiFunctions.updateData.cName);

      _delete = lib.lookupFunction<PointerBoolFFICallBack,
          PointerBoolFFICallBack>(FFiFunctions.delete.cName);

      _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect,
          PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);

      _closeDatabase = lib.lookupFunction<Pointer<Utf8> Function(Pointer<AppDbState>),
          Pointer<Utf8> Function(Pointer<AppDbState>)>(FFiFunctions.closeDatabase.cName);

      _freeCString = lib.lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>(FFiFunctions.freeCString.cName);

      _isDatabaseValid = lib.lookupFunction<Bool Function(Pointer<AppDbState>),
          bool Function(Pointer<AppDbState>)>(FFiFunctions.isDatabaseValid.cName);

    } catch (error) {
        log('Error binding functions: $error');
        throw Exception(error);
    }
  }

  Future<Result<void, String>> _init(String dbName) async {
    try {
      final dbNamePointer = dbName.toNativeUtf8();
      _dbInstance = _createDatabase(dbNamePointer);

      if (_dbInstance == nullptr) {
        calloc.free(dbNamePointer);
        return Err('Failed to create database instance. Returned null pointer.');
      }

      calloc.free(dbNamePointer);
      return Ok(());
    } catch (error) {
      return Err('Error in _init: $error');
    }
  }

  @override
  Future<bool> ensureConnectionValid() async {
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Database connection invalid (null pointer), attempting to reinitialize...');
      return await _attemptReinitialization();
    }

    try {
      if (!_isDatabaseValid(_dbInstance!)) {
        log('Database connection invalid (validation failed), attempting to reinitialize...');
        return await _attemptReinitialization();
      }
      return true;
    } catch (e) {
      log('Error checking database validity: $e');
      return await _attemptReinitialization();
    }
  }

  Future<bool> _attemptReinitialization() async {
    if (_lastDatabaseName == null) {
      log('Cannot reinitialize: no database name stored');
      return false;
    }
    
    try {
      // Clean up existing connection first
      if (_dbInstance != null && _dbInstance != nullptr) {
        try {
          final closeResult = _closeDatabase(_dbInstance!);
          final closeMessage = closeResult.toDartString();
          log('Cleanup result: $closeMessage');
          _freeCString(closeResult);
        } catch (e) {
          log('Warning: Error during cleanup: $e');
        }
        _dbInstance = nullptr; // Always reset to null pointer
      }
      
      log('Attempting to reinitialize database: $_lastDatabaseName');
      await initialize(_lastDatabaseName!);
      return true;
    } catch (e) {
      log('Failed to reinitialize database: $e');
      return false;
    }
  }

  @override
  Future<void> closeDatabase() async {
    if (_dbInstance != null && _dbInstance != nullptr) {
      try {
        final closeResult = _closeDatabase(_dbInstance!);
        final message = closeResult.toDartString();
        log('Database closed: $message');
        
        _freeCString(closeResult);
        _dbInstance = nullptr;
      } catch (e) {
        log('Error closing database: $e');
        rethrow;
      }
    }
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final jsonPointer = jsonEncode(model.toJson()).toNativeUtf8();
      final resultPointer = _post(_dbInstance!, jsonPointer);
      final result = resultPointer.toDartString();
      
      calloc.free(jsonPointer);
      _freeCString(resultPointer);
      
      if (result.startsWith('ERROR:')) {
        return Err(ErrorLocalDb.databaseError(result.substring(6)));
      }
      
      final responseMap = jsonDecode(result) as Map<String, dynamic>;
      return Ok(LocalDbModel.fromJson(responseMap));
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to create record: $error'));
    }
  }

  @override
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPointer = id.toNativeUtf8();
      final resultPointer = _getById(_dbInstance!, idPointer);
      final result = resultPointer.toDartString();
      
      calloc.free(idPointer);
      _freeCString(resultPointer);
      
      if (result.startsWith('ERROR:')) {
        return Err(ErrorLocalDb.databaseError(result.substring(6)));
      }
      
      if (result == 'null' || result.isEmpty) {
        return Ok(null);
      }
      
      final responseMap = jsonDecode(result) as Map<String, dynamic>;
      return Ok(LocalDbModel.fromJson(responseMap));
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to get record: $error'));
    }
  }

  @override
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final resultPointer = _get(_dbInstance!);
      final result = resultPointer.toDartString();
      
      _freeCString(resultPointer);
      
      if (result.startsWith('ERROR:')) {
        return Err(ErrorLocalDb.databaseError(result.substring(6)));
      }
      
      if (result == '[]' || result.isEmpty) {
        return Ok(<LocalDbModel>[]);
      }
      
      final responseList = jsonDecode(result) as List<dynamic>;
      final models = responseList
          .map((item) => LocalDbModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return Ok(models);
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to get all records: $error'));
    }
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final jsonPointer = jsonEncode(model.toJson()).toNativeUtf8();
      final resultPointer = _put(_dbInstance!, jsonPointer);
      final result = resultPointer.toDartString();
      
      calloc.free(jsonPointer);
      _freeCString(resultPointer);
      
      if (result.startsWith('ERROR:')) {
        return Err(ErrorLocalDb.databaseError(result.substring(6)));
      }
      
      final responseMap = jsonDecode(result) as Map<String, dynamic>;
      return Ok(LocalDbModel.fromJson(responseMap));
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to update record: $error'));
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPointer = id.toNativeUtf8();
      final resultPointer = _delete(_dbInstance!, idPointer);
      final success = resultPointer.value;
      
      calloc.free(idPointer);
      
      return Ok(success);
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to delete record: $error'));
    }
  }

  @override
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final resultPointer = _clearAllRecords(_dbInstance!);
      final success = resultPointer.value;
      
      return Ok(success);
    } catch (error) {
      return Err(ErrorLocalDb.databaseError('Failed to clear database: $error'));
    }
  }
}

/// Factory function for conditional imports
DatabaseInterface createDatabase() => DatabaseNative();