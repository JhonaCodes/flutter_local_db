import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:web/web.dart' as web;
import 'db_interface.dart';

class DataBaseVM implements DataBaseServiceInterface {
  @override
  Future<bool> init(ConfigDBModel config) async {
    _databaseName.updateState("de");

    web.window.indexedDB.open("${_databaseName.value}.dex");

    return false;
  }

  @override
  Future<List<DataLocalDBModel>> get(
      {int limit = 20, int offset = 0, bool secure = false}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> clean({bool secure = false}) {
    // TODO: implement clean
    throw UnimplementedError();
  }

  @override
  Future<bool> delete(String id, {bool secure = false}) async {
    web.window.indexedDB.deleteDatabase(_databaseName.value);
    return true;
  }

  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) {
    // TODO: implement getById
    throw UnimplementedError();
  }

  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false}) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<bool> deepClean({bool secure = false}) {
    // TODO: implement deepClean
    throw UnimplementedError();
  }
}

final _databaseName = ReactiveNotifier<String>(() => "");
