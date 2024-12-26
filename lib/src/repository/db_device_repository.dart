import 'dart:developer';

import 'package:flutter_local_db/src/db/db_interface.dart';

import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';


import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';

import 'package:reactive_notifier/reactive_notifier.dart';

final repositoryNotifier = ReactiveNotifier<DBRepository>(DBRepository.new);

/// This class needs cleaning, logic improvements, etc.
/// For now this is an MVP of the general concept of what we want to do.
/// Use this library with caution, as it may have drastic changes in the future.
class DBRepository implements DataBaseServiceInterface {

  String get _mainDir => LocalDBNotifier.directoryManager.notifier.data;

  @override
  Future<bool> init(ConfigDBModel config) async {
    try {
      /// Init Route data for current device route path
      await LocalDBNotifier.directoryManager.notifier.init();

      /// Configure database instance
      LocalDBNotifier.instanceConfigDB.updateState(config);

      return true;
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());

      return false;
    }
  }

  @override
  Future<DataLocalDBModel> post(DataLocalDBModel model, {bool secure = false}) async {

    if (!_isOpen) throw Exception('Repository must be open');

    try {

      final String idPrefix   = '${model.id[0]}${model.id[1]}';

      final String prefixPath = MobileDirectoryService.instance.notifier.activePrefixPath(idPrefix);

      /// Create dir if not exist.
      await MobileDirectoryService.instance.notifier.createDirectoryIfNotExist(idPrefix);

      // Manejo optimizado del índice de prefijo
      final String prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";
      ActiveIndexModel prefixIndex;


      // Use cache if is available
      if (prefixIndexCache.notifier.containsKey(prefixIndexPath)) {

        prefixIndex = ActiveIndexModel.fromJson(prefixIndexCache.notifier[prefixIndexPath]!);

      } else {

        /// Create file or and save initial data on file.
        prefixIndex = await MobileDirectoryService.instance.notifier.getOrRebuildPrefixIndex(
          prefixPath: prefixPath,
          index: DBDirectory.active.path,
          subIndex: DBFile.activeSubIndex.ext,
        );

        // Guardar en caché
        prefixIndexCache.notifier[prefixIndexPath] = prefixIndex.toJson();
      }


      if (prefixIndex.records.containsKey(model.id)) {
        log("Duplicate Record ID: ${model.id} - Use PUT for updates. POST is reserved for creating new records.");

        throw Exception("Duplicate Record ID: ${model.id} - Use PUT for updates. POST is reserved for creating new records.");
      }


      // Selección y manejo optimizado de bloques
      final String currentBlock = _selectActiveBlock(prefixIndex);
      final String blockPath = "$prefixPath/$currentBlock";

      // Usar caché de bloques
      List<DataLocalDBModel> records;

      if (LocalDataBaseNotifier.dataIndexCache.notifier.containsKey(blockPath)) {

        records = List.from(LocalDataBaseNotifier.dataIndexCache.notifier[blockPath]!);

      } else {

        final blockFile = File(blockPath);

        if (blockFile.existsSync()) {
          final content = await blockFile.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> decodedRecords = jsonDecode(content);
            records = decodedRecords
                .map((record) => DataLocalDBModel.fromJson(record))
                .toList();
          } else {
            records = [];
          }
        } else {
          records = [];
        }


    }catch(error, stackTrace){
      
      log(error.toString());
      log(stackTrace.toString());
      
    }
    
    
    
    return model;
  }

  @override
  Future<bool> deepClean({bool secure = false}) async {

    try {

    } catch (e, stack) {

      return false;
    }

    return true;
  }

  @override
  Future<bool> delete(String id, {bool secure = false}) async {

    try {


    } catch (e, stack) {
      log("Error in delete operation", error: e, stackTrace: stack);
      return false;
    }

    return true;
  }



  @override
  Future<List<DataLocalDBModel>> get({int limit = 20, int offset = 0, bool secure = false}) async {


    try {

    } catch (e, stack) {
      log("Error in get operation", error: e, stackTrace: stack);
      rethrow;
    }

    return [];
  }


  @override
  Future<DataLocalDBModel> getById(String id, {bool secure = false}) async {


    try {

    } catch (e, stack) {
      log("Error in getById operation", error: e, stackTrace: stack);
      throw Exception('Failed to get record: ${e.toString()}');
    }

    return DataLocalDBModel.fromJson({});
  }

  @override
  Future<DataLocalDBModel> put(DataLocalDBModel updatedData, {bool secure = false}) async {


    try {

    } catch (e, stack) {
      log("Error in put operation", error: e, stackTrace: stack);
      rethrow;
    }


    return DataLocalDBModel.fromJson({});
  }

  @override
  Future<bool> clean({bool secure = false}) async {

    try {

      return true;
    } catch (e, stack) {
      log("Error in clean operation", error: e, stackTrace: stack);
      return false;
    }
  }


}
