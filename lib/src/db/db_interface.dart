import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

@protected
@immutable
abstract interface class DataBaseServiceInterface {
  Future<bool> init(ConfigDBModel config);
  Future<bool> delete(String id, {bool secure = false});
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0, bool secure = false});
  Future<DataLocalDBModel> getById(String id, {bool secure = false});
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false});
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false});
  Future<bool> clean({bool secure = false});
  Future<bool> deepClean({bool secure = false});
}
