import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
// Asegúrate que estas rutas sean correctas y apunten a tus archivos
import 'package:flutter_local_db/src/enum/ffi_functions.dart';
import 'package:flutter_local_db/src/enum/ffi_native_lib_location.dart';
import 'package:flutter_local_db/src/interface/local_db_request_impl.dart';
// Importa tus modelos de error y datos
import 'package:flutter_local_db/src/model/local_db_error_model.dart'; // Contiene ErrorLocalDb, ErrorType, DetailsModel

import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:flutter_local_db/src/service/local_db_result.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;

/// opaque extension
final class AppDbState extends Opaque {}

/// Typedefs para las funciones FFI
typedef PointerStringFFICallBack = Pointer<Utf8> Function(
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBack = Pointer<AppDbState> Function(Pointer<Utf8>); // Corregido nombre B Ack -> CallBack
typedef PointerBoolFFICallBack = Pointer<Bool> Function(
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerBoolFFICallBackDirect = Pointer<Bool> Function(Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);
// Typedef para close_database
typedef VoidAppDbStateCallBack = Void Function(Pointer<AppDbState>); // Nativo
typedef DartVoidAppDbStateCallBack = void Function(Pointer<AppDbState>); // Dart


// Clase simplificada, sin WidgetsBindingObserver
class LocalDbBridge extends LocalSbRequestImpl {
  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  LocalDbResult<DynamicLibrary, String>? _lib;
  // ¡CAMBIO IMPORTANTE! Instancia nullable para manejar estado explícitamente
  Pointer<AppDbState>? _dbInstance;

  // Funciones FFI vinculadas
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerListFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;
  // Usando los booleanos como en tu último código
  late final PointerBoolFFICallBack _delete;
  late final PointerBoolFFICallBackDirect _clearAllRecords;
  // Binding para la nueva función de cierre
  late final DartVoidAppDbStateCallBack _closeDatabase;

  // initForTesting (simplificado y adaptado a nullable _dbInstance)
  Future<void> initForTesting(String databaseName, String libPath) async {
    // Asegurar limpieza previa si se llama múltiples veces en tests
    await dispose();

    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }
    if (_lib == null) {
      _lib = Ok(DynamicLibrary.open(libPath));
    }
    _bindFunctions(); // Vincular funciones (incluyendo _closeDatabase)
    final appDir = await getApplicationDocumentsDirectory();
    try {
      await _init('${appDir.path}/$databaseName');
      if (_dbInstance == null) {
        throw Exception("initForTesting failed: _dbInstance is null after _init.");
      }
    } catch (e) {
      log("Error during initForTesting: $e");
      rethrow; // Relanzar para que el test falle si la inicialización no funciona
    }
  }

  // initialize (con dispose al inicio y manejo de estado nullable)
  Future<void> initialize(String databaseName) async {
    try {
      log('Initializing DB on platform: ${Platform.operatingSystem}');

      // --- LLAMADA A DISPOSE (AHORA SEGURA) ---
      // Intenta cerrar/liberar cualquier instancia nativa previa ANTES de continuar.
      await dispose();
      log('Previous instance disposed (if any).');
      // --------------------------------------

      // Añadir extensión .db si falta
      if (!databaseName.contains('.db')) {
        log('Adding .db extension to database name.');
        databaseName = '$databaseName.db';
      }

      // Cargar librería si no está cargada
      if (_lib == null) {
        _lib = await CurrentPlatform.loadRustNativeLib();
        if (_lib case Err(error: final err)) {
          throw Exception("Failed to load native library: $err");
        }
        log('Library loaded: ${_lib}');
      }

      // Vincular funciones (esto es seguro llamarlo varias veces)
      _bindFunctions();
      log('Functions bound successfully');

      final appDir = await getApplicationDocumentsDirectory();
      log('Using app directory: ${appDir.path}');

      // Llamar a _init para crear/abrir la nueva instancia (asignará a _dbInstance?)
      await _init('${appDir.path}/$databaseName');

      // Verificación post-_init explícita
      if (_dbInstance == null) {
        // _init debería haber lanzado error, pero doble verificación por seguridad
        throw Exception("Initialization failed: _dbInstance is null after _init completed.");
      }

      log('Database initialized successfully');

    } catch (e, stack) {
      log('Error initializing database: $e \nStack: $stack');
      _dbInstance = null; // Asegurar nulidad en caso de fallo de inicialización
      rethrow; // Relanzar para que el código que llama (ej. main) sepa del fallo.
    }
  }

  // _bindFunctions (incluyendo _closeDatabase)
  void _bindFunctions() {
    switch (_lib) {
      case Ok(data: DynamicLibrary lib):
        _createDatabase = lib.lookupFunction<PointerAppDbStateCallBack, PointerAppDbStateCallBack>(FFiFunctions.createDb.cName);
        _post = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.pushData.cName);
        _get = lib.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(FFiFunctions.getAll.cName);
        _getById = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.getById.cName);
        _put = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.updateData.cName);
        // Usando los booleanos como estaban definidos en tu código
        _delete = lib.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(FFiFunctions.delete.cName);
        _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect, PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);
        // Añadir binding para close_database
        _closeDatabase = lib.lookupFunction<VoidAppDbStateCallBack, DartVoidAppDbStateCallBack>('close_database');
        break;
      case Err(error: String error):
        log(error);
        throw Exception("Failed to bind native functions: $error");
    }
  }

  // _init (adaptado para nullable y lanzar error en fallo)
  Future<void> _init(String dbName) async {
    Pointer<Utf8>? dbNamePointer;
    try {
      dbNamePointer = dbName.toNativeUtf8();
      final newInstance = _createDatabase(dbNamePointer);

      if (newInstance == nullptr) {
        _dbInstance = null; // Asegurar estado null
        log('Error: _createDatabase returned a null pointer for $dbName');
        // Lanzar excepción clara indicando el fallo
        throw Exception('Native database creation/opening failed (returned null pointer).');
      } else {
        // Asignar solo en caso de éxito
        _dbInstance = newInstance;
        log('Database instance created successfully for $dbName');
      }
    } catch (error, stackTrace) {
      _dbInstance = null; // Asegurar estado null en cualquier error
      log('Error during _init: ${error.toString()}');
      log(stackTrace.toString());
      // Relanzar para que initialize lo maneje
      throw Exception('Failed during FFI _init: $error');
    } finally {
      if (dbNamePointer != null) {
        calloc.free(dbNamePointer);
      }
    }
  }

  // dispose (seguro con _dbInstance nullable)
  Future<void> dispose() async {
    if (_dbInstance != null && _dbInstance != nullptr) {
      final instanceToClose = _dbInstance!;
      log('Dispose: Instance found, attempting to close.');
      _dbInstance = null; // Marcar como null inmediatamente
      try {
        log('Calling native close_database...');
        _closeDatabase(instanceToClose);
        log('Native close_database called successfully.');
      } catch (e, s) {
        log('Error calling native close_database: $e\n$s');
      }
    } else {
      log('dispose() called but _dbInstance is already null or nullptr.');
      _dbInstance = null; // Asegurarse de que sea null
    }
  }


  // --- Métodos CRUD Adaptados ---
  // Todos verifican nulidad de _dbInstance al inicio
  // Usan LocalDbModel
  // delete y cleanDatabase usan lógica booleana

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(LocalDbModel model) async {
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: post called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------

    Pointer<Utf8>? jsonPointer;
    try {
      final jsonString = jsonEncode(model.toJson());
      jsonPointer = jsonString.toNativeUtf8();
      // Usar '!' es seguro después de la verificación
      final resultPushPointer = _post(_dbInstance!, jsonPointer);

      if (resultPushPointer == nullptr) {
        log('Error: post FFI call returned null pointer.');
        return Err(ErrorLocalDb.databaseError('FFI post returned null pointer'));
      }

      final dataResult = resultPushPointer.cast<Utf8>().toDartString();
      // Liberar resultado FFI (asumiendo malloc en Rust)
      malloc.free(resultPushPointer);

      // Parsear respuesta JSON
      final Map<String, dynamic> response = jsonDecode(dataResult);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) { modelJson = jsonDecode(okData); }
        else if (okData is Map) { modelJson = Map<String, dynamic>.from(okData); }
        else { return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for post')); }
        // Usar LocalDbModel
        final modelData = LocalDbModel.fromJson(modelJson);
        return Ok(modelData);
      } else {
        return Err(ErrorLocalDb.fromRustError(dataResult));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in post: ${e.toString()}');
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stack) {
      log('Catch block error in post: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during post', originalError: error, stackTrace: stack));
    } finally {
      if (jsonPointer != null) { calloc.free(jsonPointer); }
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> getById(String id) async { // Retorna LocalDbModel?
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: getById called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------
    Pointer<Utf8>? idPtr;
    try {
      idPtr = id.toNativeUtf8();
      final resultFfi = _getById(_dbInstance!, idPtr);

      if (resultFfi == nullptr) {
        // nullptr aquí SÍ significa no encontrado
        return Err(ErrorLocalDb.notFound("No model found with id: $id (FFI returned null)"));
        // O si prefieres retornar Ok(null) en caso de no encontrado:
        // return Ok(null);
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) { modelJson = jsonDecode(okData); }
        else if (okData is Map) { modelJson = Map<String, dynamic>.from(okData); }
        else { return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for getById')); }
        final modelData = LocalDbModel.fromJson(modelJson);
        return Ok(modelData);
      } else {
        // El error de Rust podría ser NotFound también, fromRustError debería manejarlo
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in getById: ${e.toString()}');
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in getById: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during getById', originalError: error, stackTrace: stackTrace));
    } finally {
      if (idPtr != null) { calloc.free(idPtr); }
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(LocalDbModel model) async {
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: put called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------
    Pointer<Utf8>? jsonPointer;
    try {
      final jsonString = jsonEncode(model.toJson());
      jsonPointer = jsonString.toNativeUtf8();
      final resultFfi = _put(_dbInstance!, jsonPointer);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.databaseError("FFI put returned null pointer"));
      }

      final result = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi);

      final Map<String, dynamic> response = jsonDecode(result);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) { modelJson = jsonDecode(okData); }
        else if (okData is Map) { modelJson = Map<String, dynamic>.from(okData); }
        else { return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for put')); }
        return Ok(LocalDbModel.fromJson(modelJson));
      } else {
        return Err(ErrorLocalDb.fromRustError(result));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in put: ${e.toString()}');
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in put: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during put', originalError: error, stackTrace: stackTrace));
    } finally {
      if (jsonPointer != null) { calloc.free(jsonPointer); }
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: cleanDatabase called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------
    try {
      // --- LÓGICA CORRECTA para Pointer<Bool> ---
      final resultPtr = _clearAllRecords(_dbInstance!);
      bool success = resultPtr != nullptr;

      // NO liberar resultPtr con malloc.free a menos que estés 100% seguro que Rust lo requiere.

      if (success) {
        return Ok(true);
      } else {
        // FFI devolvió null, indica fallo en la operación nativa.
        return Err(ErrorLocalDb.databaseError("FFI clearAllRecords failed (returned null)"));
      }
      // --- Fin lógica Pointer<Bool> ---

    } catch (error, stackTrace) {
      log('Catch block error in cleanDatabase: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during cleanDatabase', originalError: error, stackTrace: stackTrace));
    }
  }


  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: delete called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------
    Pointer<Utf8>? idPtr;
    try {
      idPtr = id.toNativeUtf8();

      // --- LÓGICA CORRECTA para Pointer<Bool> ---
      final resultPtr = _delete(_dbInstance!, idPtr);
      bool success = resultPtr != nullptr;

      // NO liberar resultPtr con malloc.free a menos que estés 100% seguro que Rust lo requiere.

      if (success) {
        return Ok(true);
      } else {
        // Aquí podría ser NotFound o un error DB. Si Rust no distingue,
        // retornamos un error genérico. NotFound sería más específico si
        // nullptr específicamente significa "no encontrado".
        return Err(ErrorLocalDb.databaseError("FFI delete failed (returned null)"));
        // Alternativa si nullptr significa no encontrado:
        // return Err(ErrorLocalDb.notFound("FFI delete failed for id $id (returned null)"));
      }
      // --- Fin lógica Pointer<Bool> ---

    } catch (error, stackTrace) {
      log('Catch block error in delete: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during delete', originalError: error, stackTrace: stackTrace));
    } finally {
      if (idPtr != null) { calloc.free(idPtr); }
    }
  }

  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    // --- Verificación de Nulidad ---
    if (_dbInstance == null || _dbInstance == nullptr) {
      log('Error: getAll called but database instance is null.');
      return Err(ErrorLocalDb.databaseError('Database is not initialized.'));
    }
    // ---------------------------------
    try {
      final resultFfi = _get(_dbInstance!);

      if (resultFfi == nullptr) {
        log('Error: NULL pointer returned from GetAll FFI call');
        // Podría ser Ok([]) o error. Mantendremos error por consistencia con fallos FFI.
        return Err(ErrorLocalDb.databaseError('FFI getAll returned null pointer'));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi);

      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (response.containsKey('Ok')) {
        final dynamic okData = response['Ok'];
        List<dynamic> jsonList;
        if (okData is String) { jsonList = jsonDecode(okData); }
        else if (okData is List) { jsonList = okData; }
        else { return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for getAll')); }
        // Usar LocalDbModel
        final List<LocalDbModel> dataList = jsonList
            .map((json) => LocalDbModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        return Ok(dataList);
      } else {
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in getAll: ${e.toString()}');
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in getAll: ${error.toString()}');
      return Err(ErrorLocalDb.unknown('Dart exception during getAll', originalError: error, stackTrace: stackTrace));
    }
  }
} // Fin de LocalDbBridge


// CurrentPlatform (sin cambios, asumiendo que es correcta)
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