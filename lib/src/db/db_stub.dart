import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

import 'db_interface.dart';

class DataBase implements DataBaseInterface {
  Future<bool> init() {
    // TODO: implement init
    throw UnimplementedError();
  }

  @override
  Future<bool> clean() {
    // TODO: implement clean
    throw UnimplementedError();
  }

  @override
  Future<bool> delete(String id) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<List<DataModel>> get({int limit = 20, int offset = 0}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<bool> post(DataModel data) {
    log("From db_stup");
    // TODO: implement post
    throw UnimplementedError();
  }

  @override
  Future<DataModel> getById(String id) {
    print("Error");
    print(id);
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
