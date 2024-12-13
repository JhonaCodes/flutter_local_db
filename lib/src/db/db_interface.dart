import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/data_model.dart';

@protected
@immutable
abstract interface class DataBaseInterface {
  Future<bool> delete(String id);
  Future<List<DataModel>> get({int limit = 20, int offset = 0});
  Future<DataModel> getById(String id);
  Future<bool> post(DataModel data);
  Future<DataModel> put(DataModel data);
  Future<bool> clean();
  Future<bool> deepClean();
}
