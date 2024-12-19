import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_local_db/src/enum/db_directory.dart';
import 'package:flutter_local_db/src/enum/db_files.dart';
import 'package:flutter_local_db/src/format/manifest_format.dart';
import 'package:flutter_local_db/src/model/main_index_model.dart';
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

  @override
  Future<void> init() async {
    if (data.isEmpty) {
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

  Future<void> createDirectoryIfNotExist(String prefixPath) async {
    final prefixFileDir = Directory(prefixPath);

    if (!prefixFileDir.existsSync()) {
      await prefixFileDir.create(recursive: true);
    }
  }

  /// prefix
  String prefixFromId(String id) => '${id[0]}${id[1]}';

  /// Paths
  String activePrefixPath(String prefix) =>
      '$data/${DBDirectory.active.path}/$prefix';
}

mixin MobileDirectoryService {
  static final ReactiveNotifier<MobileDirectoryManager> instance =
      ReactiveNotifier<MobileDirectoryManager>(MobileDirectoryManager.new);
}
