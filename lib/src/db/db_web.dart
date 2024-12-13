import 'package:flutter_local_db/src/model/data_model.dart';

import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:web/web.dart' as web;
import 'db_interface.dart';

class DataBase implements DataBaseInterface {

  Future<bool> init() async{

    _databaseName.updateState("de");

    web.window.indexedDB.open("${_databaseName.value}.db");


    return false;
  }

  @override
  Future<List<DataModel>> get({int limit = 20, int offset = 0}) {
    // TODO: implement get
    throw UnimplementedError();
  }


  @override
  Future<bool> post(DataModel data) {

    throw UnimplementedError();
  }

  @override
  Future<bool> clean() {
    // TODO: implement clean
    throw UnimplementedError();
  }

  @override
  Future<bool> delete(String id) async{
    web.window.indexedDB.deleteDatabase(_databaseName.value);
    return true;
  }

  @override
  Future<DataModel> getById(String id) {
    // TODO: implement getById
    throw UnimplementedError();
  }

  @override
  Future<DataModel> put(DataModel data) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<bool> deepClean() {
    // TODO: implement deepClean
    throw UnimplementedError();
  }



}

final _databaseName = ReactiveNotifier<String>(() => "");