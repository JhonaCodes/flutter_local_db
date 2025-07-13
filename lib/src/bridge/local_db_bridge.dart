import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_local_db/src/enum/ffi_functions.dart';

import 'package:flutter_local_db/src/enum/ffi_native_lib_location.dart';
import 'package:flutter_local_db/src/interface/local_db_request_impl.dart';
import 'package:flutter_local_db/src/model/local_db_error_model.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:flutter_local_db/src/service/local_db_result.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io' show Platform;

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

class LocalDbBridge extends LocalSbRequestImpl {
  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  LocalDbResult<DynamicLibrary, String>? _lib;
  Pointer<AppDbState>? _dbInstance; // Cambiado de late a nullable
  String? _lastDatabaseName; // Almacena el último nombre de base de datos utilizado
  bool _hotRestartDetected = false; // Flag para detectar hot restart

  Future<void> initForTesting(String databaseName, String libPath) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }

    _lastDatabaseName = databaseName;

    if(_lib == null) {
      /// Initialize native library.
      _lib = Ok(DynamicLibrary.open(libPath));
    }
    /// Bind functions.
    _bindFunctions();

    /// Define default route.
    final appDir = await getApplicationDocumentsDirectory();

    /// Initialize database with default route and database name.
    await _init('${appDir.path}/$databaseName');
  }

  Future<void> initialize(String databaseName) async {
    try {
      log('Initializing DB on platform: ${Platform.operatingSystem}');

      _lastDatabaseName = databaseName;

      if(_lib == null) {
        /// Initialize native library.
        _lib = await CurrentPlatform.loadRustNativeLib();
        log('Library loaded: ${_lib}');
      }

      // Verify library was loaded successfully
      switch (_lib) {
        case Ok(data: DynamicLibrary lib):
          log('Library loaded successfully: $lib');
          break;
        case Err(error: String error):
          log('Failed to load library: $error');
          throw Exception('Failed to load native library: $error');
        case null:
          log('Library is null');
          throw Exception('Native library is null');
      }

      /// Bind functions.
      _bindFunctions();
      log('Functions bound successfully');

      /// Define default route.
      final appDir = await getApplicationDocumentsDirectory();
      log('Using app directory: ${appDir.path}');

      /// Initialize database with default route and database name.
      await _init('${appDir.path}/$databaseName');
      log('Database initialized successfully');

    } catch (e, stack) {
      log('Error initializing database: $e');
      log('Stack trace: $stack');
      rethrow;
    }
  }

  /// Método para verificar si la conexión es válida y reinicializar si es necesario
  Future<bool> ensureConnectionValid() async {
    // Verificar si la instancia es válida o si se detectó hot restart
    if (_dbInstance == null || _dbInstance == nullptr || _hotRestartDetected) {
      log('Database connection invalid (hot restart: $_hotRestartDetected), attempting to reinitialize...');

      if (_lastDatabaseName != null) {
        try {
          // Reset hot restart flag
          _hotRestartDetected = false;
          
          // Reinicializar solo la instancia de base de datos, no la librería
          final appDir = await getApplicationDocumentsDirectory();
          await _init('${appDir.path}/$_lastDatabaseName');
          log('Database reinitialized successfully after hot restart');
          return true;
        } catch (e) {
          log('Failed to reinitialize database: $e');
          _hotRestartDetected = true; // Marcar para próximo intento
          return false;
        }
      } else {
        log('Cannot reinitialize: no previous database name stored');
        return false;
      }
    }

    // Test the connection with a simple operation to detect stale pointers
    try {
      if (_dbInstance != null && _dbInstance != nullptr) {
        // Intentar una operación mínima para verificar si el puntero es válido
        final testResult = _get(_dbInstance!);
        if (testResult == nullptr) {
          log('Database pointer appears stale, marking for reinitialization');
          _hotRestartDetected = true;
          return await ensureConnectionValid(); // Recursiva para reinicializar
        }
        // Liberar el resultado de test inmediatamente
        malloc.free(testResult);
      }
    } catch (e) {
      log('Connection test failed, marking for reinitialization: $e');
      _hotRestartDetected = true;
      return await ensureConnectionValid(); // Recursiva para reinicializar
    }

    return true;
  }

  /// Functions registration
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerListFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;
  late final PointerBoolFFICallBack _delete;
  late final PointerBoolFFICallBackDirect _clearAllRecords;

  /// Bind functiopns for initialization
  void _bindFunctions() {
    switch (_lib) {
      case Ok(data: DynamicLibrary lib):
        try {
          log('Binding function: ${FFiFunctions.createDb.cName}');
          _createDatabase = lib.lookupFunction<PointerAppDbStateCallBAck,
              PointerAppDbStateCallBAck>(FFiFunctions.createDb.cName);
          
          log('Binding function: ${FFiFunctions.pushData.cName}');
          _post = lib.lookupFunction<PointerStringFFICallBack,
              PointerStringFFICallBack>(FFiFunctions.pushData.cName);
          
          log('Binding function: ${FFiFunctions.getAll.cName}');
          _get =
              lib.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(
                  FFiFunctions.getAll.cName);
          
          log('Binding function: ${FFiFunctions.getById.cName}');
          _getById = lib.lookupFunction<PointerStringFFICallBack,
              PointerStringFFICallBack>(FFiFunctions.getById.cName);
          
          log('Binding function: ${FFiFunctions.updateData.cName}');
          _put = lib.lookupFunction<PointerStringFFICallBack,
              PointerStringFFICallBack>(FFiFunctions.updateData.cName);
          
          log('Binding function: ${FFiFunctions.delete.cName}');
          _delete =
              lib.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(
                  FFiFunctions.delete.cName);
          
          log('Binding function: ${FFiFunctions.clearAllRecords.cName}');
          _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect,
              PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);
          
          log('All functions bound successfully');
        } catch (e) {
          log('Error binding functions: $e');
          throw Exception('Failed to bind FFI functions: $e');
        }
        break;
      case Err(error: String error):
        log(error);
        throw Exception(error);
    }
  }

  Future<void> _init(String dbName) async {
    try {
      log('Attempting to create database with path: $dbName');
      
      // Verify _createDatabase function is properly bound
      if (_createDatabase == null) {
        throw Exception('_createDatabase function is not properly bound');
      }

      final dbNamePointer = dbName.toNativeUtf8();
      log('Created native UTF8 pointer for database name');

      // Si ya existe una instancia, vamos a crear una nueva de todos modos
      log('Calling _createDatabase function...');
      _dbInstance = _createDatabase(dbNamePointer);
      log('_createDatabase returned: ${_dbInstance.toString()}');

      if (_dbInstance == nullptr) {
        calloc.free(dbNamePointer);
        throw Exception('Failed to create database instance. Returned null pointer. This usually means the Rust library is not properly loaded or the database path is invalid.');
      }

      // Reset hot restart flag on successful initialization
      _hotRestartDetected = false;
      log('Database instance created successfully: ${_dbInstance.toString()}');

      calloc.free(dbNamePointer);
    } catch (error, stackTrace) {
      log('Error in _init: $error');
      log(stackTrace.toString());
      _hotRestartDetected = true;
      rethrow;
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async{
    if (!(await ensureConnectionValid())) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    final jsonString = jsonEncode(model.toJson());
    final jsonPointer = jsonString.toNativeUtf8();

    try {
      final resultPushPointer = _post(_dbInstance!, jsonPointer);

      final dataResult = resultPushPointer.cast<Utf8>().toDartString();

      calloc.free(resultPushPointer);
      calloc.free(jsonPointer);

      final Map<String,dynamic> response = jsonDecode(dataResult);

      if(!response.containsKey('Ok')){
        return Err(ErrorLocalDb.fromRustError(dataResult));
      }

      final modelData = LocalDbModel.fromJson(Map<String, dynamic>.from(jsonDecode(response['Ok'])));

      return Ok(modelData);
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      print(stack.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stack));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> getById(String id) async{
    if (!(await ensureConnectionValid())) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPtr = id.toNativeUtf8();
      final resultFfi = _getById(_dbInstance!, idPtr);

      // Liberar memoria del id
      calloc.free(idPtr);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.notFound("No model found with id: $id"));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if(!response.containsKey('Ok')){
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }

      final modelData =
      LocalDbModel.fromJson(jsonDecode(response['Ok']));

      return Ok(modelData);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async{
    if (!(await ensureConnectionValid())) {
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

      malloc.free(resultFfi);

      final Map<String, dynamic> response = jsonDecode(result);

      if(!response.containsKey('Ok')){
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(LocalDbModel.fromJson(jsonDecode(response['Ok'])));
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async{
    if (!(await ensureConnectionValid())) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final resultFfi = _clearAllRecords(_dbInstance!);
      final result = resultFfi != nullptr;
      malloc.free(resultFfi);
      return Ok(result);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async{
    if (!(await ensureConnectionValid())) {
      return Err(ErrorLocalDb.databaseError('Database connection is invalid'));
    }

    try {
      final idPtr = id.toNativeUtf8();
      final deleteResult = _delete(_dbInstance!, idPtr);
      final result = deleteResult.cast<Utf8>().toDartString();
      calloc.free(idPtr);

      final Map<String, dynamic> response = jsonDecode(result);

      if(!response.containsKey('Ok')){
        return Err(ErrorLocalDb.fromRustError(result));
      }

      return Ok(true);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stackTrace));
    }
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    // Verificar la conexión antes de proceder
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

      /// Because no need anymore and the reference is on [resultTransformed]
      malloc.free(resultFfi);

      final Map<String, dynamic> response = await jsonDecode(resultTransformed);

      if(!response.containsKey('Ok')){
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }

      final List<dynamic> jsonList = await jsonDecode(response['Ok']);

      final List<LocalDbModel> dataList =
      jsonList.map((json) => LocalDbModel.fromJson(Map<String,dynamic>.from(json))).toList();

      return Ok(dataList);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(ErrorLocalDb.fromRustError(error.toString(), originalError: error, stackTrace: stackTrace));
    }
  }
}

sealed class CurrentPlatform {
  static Future<LocalDbResult<DynamicLibrary, String>>
  loadRustNativeLib() async {
    if (Platform.isAndroid) {
      return Ok(DynamicLibrary.open(FFiNativeLibLocation.android.lib));
    }

    if (Platform.isMacOS) {
      try {
        final arch = await FFiNativeLibLocation.macos.toMacosArchPath();
        log('Attempting to load macOS library: $arch');
        return Ok(DynamicLibrary.open(arch));
      } catch (e) {
        log('Failed to load architecture-specific library, trying default: $e');
        try {
          return Ok(DynamicLibrary.open(FFiNativeLibLocation.macos.lib));
        } catch (e2) {
          return Err("Error loading library on macOS: $e2");
        }
      }
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
}