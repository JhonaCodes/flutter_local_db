import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_local_db/src/enum/db_directory.dart';
import 'package:flutter_local_db/src/enum/db_files.dart';
import 'package:flutter_local_db/src/format/manifest_format.dart';
import 'package:flutter_local_db/src/model/active_index_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/model/main_index_model.dart';
import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';
import 'package:flutter_local_db/src/notifiers/prefix_index_cache.dart';
import 'package:flutter_local_db/src/utils/system_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

class MobileDirectoryManager extends ViewModelStateImpl<String> {
  MobileDirectoryManager() : super('');

  final List<String> suDirectories = [
    DBDirectory.active.path,
    DBDirectory.backup.path,

    /// For next releases in this order.
    //DBDirectory.secure.path,
    //DBDirectory.sync.path,
    //DBDirectory.historical.path,
    //DBDirectory.sealed.path,
  ];

  final List<String> initialFiles = [
    DBFile.manifest.ext,
    DBFile.globalIndex.ext
  ];

  /// prefix
  String prefixFromId(String id) => '${id[0]}${id[1]}';

  /// Paths
  String activePrefixPath(String prefix) => '$data${DBDirectory.active.path}/$prefix';

  @override
  Future<void> init() async {

    if (data.isEmpty && !SystemUtils.isWeb) {
      final appDir = await getApplicationDocumentsDirectory();

      final newDir =
          Directory('${appDir.path}/${DBDirectory.localDatabase.path}');

      try {
        if (!newDir.existsSync()) {
          await newDir.create(recursive: true).then((response) {
            if (response.path.contains(DBDirectory.localDatabase.path)) {
              updateState(response.path);
            }
          });
        } else {
          updateState(newDir.path);
        }
      } catch (e, stack) {
        log(e.toString());
        log(stack.toString());
      }
    }

    await _initialFilesAndDirectories();
  }



  Future<void> _initialFilesAndDirectories() async {
    await _createInitialFiles();
    await _createSubDirectories();
    _readAllDataDirectories();
  }

  Future<void> _createInitialFiles() async {
    try {
      for (String file in initialFiles) {
        final fileComponent = File('$data/$file');

        if (!fileComponent.existsSync()) {
          await fileComponent.create(recursive: true).then((response) {
            if (file.contains(DBFile.manifest.ext)) {
              fileComponent.writeAsStringSync(ManifestFormat.toToml());
            }

            if (file.contains(DBFile.globalIndex.ext)) {
              fileComponent
                  .writeAsStringSync(jsonEncode(MainIndexModel.toInitial()));
            }
          });
        } else {
          log('File already exists: $file');
        }
      }
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
    }
  }

  Future<void> _createSubDirectories() async {

    final String awaitedDirectory = data;

    try {
      for (String dir in suDirectories) {

        final subDirectory = Directory("$awaitedDirectory/$dir");

        if (!subDirectory.existsSync()) {

          await subDirectory.create(recursive: true).then((response) {

            return response.path.contains(dir);

          });

        } else {
          log("Folder already exist: $dir");
        }
      }
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());
    }
  }

  Future<void> createDirectoryIfNotExist(String prefixIndex) async {

    /// Verify on memory if folder exist, if not just create
    if (!containPrefixDir(prefixIndex)) {

      final prefixPatch = activePrefixPath(prefixIndex);

      await Directory(prefixPatch).create(recursive: true).then((response)async{

        /// Create prefix on cache list.
        LocalDataBaseNotifier.currentListPrefix.transformState((list) {
          list.add(prefixIndex);
          //log("Prefix $prefixIndex was added on currentListPrefix cache");
          return list;
        });

        //log("${LocalDataBaseNotifier.currentListPrefix.notifier}");

      });

    }

  }

  Future<ActiveIndexModel> getOrRebuildPrefixIndex({required String prefixPath, required String index, required String subIndex}) async {

    final String indexPath = "$prefixPath/$subIndex";

    //log(indexPath);

    final File indexFile = File(indexPath);

    //log(indexFile.path);

    final bool isIndexFileOnPath = await indexFile.exists();

    String  content  = "";

    try {

      if (isIndexFileOnPath) {
        content = await indexFile.readAsString() ?? '';
        /// Because no need recreate index on each insert on files.
        return ActiveIndexModel.fromJson( content.isNotEmpty ? jsonDecode(content) : ActiveIndexModel.toInitialActiveFolder());

      }else{

        /// Rebuild index if not exist
        final prefix = prefixPath.split('/').last;
        await _rebuildPrefixIndex(prefix, index);


      }

      content = await indexFile.readAsString();

      return ActiveIndexModel.fromJson(jsonDecode(content));

    } catch (error, stackTrace) {

      log(error.toString());
      log(stackTrace.toString());

      /// TODO: verify if this implementation is required
      return ActiveIndexModel.fromJson(ActiveIndexModel.toInitialActiveFolder());

    }

  }


  Future<bool> _rebuildPrefixIndex(String prefix, String index) async {

    try {

      final String activePath = "$data/$index";
      final String prefixPath = "$activePath/$prefix";

      final prefixDir = Directory(prefixPath);

      /// If we have a index file no need rebuild.
      if (!prefixDir.existsSync()) return false;


     // log('Creating prefix index file');

      // Create new prefix for this index
      final ActiveIndexModel newPrefixIndex = ActiveIndexModel.fromJson(ActiveIndexModel.toInitialActiveFolder());

      // Search .dex (data files) on current directory.
      await for (final entity in prefixDir.list()) {

        if (entity is File && entity.path.endsWith('.dex')) {

          final String blockName = entity.path.split('/').last;

          try {

            // Read and process each data file.
            final String content = await entity.readAsString();

            if (content.isNotEmpty) {

              final List<dynamic> records = jsonDecode(content);

              // Rebuild data for index
              int usedLines = records.length;

              newPrefixIndex.blocks[blockName] = BlockData(
                totalLines: LocalDataBaseNotifier.instanceConfig.notifier.maxRecordsPerFile,
                usedLines: usedLines,
                freeSpaces: LocalDataBaseNotifier.instanceConfig.notifier.maxRecordsPerFile - usedLines,
              );

              // Rebuild registers data for index
              for (var record in records) {
                final DataLocalDBModel data = DataLocalDBModel.fromJson(record);
                newPrefixIndex.records[data.id] = RecordLocation(
                  block: blockName,
                  lastUpdate: DateTime.now().toIso8601String(), // Use current data.
                );
              }
            }
          } catch (e, stackTrace) {

            /// todo build a file where return a data with error for download or parse
            log("Error on file $blockName: $e");
            log(stackTrace.toString());
            continue; // Build a next file if we had a error
          }
        }
      }

      // Save new index
      final indexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";
      await File(indexPath).writeAsString(jsonEncode(newPrefixIndex.toJson()));

      // Update cahe data.
      prefixIndexCache.notifier[indexPath] = newPrefixIndex.toJson();

      return true;
    } catch (e, stackTrace) {
      log("Error on prefix $prefix: $e");
      log(stackTrace.toString());
      return false;
    }
  }


  /// Add sub prefix dir on cache.
  void _readAllDataDirectories() {
    final subDirectory = Directory("$data/${DBDirectory.active.path}");

    List<String> dirs = [];

    subDirectory.listSync().forEach((subDir) => dirs.add(subDir.path.split('/').last));


    if(dirs.isNotEmpty) {
      LocalDataBaseNotifier.currentListPrefix.updateState(dirs);
    }

  }

  /// Verify is contain prefix for create or not folder [12,f4,be,...]
  bool containPrefixDir(String prefix) => LocalDataBaseNotifier.currentListPrefix.notifier.contains(prefix);

}

mixin MobileDirectoryService {
  static final ReactiveNotifier<MobileDirectoryManager> instance =
      ReactiveNotifier<MobileDirectoryManager>(MobileDirectoryManager.new);
}
