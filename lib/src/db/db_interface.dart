import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

@protected
@immutable
abstract interface class DataBaseServiceInterface {
  Future<bool> init(ConfigDBModel config);
  Future<bool> delete(String id);
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0});
  Future<DataLocalDBModel> getById(String id);
  Future<bool> post(DataLocalDBModel data);
  Future<DataLocalDBModel> put(DataLocalDBModel data);
  Future<bool> clean();
  Future<bool> deepClean();
}
