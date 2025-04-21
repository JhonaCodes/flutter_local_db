import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
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


class LocalDbBridge extends LocalSbRequestImpl with WidgetsBindingObserver {
  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  LocalDbResult<DynamicLibrary, String>? _lib;
  Pointer<AppDbState>? _dbInstance; // Cambiado de late a nullable
  String? _lastDatabaseName; // Almacena el último nombre de base de datos utilizado


  void registerLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  void unregisterLifecycleObserver() {
    WidgetsBinding.instance.removeObserver(this);
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        log('App paused, preparing to save state');
        // Podríamos hacer alguna limpieza parcial aquí
        break;
      case AppLifecycleState.resumed:
        log('App resumed, checking database connection');
        // Verificar la conexión cuando la app se reanuda
        ensureConnectionValid();
        break;
      case AppLifecycleState.detached:
        log('App detached, cleaning up resources');
        dispose();
        break;
      default:
      // Manejar otros estados
        break;
    }
  }

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
      // Limpiar recursos previos si existen
      await dispose();

      WidgetsBinding.instance.addObserver(this);

      log('Initializing DB on platform: ${Platform.operatingSystem}');

      _lastDatabaseName = databaseName;

      if(_lib == null) {
        /// Initialize native library.
        _lib = await CurrentPlatform.loadRustNativeLib();
      }
      log('Library loaded: ${_lib}');

      /// Bind functions.
      _bindFunctions();
      log('Functions bound successfully');

      /// Define default route.
      final appDir = await getApplicationDocumentsDirectory();
      log('Using app directory: ${appDir.path}');

      /// Initialize database with retries
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          await _init('${appDir.path}/$databaseName');
          log('Database initialized successfully on attempt ${retryCount + 1}');

          if (_dbInstance != null && _dbInstance != nullptr) {
            break;
          } else {
            log('Warning: _init completed but _dbInstance is null or nullptr');
            await Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)));
            retryCount++;
          }
        } catch (e) {
          log('Error initializing database on attempt ${retryCount + 1}: $e');
          await Future.delayed(Duration(milliseconds: 200 * (retryCount + 1)));
          retryCount++;
        }
      }

      if (_dbInstance == null || _dbInstance == nullptr) {
        log('Failed to initialize database after $maxRetries attempts');
        // Podrías lanzar una excepción aquí o simplemente continuar
      }

    } catch (e, stack) {
      log('Error initializing database: $e');
      log('Stack trace: $stack');
      rethrow;
    }
  }

  Future<bool> ensureConnectionValid() async {
    // Verificar si la instancia es válida
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Database connection invalid, attempting to reinitialize...');

      if (_lastDatabaseName != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          await _init('${appDir.path}/$_lastDatabaseName');

          // Verificar si la reinicialización fue exitosa
          if (_dbInstance != null && _dbInstance != nullptr) {
            log('Database reinitialized successfully');
            return true;
          } else {
            // Si después de reinicializar sigue siendo nulo, esperamos un poco y reintentamos
            log('Reinitialization resulted in null pointer, waiting and retrying...');
            await Future.delayed(Duration(milliseconds: 500));
            await _init('${appDir.path}/$_lastDatabaseName');

            // Verificar nuevamente
            if (_dbInstance != null && _dbInstance != nullptr) {
              log('Database reinitialized successfully on second attempt');
              return true;
            } else {
              log('Failed to reinitialize database after multiple attempts');
              return false;
            }
          }
        } catch (e) {
          log('Failed to reinitialize database: $e');
          return false;
        }
      } else {
        log('Cannot reinitialize: no previous database name stored');
        return false;
      }
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
  late final void Function(Pointer<AppDbState>) _closeDatabase;

  /// Bind functiopns for initialization
  void _bindFunctions() {
    switch (_lib) {
      case Ok(data: DynamicLibrary lib):
        _createDatabase = lib.lookupFunction<PointerAppDbStateCallBAck,
            PointerAppDbStateCallBAck>(FFiFunctions.createDb.cName);
        _post = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.pushData.cName);
        _get =
            lib.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(
                FFiFunctions.getAll.cName);
        _getById = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.getById.cName);
        _put = lib.lookupFunction<PointerStringFFICallBack,
            PointerStringFFICallBack>(FFiFunctions.updateData.cName);
        _delete =
            lib.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(
                FFiFunctions.delete.cName);
        _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect,
            PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);

        _closeDatabase = lib.lookupFunction<Void Function(Pointer<AppDbState>),
            void Function(Pointer<AppDbState>)>(FFiFunctions.closeDatabase.cName);
        break;
      case Err(error: String error):
        log(error);
        throw Exception(error);
    }
  }

  Future<void> _init(String dbName) async {
    try {

      final dbFile = File(dbName);
      final dbExists = await dbFile.exists();

      final dbNamePointer = dbName.toNativeUtf8();

      // Intentar crear/abrir la base de datos
      _dbInstance = _createDatabase(dbNamePointer);
      calloc.free(dbNamePointer);

      // Manejar el caso donde _createDatabase devuelve null
      if (_dbInstance == nullptr) {
        // En lugar de lanzar una excepción, registramos el problema
        log('Warning: Database instance creation returned null pointer.');

        // Si la base de datos existe físicamente pero no pudimos abrir la instancia
        // podría ser por un problema temporal o de permisos
        if (dbExists) {
          log('Database file exists but could not be opened. This may be temporary.');
          // No lanzamos excepción para permitir que la app continúe y pueda reintentar más tarde
        } else {
          // Si el archivo no existe, es un problema más serio
          log('Database file does not exist and could not be created.');
          // Aquí podrías lanzar una excepción, pero vamos a ser más permisivos
        }
      } else {
        log('Database initialized successfully at: $dbName');
      }
    } catch (error, stackTrace) {
      log('Error in _init: $error');
      log(stackTrace.toString());
      // No relanzamos la excepción para permitir que la app continúe funcionando
      // pero aún así registramos el error para depuración
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


  Future<void> dispose() async {
    // Si _dbInstance no es nulo, deberíamos limpiarlo
    if (_dbInstance != null && _dbInstance != nullptr) {
      try {
        // Usar la función FFI para cerrar/liberar la base de datos
        _closeDatabase(_dbInstance!);

        // Establecer _dbInstance a null después de cerrarla
        _dbInstance = null;

        log('Database resources successfully released');
      } catch (e) {
        log('Error disposing database: $e');

        // Aún así, intentar establecer _dbInstance a null para evitar problemas futuros
        _dbInstance = null;
      }
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
}
