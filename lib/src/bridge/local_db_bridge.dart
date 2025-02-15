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


/// opaque extension
final class AppDbState extends Opaque {}

/// Typedef for the rust functions
typedef PointerStringFFICallBack = Pointer<Utf8> Function(Pointer<AppDbState>, Pointer<Utf8>);
typedef PointerAppDbStateCallBAck = Pointer<AppDbState> Function(Pointer<Utf8>);


class LocalDbBridge extends LocalSbRequestImpl{

  LocalDbBridge._();

  static final LocalDbBridge instance = LocalDbBridge._();

  late final LocalDbResult<DynamicLibrary, String> _lib;
  late final Pointer<AppDbState> _dbInstance;


  Future<void> initialize(String databaseName) async {
    _lib = CurrentPlatform.loadRustNativeLib();
    _bindFunctions();

    final appDir = await getApplicationDocumentsDirectory();

    _init('${appDir.path}/$databaseName');
  }






  /// Functions registration
  late final Pointer<AppDbState> Function(Pointer<Utf8>) _createDatabase;
  late final PointerStringFFICallBack _post;
  late final PointerStringFFICallBack _get;
  late final PointerStringFFICallBack _getById;
  late final PointerStringFFICallBack _put;


  /// Bind functiopns for initialization
  void _bindFunctions(){
    switch(_lib){
      case Ok(data: DynamicLibrary lib):
        _createDatabase = lib.lookupFunction<PointerAppDbStateCallBAck, PointerAppDbStateCallBAck>(FFiFunctions.createDb.cName);
        _post = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.pushData.cName);
        _get = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.getAll.cName);
        _getById = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.getById.cName);
        _put = lib.lookupFunction<PointerStringFFICallBack, PointerStringFFICallBack>(FFiFunctions.updateData.cName);
        break;
        case Err(error: String error):
          throw Exception(error);
    }
  }

  Future<void> _init(String dbName)async{
    try{

      final dbNamePointer = dbName.toNativeUtf8();
      _dbInstance = _createDatabase(dbNamePointer);

      calloc.free(dbNamePointer);

    }catch(error, stackTrace){
      log(error.toString());
      log(stackTrace.toString());
    }
  }


  @override
  Future<LocalDbResult<LocalDbRequestModel,String>> post(LocalDbRequestModel model) async{

    final jsonString = jsonEncode(model.toJson());
    final jsonPointer = jsonString.toNativeUtf8();

    try{


      final resultPushPointer = _post(_dbInstance, jsonPointer);

      final dataResult = resultPushPointer.cast<Utf8>().toDartString();

      calloc.free(resultPushPointer);

      calloc.free(jsonPointer);

      final  modelData = LocalDbRequestModel.fromJson(jsonDecode(dataResult));

      return Ok(modelData);

    }catch(error, stack){
      log(error.toString());
      log(stack.toString());
      return Err(error.toString());
    }

  }


  @override
  Future<LocalDbResult<LocalDbRequestModel?,String>> getById(String id) async{
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

      final  modelData = LocalDbRequestModel.fromJson(jsonDecode(resultTransformed));

      return Ok(modelData);

    } catch(error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
      return Err(error.toString());
    }
  }

  @override
  Future<LocalDbResult<LocalDbRequestModel, String>> put(LocalDbRequestModel model) {
    // TODO: implement put
    throw UnimplementedError();
  }
  
  // @override
  // Future<bool> cleanDatabase(LocalDbRequestModel model) {
  //   // TODO: implement cleanDatabase
  //   throw UnimplementedError();
  // }

  @override
  Future<bool> delete(String id) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<LocalDbResult<List<LocalDbRequestModel>, String>> getAll() {
    // TODO: implement getAll
    throw UnimplementedError();
  }
  



}

sealed class CurrentPlatform {
  static LocalDbResult<DynamicLibrary, String> loadRustNativeLib() {
    if (Platform.isAndroid) {
      Ok(DynamicLibrary.open(FFiNativeLibLocation.android.lib));
    }

    if (Platform.isMacOS) {
      Ok(DynamicLibrary.open(FFiNativeLibLocation.macos.lib));
    }

    if (Platform.isIOS) {
      Ok(DynamicLibrary.open(FFiNativeLibLocation.ios.lib));
    }

    return Err("Unsupported platform: ${Platform.operatingSystem}");
  }
}
