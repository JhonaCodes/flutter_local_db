import 'dart:nativewrappers/_internal/vm/lib/developer.dart';

import 'package:flutter_local_db/src/db/database.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

class LocalDB {
  static final ReactiveNotifier<DataBase> _instance = ReactiveNotifier<DataBase>(() => DataBase());

  static Future<void> init() async {
    await _instance.value.init();
  }

  // ignore: non_constant_identifier_names
  static Future<void> Post(String key, Map<String, dynamic> data) async {
    final currentData = DataModel(key, data.length / 1000, data.hashCode, data);

    await _instance.value.post(currentData);
  }

  // ignore: non_constant_identifier_names
  static Future<List<DataModel>> Get({int limit = 1}) async {
    return await _instance.value.get(limit: limit);
  }

// ignore: non_constant_identifier_names
  static Future<DataModel> GetById(String id) async {
    log(id);
    return await _instance.value.getById(id);
  }

// ignore: non_constant_identifier_names
  static Future<DataModel> Put(String id, Map<dynamic, dynamic> data) async {

    final mapData = DataModel(id, data.length / 1000, data.hashCode, data);

    return await _instance.value.put(mapData);

  }

  // ignore: non_constant_identifier_names
  static Future<bool> Delete(String id) async {
    return await _instance.value.delete(id);
  }

// ignore: non_constant_identifier_names
  static Future<bool> Clean() async {
    return await _instance.value.clean();
  }

  // ignore: non_constant_identifier_names
  static Future<bool> DeepClean() async {
    return await _instance.value.deepClean();
  }
}
