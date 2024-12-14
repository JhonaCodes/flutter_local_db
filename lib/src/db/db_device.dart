import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/repository/db_device_repository.dart';

import 'db_interface.dart';

class DataBaseVM implements DataBaseServiceInterface {

  Future<bool> init() async {
    return await RepositoryNotifier.value.init();
  }

  @override
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0}) async {
    return await RepositoryNotifier.value.get(limit: limit, offset: offset);
  }

  @override
  Future<bool> post(DataLocalDBModel data) async {
    await RepositoryNotifier.value.post(data);

    return true;
  }

  @override
  Future<bool> clean() async {
    await RepositoryNotifier.value.clean();
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    await RepositoryNotifier.value.delete(id);
    return true;
  }

  @override
  Future<DataLocalDBModel> getById(String id) {
    return RepositoryNotifier.value.getById(id);
  }

  @override
  Future<DataLocalDBModel> put(DataLocalDBModel data) {
    return RepositoryNotifier.value.put(data);
  }

  @override
  Future<bool> deepClean() async {
    await RepositoryNotifier.value.deepClean();
    return true;
  }
}
