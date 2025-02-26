import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_local_db/src/enum/ffi_functions.dart';

import 'package:flutter_local_db/src/enum/ffi_native_lib_location.dart';
import 'package:flutter_local_db/src/interface/local_db_request_impl.dart';
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
typedef PointerBoolFFICallBackDirect = Pointer<Bool> Function(
    Pointer<AppDbState>);
typedef PointerListFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>);

class LocalDbBridge extends LocalSbRequestImpl {
  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  late LocalDbResult<DynamicLibrary, String> _lib;
  late Pointer<AppDbState> _dbInstance;

  Future<void> initForTesting(String databaseName, String libPath) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }

    /// Initialize native library.
    _lib = Ok(DynamicLibrary.open(libPath));

    /// Bind functions.
    _bindFunctions();

    /// Define default route.
    final appDir = await getApplicationDocumentsDirectory();

    /// Initialize database with default route and database name.
    _init('${appDir.path}/$databaseName');
  }

  Future<void> initialize(String databaseName) async {
    if (!databaseName.contains('.db')) {
      databaseName = '$databaseName.db';
    }

    /// Initialize native library.
    _lib = await CurrentPlatform.loadRustNativeLib();

    /// Bind functions.
    _bindFunctions();

    /// Define default route.
    final appDir = await getApplicationDocumentsDirectory();

    /// Initialize database with default route and database name.
    _init('${appDir.path}/$databaseName');
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

      calloc.free(dbNamePointer);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
    }
  }

  @override
  Future<LocalDbResult<LocalDbRequestModel, String>> post(
      LocalDbRequestModel model) async {
    final jsonString = jsonEncode(model.toJson());
    final jsonPointer = jsonString.toNativeUtf8();

    try {
      final resultPushPointer = _post(_dbInstance, jsonPointer);

      final dataResult = resultPushPointer.cast<Utf8>().toDartString();

      calloc.free(resultPushPointer);

      calloc.free(jsonPointer);

      final modelData = LocalDbRequestModel.fromJson(jsonDecode(dataResult));

      return Ok(modelData);
    } catch (error, stack) {
      log(error.toString());
      log(stack.toString());
      return Err(error.toString());
    }
  }

  @override
  Future<LocalDbResult<LocalDbRequestModel?, String>> getById(String id) async {
    try {
      final idPtr = id.toNativeUtf8();
      final resultFfi = _getById(_dbInstance, idPtr);

      // Liberar memoria del id
      calloc.free(idPtr);

      if (resultFfi == nullptr) {
        return const Err("Not found");
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();
      malloc.free(resultFfi);

      final modelData =
          LocalDbRequestModel.fromJson(jsonDecode(resultTransformed));

      return Ok(modelData);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(error.toString());
    }
  }

  @override
  Future<LocalDbResult<LocalDbRequestModel, String>> put(
      LocalDbRequestModel model) async {
    try {
      final jsonString = jsonEncode(model.toJson());
      final jsonPointer = jsonString.toNativeUtf8();
      final resultFfi = _put(_dbInstance, jsonPointer);
      final result = resultFfi.cast<Utf8>().toDartString();

      calloc.free(jsonPointer);

      if (resultFfi == nullptr) {
        return const Err("Not found");
      }

      malloc.free(resultFfi);

      return Ok(LocalDbRequestModel.fromJson(jsonDecode(result)));
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(error.toString());
    }
  }

  @override
  Future<LocalDbResult<bool, String>> cleanDatabase() async {
    try {
      final resultFfi = _clearAllRecords(_dbInstance);
      final result = resultFfi != nullptr;
      malloc.free(resultFfi);
      return Ok(result);
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(error.toString());
    }
  }

  @override
  Future<LocalDbResult<bool, String>> delete(String id) async {
    try {
      final idPtr = id.toNativeUtf8();
      final deleteResult = _delete(_dbInstance, idPtr);

      calloc.free(idPtr);

      return Ok(deleteResult.address == 1);
    } catch (e, stack) {
      log(e.toString());
      log(stack.toString());
      return Err(e.toString());
    }
  }

  @override
  Future<LocalDbResult<List<LocalDbRequestModel>, String>> getAll() async {
    try {
      final resultFfi = _get(_dbInstance);

      if (resultFfi == nullptr) {
        log('Error: NULL pointer returned from GetAll FFI call');
        return Err('Failed to retrieve data: null pointer returned');
      }

      final resultTransformed = resultFfi.cast<Utf8>().toDartString();

      /// Because no need anymore and the reference is on [resultTransformed]
      malloc.free(resultFfi);

      final List<dynamic> jsonList = jsonDecode(resultTransformed);

      final List<LocalDbRequestModel> dataList =
          jsonList.map((json) => LocalDbRequestModel.fromJson(json)).toList();

      return Ok(dataList);
    } catch (e, stack) {
      log(e.toString());
      log(stack.toString());
      return Err(e.toString());
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
      return Ok(DynamicLibrary.open(FFiNativeLibLocation.ios.lib));
    }

    return Err("Unsupported platform: ${Platform.operatingSystem}");
  }
}
