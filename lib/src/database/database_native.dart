import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import '../enum/ffi_functions.dart';
import '../enum/ffi_native_lib_location.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import '../service/local_db_result.dart';
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
  DatabaseNative._();

  static final DatabaseNative instance = DatabaseNative._();

  LocalDbResult<DynamicLibrary, String>? _lib;
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

    await _init(databaseName);
    log('Native database initialized successfully for testing');
  }

  @override
  Future<void> initialize(String databaseName) async {
    try {
      log('Initializing native DB on platform: ${Platform.operatingSystem}');

      _lastDatabaseName = databaseName;

      if (_lib == null) {
        _lib = await _loadRustNativeLib();
        log('Native library loaded: $_lib');
      }
      
      _bindFunctions();
      log('Functions bound successfully');

      final appDir = await getApplicationDocumentsDirectory();
      log('Using app directory: ${appDir.path}');

      await _init('${appDir.path}/$databaseName');
      log('Native database initialized successfully');

    } catch (e, stack) {
      log('Error initializing native database: $e');
      log('Stack trace: $stack');
      rethrow;
    }
  }

  Future<LocalDbResult<DynamicLibrary, String>> _loadRustNativeLib() async {
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

  void _bindFunctions() {
    switch (_lib) {
      case Ok(data: DynamicLibrary lib):
        _createDatabase = lib.lookupFunction<PointerAppDbStateCallBAck,
            PointerAppDbStateCallBAck>(FFiFunctions.createDb.cName);
        _post = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.pushData.cName);
        _get = lib.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(
            FFiFunctions.getAll.cName);
        _getById = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.getById.cName);
        _put = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.updateData.cName);
        _delete = lib.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(
            FFiFunctions.delete.cName);
        _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect,
            PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);
        _closeDatabase = lib.lookupFunction<Pointer<Utf8> Function(Pointer<AppDbState>),
            Pointer<Utf8> Function(Pointer<AppDbState>)>(FFiFunctions.closeDatabase.cName);
        _freeCString = lib.lookupFunction<Void Function(Pointer<Utf8>),
            void Function(Pointer<Utf8>)>(FFiFunctions.freeCString.cName);
        _isDatabaseValid = lib.lookupFunction<Bool Function(Pointer<AppDbState>),
            bool Function(Pointer<AppDbState>)>(FFiFunctions.isDatabaseValid.cName);
        break;
      case Err(error: String error):
        log(error);
        throw Exception(error);
    }
  }

  Future<void> _init(String dbName) async {
    try {
      final dbNamePointer = dbName.toNativeUtf8();
      _dbInstance = _createDatabase(dbNamePointer);

      if (_dbInstance == nullptr) {
        throw Exception('Failed to create database instance. Returned null pointer.');
      }

      calloc.free(dbNamePointer);
    } catch (error, stackTrace) {
      log('Error in _init: $error');
      log(stackTrace.toString());
      rethrow;
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
        log('Database connection invalid (Rust validation failed), attempting to reinitialize...');
        await _closeCurrentConnection();
        return await _attemptReinitialization();
      }
    } catch (e) {
      log('Error validating database connection: $e, attempting to reinitialize...');
      await _closeCurrentConnection();
      return await _attemptReinitialization();
    }

    return true;
  }

  Future<void> _closeCurrentConnection() async {
    if (_dbInstance != null && _dbInstance != nullptr) {
      try {
        if (_isDatabaseValid(_dbInstance!)) {
          final closeResult = _closeDatabase(_dbInstance!);
          if (closeResult != nullptr) {
            final resultStr = closeResult.cast<Utf8>().toDartString();
            log('Database close result: $resultStr');
            _freeCString(closeResult);
          }
        }
      } catch (e) {
        log('Error during database close: $e');
      } finally {
        _dbInstance = nullptr;
      }
    }
  }

  Future<bool> _attemptReinitialization() async {
    if (_lastDatabaseName != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        await _init('${appDir.path}/$_lastDatabaseName');
        log('Database reinitialized successfully');
        return true;
      } catch (e) {
        log('Failed to reinitialize database: $e');
        return false;
      }
    } else {
      log('Cannot reinitialize: no previous database name stored');
      return false;
    }
  }

  @override
  Future<void> closeDatabase() async {
    await _closeCurrentConnection();
    log('Database manually closed');
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    final jsonString = jsonEncode(model.toJson());
    final jsonPointer = jsonString.toNativeUtf8();

    try {
      final resultPushPointer = _post(_dbInstance!, jsonPointer);
      final dataResult = resultPushPointer.cast<Utf8>().toDartString();

      _freeCString(resultPushPointer);
      calloc.free(jsonPointer);

      final Map<String, dynamic> response = jsonDecode(dataResult);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(dataResult));
      }

      final modelData = LocalDbModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(response['Ok'])));

      return Ok(modelData);
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stack));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPtr = id.toNativeUtf8();
      final resultFfi = _getById(_dbInstance!, idPtr);

      calloc.free(idPtr);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.notFound("No model found with id: $id"));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      _freeCString(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }

      final modelData = LocalDbModel.fromJson(jsonDecode(response['Ok']));

      return Ok(modelData);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final resultFfi = _get(_dbInstance!);

      if (resultFfi == nullptr) {
        log('Error: NULL pointer returned from GetAll FFI call');
        return Err(ErrorLocalDb.notFound('Failed to retrieve data: null pointer returned'));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      _freeCString(resultFfi);

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
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final jsonString = jsonEncode(model.toJson());
      final jsonPointer = jsonString.toNativeUtf8();
      final resultFfi = _put(_dbInstance!, jsonPointer);
      final result = resultFfi.cast<Utf8>().toDartString();

      calloc.free(jsonPointer);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.notFound("No model found"));
      }

      _freeCString(resultFfi);

      final Map<String, dynamic> response = jsonDecode(result);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(LocalDbModel.fromJson(jsonDecode(response['Ok'])));
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPtr = id.toNativeUtf8();
      final deleteResult = _delete(_dbInstance!, idPtr);
      final result = deleteResult.cast<Utf8>().toDartString();
      calloc.free(idPtr);

      final Map<String, dynamic> response = jsonDecode(result);

      if (!response.containsKey('Ok')) {
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(true);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    if (!await ensureConnectionValid()) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final resultFfi = _clearAllRecords(_dbInstance!);
      final result = resultFfi != nullptr;
      return Ok(result);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(),
          originalError: error, stackTrace: stackTrace));
    }
  }
}