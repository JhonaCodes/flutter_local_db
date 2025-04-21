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

/// Typedefs (sin cambios)
typedef PointerStringFFICallBack = Pointer<Utf8> Function(
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBack = Pointer<AppDbState> Function(Pointer<Utf8>);
typedef PointerBoolFFICallBack = Pointer<Bool> Function( // Usado si delete/clear devuelven Bool
    Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerBoolFFICallBackDirect = Pointer<Bool> Function( // Usado si clear devuelve Bool sin ID
    Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);
typedef VoidAppDbStateCallBack = Void Function(Pointer<AppDbState>); // Nativo
typedef DartVoidAppDbStateCallBack = void Function(Pointer<AppDbState>); // Dart

// Clase simplificada, sin WidgetsBindingObserver
class LocalDbBridge extends LocalSbRequestImpl {
  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  LocalDbResult<DynamicLibrary, String>? _lib;
  late Pointer<AppDbState> _dbInstance;

  // initForTesting (sin cambios funcionales)
  Future<void> initForTesting(String databaseName, String libPath) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }
    if (_lib == null) {
      _lib = Ok(DynamicLibrary.open(libPath));
    }
    _bindFunctions();
    final appDir = await getApplicationDocumentsDirectory();
    await _init('${appDir.path}/$databaseName');
  }

  // initialize (simplificado)
  Future<void> initialize(String databaseName) async {
    try {
      log('Initializing DB on platform: ${Platform.operatingSystem}');

      // --- LLAMADA A DISPOSE ---
      // Intenta cerrar/liberar cualquier instancia nativa previa ANTES de continuar.
      await dispose();
      log('Previous instance disposed (if any).');
      // ------------------------

      // Añadir extensión .db si falta
      if (!databaseName.contains('.db')) {
        log('Adding .db extension to database name.');
        databaseName = '$databaseName.db';
      }

      if (_lib == null) {
        _lib = await CurrentPlatform.loadRustNativeLib();
        if (_lib case Err(error: final err)) {
          // Si la carga de la librería falla, lanzar error inmediatamente
          throw Exception("Failed to load native library: $err");
        }
        log('Library loaded: ${_lib}');
      }

      // Vincular funciones (esto es seguro llamarlo varias veces si _lib ya existe)
      _bindFunctions();
      log('Functions bound successfully');

      final appDir = await getApplicationDocumentsDirectory();
      log('Using app directory: ${appDir.path}');

      // Llamar a _init para crear/abrir la nueva instancia
      await _init('${appDir.path}/$databaseName');
      log('Database initialized successfully');

    } catch (e, stack) {
      log('Error initializing database: $e \nStack: $stack');
      // Relanzar para que el código que llama a initialize (ej. main) sepa del fallo.
      rethrow;
    }
  }

  /// Function bindings (sin _closeDatabase)
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerListFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;
  // *** REVISAR TIPOS DE RETORNO DE RUST PARA delete Y clearAllRecords ***
  // Asumiendo JSON para delete (como en el 2do ejemplo)
  late final PointerStringFFICallBack _delete;
  // Asumiendo JSON para clearAllRecords (para consistencia, aunque el 2do ejemplo usaba Bool)

  late final PointerBoolFFICallBackDirect _clearAllRecords;
  // Si devuelven Bool, usa los typedefs comentados abajo y ajusta el lookup y la lógica en los métodos.
  // late final PointerBoolFFICallBack _delete;
  late final DartVoidAppDbStateCallBack _closeDatabase;


  // _bindFunctions (adaptado para asumir JSON en delete/clear)
  void _bindFunctions() {
    switch (_lib) {
      case Ok(data: DynamicLibrary lib):
        _createDatabase = lib.lookupFunction<PointerAppDbStateCallBack, PointerAppDbStateCallBack>(FFiFunctions.createDb.cName);
        _post = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.pushData.cName);
        _get = lib.lookupFunction<PointerListFFICallBack, PointerListFFICallBack>(FFiFunctions.getAll.cName);
        _getById = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.getById.cName);
        _put = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.updateData.cName);
        // Asumiendo JSON
        _delete = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.delete.cName);
        _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect, PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);
        // Si devuelven Bool, usa esto:
        // _delete = lib.lookupFunction<PointerBoolFFICallBack, PointerBoolFFICallBack>(FFiFunctions.delete.cName);
        // _clearAllRecords = lib.lookupFunction<PointerBoolFFICallBackDirect, PointerBoolFFICallBackDirect>(FFiFunctions.clearAllRecords.cName);
        _closeDatabase = lib.lookupFunction<VoidAppDbStateCallBack, DartVoidAppDbStateCallBack>(FFiFunctions.closeDatabase.cName);

        break;
      case Err(error: String error):
        log(error);
        throw Exception(error); // Fallo crítico al cargar la librería
    }
  }

  // _init (simplificado)
  Future<void> _init(String dbName) async {
    Pointer<Utf8>? dbNamePointer; // Hacerlo nullable para el finally
    try {
      dbNamePointer = dbName.toNativeUtf8();
      _dbInstance = _createDatabase(dbNamePointer);

      if (_dbInstance == nullptr) {
        log('Error: _createDatabase returned a null pointer for $dbName');
        // Lanzar excepción porque sin instancia no se puede operar
        throw Exception('Failed to initialize database instance (null pointer).');
      } else {
        log('Database instance created successfully for $dbName');
      }
    } catch (error, stackTrace) {
      log('Error during _init: ${error.toString()}');
      log(stackTrace.toString());
      // Relanzar para que initialize() lo maneje
      throw Exception('Failed during FFI _init: $error');
    } finally {
      // Asegurar liberación del puntero
      if (dbNamePointer != null) {
        calloc.free(dbNamePointer);
      }
    }
  }

  // --- Métodos CRUD usando ErrorLocalDb y asumiendo JSON de FFI ---

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> post(
      LocalDbModel model) async {
    Pointer<Utf8>? jsonPointer; // Nullable para finally
    try {
      // Simple check, _init debería haber lanzado error si falló
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }

      final jsonString = jsonEncode(model.toJson());
      jsonPointer = jsonString.toNativeUtf8();

      final resultPushPointer = _post(_dbInstance, jsonPointer);

      if (resultPushPointer == nullptr) {
        log('Error: post FFI call returned null pointer.');
        // Usar un error específico de DB/FFI
        return Err(ErrorLocalDb.databaseError('FFI post returned null pointer'));
      }

      final dataResult = resultPushPointer.cast<Utf8>().toDartString();
      malloc.free(resultPushPointer); // Liberar resultado FFI

      // Parsear la respuesta JSON esperada {"Ok":...} o {"Err":...}
      final Map<String, dynamic> response = jsonDecode(dataResult);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) {
          modelJson = jsonDecode(okData);
        } else if (okData is Map) {
          modelJson = Map<String, dynamic>.from(okData);
        } else {
          // Usar error de serialización
          return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for post'));
        }
        final modelData = LocalDbModel.fromJson(modelJson);
        return Ok(modelData);
      } else {
        // Dejar que fromRustError interprete el error de Rust
        return Err(ErrorLocalDb.fromRustError(dataResult));
      }
    } on FormatException catch (e, s) { // Error específico de jsonDecode
      log('JSON FormatException in post: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stack) {
      log('Catch block error in post: ${error.toString()}');
      log(stack.toString());
      // Usar error desconocido para excepciones generales de Dart
      return Err(ErrorLocalDb.unknown('Dart exception during post', originalError: error, stackTrace: stack));
    } finally {
      // Asegurar liberación del puntero de entrada
      if (jsonPointer != null) {
        calloc.free(jsonPointer);
      }
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> getById(String id) async {
    Pointer<Utf8>? idPtr; // Nullable para finally
    try {
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }
      idPtr = id.toNativeUtf8();
      final resultFfi = _getById(_dbInstance, idPtr);

      if (resultFfi == nullptr) {
        // nullptr en getById específicamente significa "no encontrado" según convención común
        return Err(ErrorLocalDb.notFound("No model found with id: $id (FFI returned null)"));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi); // Liberar resultado FFI

      // Parsear respuesta JSON
      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) {
          modelJson = jsonDecode(okData);
        } else if (okData is Map) {
          modelJson = Map<String, dynamic>.from(okData);
        } else {
          return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for getById'));
        }
        final modelData = LocalDbModel.fromJson(modelJson);
        return Ok(modelData);
      } else {
        // Dejar que fromRustError interprete la respuesta de error
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in getById: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in getById: ${error.toString()}');
      log(stackTrace.toString());
      return Err(ErrorLocalDb.unknown('Dart exception during getById', originalError: error, stackTrace: stackTrace));
    } finally {
      if (idPtr != null) {
        calloc.free(idPtr);
      }
    }
  }

  @override
  Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> put(
      LocalDbModel model) async {
    Pointer<Utf8>? jsonPointer; // Nullable para finally
    try {
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }
      final jsonString = jsonEncode(model.toJson());
      jsonPointer = jsonString.toNativeUtf8();
      final resultFfi = _put(_dbInstance, jsonPointer);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.databaseError("FFI put returned null pointer"));
      }

      final result = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi); // Liberar resultado FFI

      // Parsear respuesta JSON
      final Map<String, dynamic> response = jsonDecode(result);

      if (response.containsKey('Ok')) {
        final okData = response['Ok'];
        final Map<String, dynamic> modelJson;
        if (okData is String) {
          modelJson = jsonDecode(okData);
        } else if (okData is Map) {
          modelJson = Map<String, dynamic>.from(okData);
        } else {
          return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for put'));
        }
        return Ok(LocalDbModel.fromJson(modelJson));
      } else {
        return Err(ErrorLocalDb.fromRustError(result));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in put: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in put: ${error.toString()}');
      log(stackTrace.toString());
      return Err(ErrorLocalDb.unknown('Dart exception during put', originalError: error, stackTrace: stackTrace));
    } finally {
      if (jsonPointer != null) {
        calloc.free(jsonPointer);
      }
    }
  }

  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> cleanDatabase() async {
    try {
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }

      // *** ASUMIENDO QUE _clearAllRecords DEVUELVE JSON Pointer<Utf8> ***
      final resultFfi = _clearAllRecords(_dbInstance);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.databaseError("FFI clearAllRecords returned null pointer"));
      }

      final result = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi); // Liberar resultado FFI

      final Map<String, dynamic> response = jsonDecode(result);

      if (response.containsKey('Ok')) {
        // Asumiendo que Ok indica éxito booleano
        return Ok(true);
      } else {
        return Err(ErrorLocalDb.fromRustError(result));
      }
      // --- Fin lógica JSON ---

      /* --- LÓGICA ALTERNATIVA SI DEVUELVE Pointer<Bool> ---
      // 1. Cambia el typedef y lookup de _clearAllRecords a PointerBoolFFICallBackDirect
      // 2. Usa esta lógica:
      final resultPtr = _clearAllRecords(_dbInstance);
      bool success = resultPtr != nullptr;
      // Liberar si es necesario (revisar Rust): if (success) { malloc.free(resultPtr); }
      if (success) {
         return Ok(true);
      } else {
         return Err(ErrorLocalDb.databaseError("FFI clearAllRecords failed (returned null)"));
      }
      */

    } on FormatException catch (e, s) { // Solo si parseas JSON
      log('JSON FormatException in cleanDatabase: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in cleanDatabase: ${error.toString()}');
      log(stackTrace.toString());
      return Err(ErrorLocalDb.unknown('Dart exception during cleanDatabase', originalError: error, stackTrace: stackTrace));
    }
  }


  @override
  Future<LocalDbResult<bool, ErrorLocalDb>> delete(String id) async {
    Pointer<Utf8>? idPtr; // Nullable para finally
    try {
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }
      idPtr = id.toNativeUtf8();

      // *** ASUMIENDO QUE _delete DEVUELVE JSON Pointer<Utf8> ***
      final resultFfi = _delete(_dbInstance, idPtr);

      if (resultFfi == nullptr) {
        return Err(ErrorLocalDb.databaseError("FFI delete returned null pointer"));
      }
      final result = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi); // Liberar resultado FFI

      final Map<String, dynamic> response = jsonDecode(result);

      if (response.containsKey('Ok')) {
        // Asumiendo que Ok indica éxito booleano
        return Ok(true);
      } else {
        return Err(ErrorLocalDb.fromRustError(result));
      }
      // --- Fin lógica JSON ---

      /* --- LÓGICA ALTERNATIVA SI DEVUELVE Pointer<Bool> ---
      // 1. Cambia el typedef y lookup de _delete a PointerBoolFFICallBack
      // 2. Usa esta lógica:
      final resultPtr = _delete(_dbInstance, idPtr);
      bool success = resultPtr != nullptr;
      // Liberar si es necesario (revisar Rust): if (success) { malloc.free(resultPtr); }
      if (success) {
         return Ok(true);
      } else {
         // Podría ser NotFound si el ID no existe, o DatabaseError si falla.
         // Si Rust distingue, necesitarías más info. Asumamos error general.
         return Err(ErrorLocalDb.databaseError("FFI delete failed (returned null or false)"));
      }
      */

    } on FormatException catch (e, s) { // Solo si parseas JSON
      log('JSON FormatException in delete: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in delete: ${error.toString()}');
      log(stackTrace.toString());
      return Err(ErrorLocalDb.unknown('Dart exception during delete', originalError: error, stackTrace: stackTrace));
    } finally {
      if (idPtr != null) {
        calloc.free(idPtr);
      }
    }
  }


  @override
  Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    try {
      // ignore: unnecessary_null_comparison
      if (_dbInstance == null || _dbInstance == nullptr) {
        return Err(ErrorLocalDb.databaseError('Database instance is not valid.'));
      }
      final resultFfi = _get(_dbInstance);

      if (resultFfi == nullptr) {
        log('Error: NULL pointer returned from GetAll FFI call');
        // Un null aquí podría significar error o simplemente lista vacía.
        // Si significa lista vacía, deberías retornar Ok([]).
        // Asumamos que significa error FFI.
        return Err(ErrorLocalDb.databaseError('FFI getAll returned null pointer'));
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi); // Liberar resultado FFI

      // Parsear respuesta JSON {"Ok": [...]}
      final Map<String, dynamic> response = jsonDecode(resultTransformed);

      if (response.containsKey('Ok')) {
        final dynamic okData = response['Ok'];
        List<dynamic> jsonList;
        if (okData is String) {
          jsonList = jsonDecode(okData);
        } else if (okData is List) {
          jsonList = okData;
        } else {
          return Err(ErrorLocalDb.serializationError('Unexpected data type in "Ok" field for getAll'));
        }
        // Mapear la lista usando LocalDbModel
        final List<LocalDbModel> dataList = jsonList
            .map((json) => LocalDbModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        return Ok(dataList);
      } else {
        return Err(ErrorLocalDb.fromRustError(resultTransformed));
      }
    } on FormatException catch (e, s) {
      log('JSON FormatException in getAll: ${e.toString()}');
      log(s.toString());
      return Err(ErrorLocalDb.serializationError('Failed to decode FFI response JSON', originalError: e, stackTrace: s));
    } catch (error, stackTrace) {
      log('Catch block error in getAll: ${error.toString()}');
      log(stackTrace.toString());
      return Err(ErrorLocalDb.unknown('Dart exception during getAll', originalError: error, stackTrace: stackTrace));
    }
  }


  // Método para llamar al cierre nativo
  Future<void> dispose() async {
    // Verificamos que _dbInstance no sea nullptr ANTES de intentar cerrarla.
    // Esto es importante si initialize falló parcialmente o si dispose se llama accidentalmente dos veces.
    // Como _dbInstance es `late final`, no puede ser null si initialize tuvo éxito.
    // La comprobación principal es contra `nullptr`.
    if (_dbInstance != nullptr) {
      try {
        log('Calling native close_database...');
        // Llama a la función FFI que acabamos de vincular
        _closeDatabase(_dbInstance);
        log('Native close_database called successfully.');

        // ¡Importante! Aunque la memoria nativa se libera, _dbInstance en Dart
        // todavía contiene la dirección de memoria (ahora inválida).
        // Para evitar usarla accidentalmente, lo IDEAL sería ponerla a null.
        // PERO, como es `late final`, no podemos.
        // La llamada a dispose() ANTES de _init() en el NUEVO initialize()
        // se encargará de obtener una NUEVA instancia válida si es necesario.
        // Solo debemos asegurarnos de no usar _dbInstance después de llamar a dispose
        // hasta que initialize() la reasigne.

      } catch (e, s) {
        // Captura errores específicos de FFI si ocurren durante el cierre
        log('Error calling native close_database: $e\n$s');
        // Podrías decidir si relanzar o solo registrar el error.
        // En general, un fallo al cerrar es menos crítico que uno al abrir.
      }
    } else {
      log('dispose() called but _dbInstance is nullptr (already closed or never initialized?).');
    }
  }
}


// CurrentPlatform se mantiene igual
sealed class CurrentPlatform {
  static Future<LocalDbResult<DynamicLibrary, String>>
  loadRustNativeLib() async {
    if (Platform.isAndroid) {
      // Ajusta esta ruta si es necesario
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
          // Ajusta esta ruta si es necesario
          return Ok(DynamicLibrary.open(FFiNativeLibLocation.ios.lib));
        } catch (error) {
          // Usar ErrorLocalDb aquí también podría ser una opción, pero String es más simple para la carga de la lib
          return Err("Error loading library on iOS: $error");
        }
      }
    }
    return Err("Unsupported platform: ${Platform.operatingSystem}");
  }
}