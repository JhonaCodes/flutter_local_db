import 'dart:developer';

import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

import 'db_interface.dart';

class DataBaseVM implements DataBaseServiceInterface {
  @override
  Future<bool> init(ConfigDBModel config) {
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
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<bool> post(DataLocalDBModel data) {
    log("From db_stup");
    // TODO: implement post
    throw UnimplementedError();
  }

  @override
  Future<DataLocalDBModel> getById(String id) {
    log("Error");
    // TODO: implement getById
    throw UnimplementedError();
  }

  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data) {
    // TODO: implement put
    throw UnimplementedError();
  }

  @override
  Future<bool> deepClean() {
    // TODO: implement deepClean
    throw UnimplementedError();
  }
}
