import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/repository/db_device_repository.dart';

import 'db_interface.dart';

class DataBaseVM implements DataBaseServiceInterface {

  @override
  Future<bool> init(ConfigDBModel config) async {
    return await repositoryNotifier.value.init(config);
  }

  @override
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0, bool secure = false}) async {
    return await repositoryNotifier.value.get(limit: limit, offset: offset);
  }

  @override
  Future<DataLocalDBModel> post(DataLocalDBModel data, {bool secure = false}) async => await repositoryNotifier.value.post(data);

  @override
  Future<bool> clean({bool secure = false}) async {
    await repositoryNotifier.value.clean();
    return true;
  }

  @override
  Future<bool> delete(String id, {bool secure = false}) async {
    await repositoryNotifier.value.delete(id);
    return true;
  }

  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) {
    return repositoryNotifier.value.getById(id);
  }

  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data, {bool secure = false}) {
    return repositoryNotifier.value.put(data);
  }

  @override
  Future<bool> deepClean({bool secure = false}) async {
    await repositoryNotifier.value.deepClean();
    return true;
  }
}
