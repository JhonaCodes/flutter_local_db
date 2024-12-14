import 'dart:convert';
import 'dart:developer';

import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';
import 'package:flutter_local_db/src/notifiers/queue_cache.dart';


class LocalDB {

  static Future<void> init() async => await localDatabaseNotifier.value.init();

  // ignore: non_constant_identifier_names
  static Future<void> Post(String key, Map<dynamic, dynamic> data) async {

    if( !_isValidId(key) ){

      throw Exception("The provided key is invalid. Please ensure it contains only letters and numbers, with a minimum length of 9 characters.");
    }

    if( _isValidMap(data) ) {

      final currentData = DataLocalDBModel(
        id: key,
        sizeKb: _mapToKb(data),
        hash: _toHash(data.values),
        data: data,
      );

      await queueCache.value.process(() async => await localDatabaseNotifier.value.post(currentData));

    }

  }

  // ignore: non_constant_identifier_names
  static Future<List<DataLocalDBModel>> Get({int limit = 10}) async {
    return await localDatabaseNotifier.value.get(limit: limit);
  }

// ignore: non_constant_identifier_names
  static Future<DataLocalDBModel> GetById(String id) async {
    return await localDatabaseNotifier.value.getById(id);
  }

// ignore: non_constant_identifier_names
  static Future<DataLocalDBModel> Put(String id, Map<dynamic, dynamic> data) async {
    final mapData = DataLocalDBModel(
      id: id,
      sizeKb: _mapToKb(data),
      hash: data.hashCode,
      data: data,
    );

    return await localDatabaseNotifier.value.put(mapData);
  }

  // ignore: non_constant_identifier_names
  static Future<bool> Delete(String id) async {
    return await localDatabaseNotifier.value.delete(id);
  }

// ignore: non_constant_identifier_names
  static Future<bool> Clean() async {
    return await localDatabaseNotifier.value.clean();
  }

  // ignore: non_constant_identifier_names
  static Future<bool> DeepClean() async {
    return await localDatabaseNotifier.value.deepClean();
  }

  static double _mapToKb(Map map) => double.parse((utf8.encode(jsonEncode(map)).length / 1024).toStringAsFixed(3));
  static int _toHash (Iterable<dynamic> values) => Object.hashAll(values);
  static bool _isValidMap(dynamic map) {
    try{

      String jsonString = jsonEncode(map);

      jsonDecode(jsonString);

      return true;
    }catch(error, stackTrace){
      log(error.toString());
      log(stackTrace.toString());
      return false;
    }
  }
  static bool _isValidId(String text) {
    RegExp regex = RegExp(r'^[a-zA-Z0-9-]{9,}$');
    return regex.hasMatch(text);
  }

}
