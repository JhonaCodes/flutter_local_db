import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_local_db/src/db/db_interface.dart';
import 'package:flutter_local_db/src/enum/db_directory.dart';
import 'package:flutter_local_db/src/enum/db_files.dart';
import 'package:flutter_local_db/src/format/manifest_format.dart';
import 'package:flutter_local_db/src/model/active_index_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:flutter_local_db/src/model/main_index_model.dart';

import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';


/// For now just boilerplate code that works.
// ignore: non_constant_identifier_names
final RepositoryNotifier = ReactiveNotifier<DBRepository>(() => DBRepository());

class DBRepository implements DataBaseInterface {

  bool _isOpen = false;

  DBRepository() {
    _isOpen = true;
  }

  final List<String> _suDirectories = [
    DBDirectory.active.path,
    DBDirectory.sealed.path,
    DBDirectory.secure.path,
    DBDirectory.backup.path,
    DBDirectory.historical.path,
    DBDirectory.sync.path,
  ];

  static final List<String> _initialFiles = [
    DBFile.manifest.ext,
    DBFile.globalIndex.ext,
  ];

  get mainDir async => await directory();

  Future<String> directory() async {
    final appDir = await getApplicationDocumentsDirectory();

    final newDir = Directory('${appDir.path}/${DBDirectory.localDatabase.path}');

    try {
      if (!newDir.existsSync()) {
        await newDir.create(recursive: true).then((response) {
          if (response.path.contains(DBDirectory.localDatabase.path)) {
            return response.path;
          }
        });
      }
    } catch (e, stack) {
      print(e.toString());
      print(stack.toString());
    }


    return newDir.path;
  }

  /// Function for creating subdirectories
  Future<bool> _createSubDirectory(String directoryName) async {
    final String awaitedDirectory = await mainDir;

    final subDirectory = Directory("$awaitedDirectory/$directoryName");

    if (!subDirectory.existsSync()) {
      await subDirectory.create(recursive: true).then((response) {
        return response.path.contains(directoryName);
      });
    } else {
      log("Folder already exist: $directoryName");
    }

    return true;
  }

  /// Initialization
  Future<bool> init() async {
    try {

      /// Creating sub-directories
      for (String dir in _suDirectories) {
        await _createSubDirectory(dir);
      }

      /// Creating files
      for (String file in _initialFiles) {
        final fileComponent = File('${await mainDir}/$file');

        if (!fileComponent.existsSync()) {
          await fileComponent.create(recursive: true).then((response) {
            if (file.contains(DBFile.manifest.ext)) {
              fileComponent.writeAsStringSync(ManifestFormat.toToml());
            }

            if (file.contains(DBFile.globalIndex.ext)) {
              fileComponent.writeAsStringSync(jsonEncode(MainIndexModel.toInitial()));
            }
          });
        } else {
          log('File already exists: $file');
        }
      }

      return true;
    } catch (error, stackTrace) {
      log(error.toString());
      log(stackTrace.toString());

      return false;
    }
  }


  /// Crear elementos [Post]
  @override
  Future<bool> clean() async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      // Limpiar caché
      _prefixIndexCache.clear();
      _blockCache.clear();

      // Obtener directorio activo
      final String activePath = "${await mainDir}/${DBDirectory.active.path}";
      final activeDir = Directory(activePath);

      if (!activeDir.existsSync()) {
        return true; // Si no existe, consideramos que ya está limpio
      }

      // Eliminar todo el contenido del directorio active
      await for (final entity in activeDir.list()) {
        await entity.delete(recursive: true);
      }

      // Resetear el índice principal pero mantener la estructura
      final mainFile = await mainIndexFile;
      if (mainFile != null && mainFile.existsSync()) {
        await mainFile.writeAsString(jsonEncode(MainIndexModel.toInitial()));
      }

      return true;
    } catch (e, stack) {
      log("Error in clean operation", error: e, stackTrace: stack);
      return false;
    }
  }

  @override
  Future<bool> deepClean() async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      // Limpiar caché
      _prefixIndexCache.clear();
      _blockCache.clear();

      // Obtener el directorio principal
      final baseDir = await mainDir;

      // Lista de todos los subdirectorios a limpiar
      final directories = _suDirectories;

      // Eliminar contenido de cada subdirectorio
      for (String dir in directories) {
        final dirPath = "$baseDir/$dir";
        final directory = Directory(dirPath);

        if (directory.existsSync()) {
          await for (final entity in directory.list()) {
            await entity.delete(recursive: true);
          }
        }
      }

      // Resetear el índice principal a un objeto vacío
      final mainFile = await mainIndexFile;
      if (mainFile != null && mainFile.existsSync()) {
        await mainFile.writeAsString('{}');
      }

      // Mantener el archivo manifest (.toml) sin cambios
      final manifestPath = "$baseDir/${DBFile.manifest.ext}";
      final manifestFile = File(manifestPath);
      if (!manifestFile.existsSync()) {
        // Si no existe el manifest, lo creamos con la configuración inicial
        await manifestFile.writeAsString(ManifestFormat.toToml());
      }

      // Recrear la estructura de directorios base
      for (String dir in directories) {
        final dirPath = "$baseDir/$dir";
        final directory = Directory(dirPath);

        if (!directory.existsSync()) {
          await directory.create(recursive: true);
        }
      }

      return true;
    } catch (e, stack) {
      log("Error in deepClean operation", error: e, stackTrace: stack);
      return false;
    }
  }


  @override
  Future<bool> delete(String id) async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      // Extract prefix from ID (first 2 characters)
      final idPrefix = "${id[0]}${id[1]}";

      // Get paths
      final activePath = "${await mainDir}/${DBDirectory.active.path}";
      final prefixPath = "$activePath/$idPrefix";
      final prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";

      // Check if prefix index exists
      final prefixIndexFile = File(prefixIndexPath);
      if (!prefixIndexFile.existsSync()) {
        throw Exception('Record not found: index does not exist');
      }

      // Read and decode prefix index
      final indexContent = await prefixIndexFile.readAsString();
      if (indexContent.isEmpty) {
        throw Exception('Empty index file');
      }

      final ActiveIndexModel prefixIndex = ActiveIndexModel.fromJson(
          jsonDecode(indexContent)
      );

      // Check if record exists in index
      if (!prefixIndex.records.containsKey(id)) {
        throw Exception('Record not found in index');
      }

      // Get block information
      final recordLocation = prefixIndex.records[id]!;
      final blockPath = "$prefixPath/${recordLocation.block}";
      final blockFile = File(blockPath);

      if (!blockFile.existsSync()) {
        throw Exception('Block file not found');
      }

      // Create temporary backup before deletion
      final tempPath = "$prefixPath/delete_temp_${DateTime.now().millisecondsSinceEpoch}.bak";
      final tempFile = File(tempPath);

      List<DataModel> records;

      // Read current block content
      if (_blockCache.containsKey(blockPath)) {
        records = List.from(_blockCache[blockPath]!);
      } else {
        final blockContent = await blockFile.readAsString();
        final List<dynamic> blockRecords = jsonDecode(blockContent);
        records = blockRecords.map((r) => DataModel.fromJson(r)).toList();
        _blockCache[blockPath] = records;
      }

      // Find record index
      final recordIndex = records.indexWhere((r) => r.id == id);
      if (recordIndex == -1) {
        throw Exception('Record not found in block');
      }

      // Create backup of current state
      await tempFile.writeAsString(jsonEncode(records[recordIndex].toJson()));

      try {
        // Remove record from list
        records.removeAt(recordIndex);

        // Update block file
        await blockFile.writeAsString(
            jsonEncode(records.map((r) => r.toJson()).toList()),
            flush: true
        );

        // Update cache
        _blockCache[blockPath] = records;

        // Remove from index
        prefixIndex.records.remove(id);

        // Update block data in index
        if (records.isEmpty) {
          // If block is empty, remove it from index
          prefixIndex.blocks.remove(recordLocation.block);
          // Optionally delete empty block file
          await blockFile.delete();
        } else {
          // Update block statistics
          prefixIndex.blocks[recordLocation.block] = BlockData(
            totalLines: 20000,
            usedLines: records.length,
            freeSpaces: [],
            fragmentation: 0.0,
          );
        }

        // Write updated index
        await prefixIndexFile.writeAsString(
            jsonEncode(prefixIndex.toJson()),
            flush: true
        );

        // If everything is OK, delete temp file
        await tempFile.delete();

        return true;

      } catch (e) {
        // If anything fails, keep temp file for recovery
        log("Delete failed. Backup available at: $tempPath");
        rethrow;
      }

    } catch (e, stack) {
      log("Error in delete operation", error: e, stackTrace: stack);
      return false;
    }
  }


  @override
  Future<bool> post(DataModel model) async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      final idPrefix = "${model.id[0]}${model.id[1]}";
      final String activePath = "${await mainDir}/${DBDirectory.active.path}";
      final String prefixPath = "$activePath/$idPrefix";

      // Creamos el directorio si no existe
      final prefixDir = Directory(prefixPath);
      if (!prefixDir.existsSync()) {
        await prefixDir.create(recursive: true);
      }

      // Manejo optimizado del índice de prefijo
      final String prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";
      ActiveIndexModel prefixIndex;

      // Usar caché si está disponible
      if (_prefixIndexCache.containsKey(prefixIndexPath)) {
        prefixIndex = ActiveIndexModel.fromJson(
            jsonDecode(_prefixIndexCache[prefixIndexPath]!)
        );
      } else {
        final prefixIndexFile = File(prefixIndexPath);
        if (!prefixIndexFile.existsSync()) {
          prefixIndex = ActiveIndexModel.fromJson(ActiveIndexModel.toInitial());
        } else {
          final content = await prefixIndexFile.readAsString();
          prefixIndex = ActiveIndexModel.fromJson(
              content.isEmpty ? ActiveIndexModel.toInitial() : jsonDecode(content)
          );
        }
        // Guardar en caché
        _prefixIndexCache[prefixIndexPath] = jsonEncode(prefixIndex.toJson());
      }

      if (prefixIndex.records.containsKey(model.id)) {
        log("Record ID already exists: ${model.id}");
        return false;
      }

      // Selección y manejo optimizado de bloques
      final String currentBlock = _selectActiveBlock(prefixIndex);
      final String blockPath = "$prefixPath/$currentBlock";

      // Usar caché de bloques
      List<DataModel> records;
      if (_blockCache.containsKey(blockPath)) {
        records = List.from(_blockCache[blockPath]!);
      } else {
        final blockFile = File(blockPath);
        if (blockFile.existsSync()) {
          final content = await blockFile.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> decodedRecords = jsonDecode(content);
            records = decodedRecords
                .map((record) => DataModel.fromJson(record))
                .toList();
          } else {
            records = [];
          }
        } else {
          records = [];
        }
        _blockCache[blockPath] = records;
      }

      // Añadir nuevo registro
      records.add(model);
      _blockCache[blockPath] = records;

      // Escribir a disco de manera eficiente
      await File(blockPath).writeAsString(
          jsonEncode(records.map((r) => r.toJson()).toList()),
          flush: true // Asegura escritura inmediata
      );

      // Actualizar índice
      prefixIndex.blocks[currentBlock] = BlockData(
        totalLines: 20000,
        usedLines: records.length,
        freeSpaces: [],
        fragmentation: 0.0,
      );

      prefixIndex.records[model.id] = RecordLocation(
        block: currentBlock,
        lastUpdate: DateTime.now().toIso8601String(),
      );

      // Actualizar caché y escribir índice
      _prefixIndexCache[prefixIndexPath] = jsonEncode(prefixIndex.toJson());
      await File(prefixIndexPath).writeAsString(
          _prefixIndexCache[prefixIndexPath]!,
          flush: true
      );

      // Actualizar índice principal
      await _updateMainIndex(idPrefix, prefixPath);

      return true;
    } catch (e, stack) {
      log("Error in post operation", error: e, stackTrace: stack);
      return false;
    }
  }

// Helper method for block selection
  String _selectActiveBlock(ActiveIndexModel prefixIndex) {
    // If no blocks exist, create first one
    if (prefixIndex.blocks.isEmpty) {
      return 'act_001.dex';
    }

    // Find a block with available space
    for (var entry in prefixIndex.blocks.entries) {
      if (entry.value.usedLines < entry.value.totalLines) {
        return entry.key;
      }
    }

    // All blocks full, create new one
    final lastBlock = prefixIndex.blocks.keys.toList()
      ..sort();
    final lastNum = int.parse(lastBlock.last.split('_')[1].split('.')[0]);
    return 'act_${(lastNum + 1).toString().padLeft(3, '0')}.dex';
  }


  Future<File>? get mainIndexFile async => File("${await mainDir}/${DBFile.globalIndex.ext}");

  Future<String>? get mainIndexData async {
    final File? data = await mainIndexFile;
    return utf8.decode(data?.readAsBytesSync() ?? []);
  }

  Future<bool> _isCodeOnMainIndex(String idIndex) async {
    final fileMap = await _decodeMainIndex;
    return fileMap.containsKey(idIndex);
  }

  Future<Map<String, dynamic>> get _decodeMainIndex async =>
      mainIndexFile != null
          ? Map<String, dynamic>.from(await jsonDecode(await mainIndexData ?? "{}"))
          : {};


  Future<void> clearCache() async {
    _prefixIndexCache.clear();
    _blockCache.clear();
  }


  // Añadimos cache para optimizar
  final Map<String, String> _prefixIndexCache = {};
  final Map<String, List<DataModel>> _blockCache = {};


  Future<void> _updateMainIndex(String idPrefix, String prefixPath) async {
    final mainFile = await mainIndexFile;
    if (mainFile != null) {
      MainIndexModel mainIndex = MainIndexModel.fromJson(await _decodeMainIndex);

      mainIndex.containers[idPrefix] = ContainerPaths(
        active: "${DBDirectory.active.path}/$idPrefix/${DBFile.activeSubIndex.ext}",
        deleted: null,
        sealed: null,
        backup: null,
        historical: null,
        sync: null,
      );

      await mainFile.writeAsString(jsonEncode(mainIndex.toJson()));
    }
  }



  /// Obtiene una lista paginada de registros ordenados por fecha (más reciente a más antiguo)
  ///
  /// Parámetros:
  /// - [limit] : Número máximo de registros a retornar (por defecto 20)
  /// - [offset] : Número de registros a saltar (por defecto 0)
  ///
  /// Retorna:
  /// - Future<List<DataModel>> : Lista de registros paginada
  ///
  /// Ejemplo de uso:
  /// ```dart
  /// // Obtener primeros 20 registros
  /// final page1 = await repository.get(limit: 20, offset: 0);
  ///
  /// // Obtener siguientes 20 registros
  /// final page2 = await repository.get(limit: 20, offset: 20);
  /// ```
  ///
  /// Funcionamiento:
  /// 1. Lee el índice principal para obtener todos los prefijos
  /// 2. Para cada prefijo:
  ///   - Lee su índice específico
  ///   - Agrupa los registros por bloques
  ///   - Lee y procesa cada bloque
  /// 3. Ordena todos los registros por fecha
  /// 4. Aplica la paginación (limit y offset)
  ///
  /// Lanza:
  /// - Exception si el repositorio no está abierto
  /// - Errores de lectura/escritura de archivos
  ///
  /// Notas:
  /// - Los registros se ordenan del más reciente al más antiguo
  /// - Si no hay registros, retorna una lista vacía
  /// - Utiliza el lastUpdate del índice para el ordenamiento
  @override
  Future<List<DataModel>> get({int limit = 20, int offset = 0}) async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      // Lista para almacenar los resultados
      final records = <MapEntry<DateTime, DataModel>>[];

      // Obtener directorio activo
      final String activePath = "${await mainDir}/${DBDirectory.active.path}";

      // Obtener índice principal
      final mainFile = await mainIndexFile;
      if (mainFile == null) {
        return [];
      }

      // Decodificar índice principal
      final mainIndex = MainIndexModel.fromJson(await _decodeMainIndex);

      // Recorrer cada prefijo en el índice principal
      for (final prefix in mainIndex.containers.keys) {
        final String prefixPath = "$activePath/$prefix";
        final String prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";

        // Verificar y leer índice del prefijo
        final prefixIndexFile = File(prefixIndexPath);
        if (!prefixIndexFile.existsSync()) {
          continue;
        }

        // Leer y decodificar índice del prefijo
        final String indexContent = await prefixIndexFile.readAsString();
        if (indexContent.isEmpty) {
          continue;
        }

        final ActiveIndexModel prefixIndex = ActiveIndexModel.fromJson(
            jsonDecode(indexContent)
        );

        // Agrupar registros por bloque para optimizar lecturas
        final Map<String, List<String>> blockToIds = {};
        for (final recordEntry in prefixIndex.records.entries) {
          final blockName = recordEntry.value.block;
          blockToIds.putIfAbsent(blockName, () => []).add(recordEntry.key);
        }

        // Procesar cada bloque
        for (final blockEntry in blockToIds.entries) {
          final blockPath = "$prefixPath/${blockEntry.key}";
          final blockFile = File(blockPath);

          if (!blockFile.existsSync()) {
            continue;
          }

          final String blockContent = await blockFile.readAsString();
          if (blockContent.isEmpty) {
            continue;
          }

          // Decodificar registros del bloque
          final List<dynamic> blockRecords = jsonDecode(blockContent);

          // Procesar cada registro en el bloque
          for (final record in blockRecords) {
            final DataModel recordModel = DataModel.fromJson(record);

            // Verificar si el ID está en la lista de IDs del bloque
            if (blockToIds[blockEntry.key]!.contains(recordModel.id)) {
              final DateTime recordDate = DateTime.parse(
                  prefixIndex.records[recordModel.id]!.lastUpdate
              );
              records.add(MapEntry(recordDate, recordModel));
            }
          }
        }
      }

      // Ordenar registros por fecha (más reciente primero)
      records.sort((a, b) => b.key.compareTo(a.key));

      // Aplicar paginación y retornar
      return records
          .skip(offset)
          .take(limit)
          .map((e) => e.value)
          .toList();

    } catch (e, stack) {
      log("Error in get operation", error: e, stackTrace: stack);
      rethrow;
    }
  }


  // Método auxiliar para obtener el total de registros (útil para paginación)
  Future<int> getTotalRecords() async {
    try {
      final mainFile = await mainIndexFile;
      if (mainFile == null) return 0;

      final mainIndex = MainIndexModel.fromJson(await _decodeMainIndex);
      int total = 0;

      for (var prefix in mainIndex.containers.keys) {
        final prefixIndexPath = "${await mainDir}/${DBDirectory.active.path}/$prefix/${DBFile.activeSubIndex.ext}";
        final prefixIndexFile = File(prefixIndexPath);
        if (!prefixIndexFile.existsSync()) continue;

        final prefixIndex = ActiveIndexModel.fromJson(
            jsonDecode(await prefixIndexFile.readAsString())
        );

        total += prefixIndex.records.length;
      }

      return total;
    } catch (e) {
      log("Error getting total records", error: e);
      return 0;
    }
  }


  @override
  Future<DataModel> getById(String id) async {
    print(id);

    if (!_isOpen) throw Exception('Repository must be open');

    try {
      // Extract prefix from ID (first 2 characters)
      final idPrefix = "${id.toString()[0]}${id.toString()[1]}";

      // Get active directory path
      final activePath = "${await mainDir}/${DBDirectory.active.path}";
      final prefixPath = "$activePath/$idPrefix";
      final prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";

      // Check if prefix index exists
      final prefixIndexFile = File(prefixIndexPath);
      if (!prefixIndexFile.existsSync()) {
        throw Exception('Record not found: index does not exist');
      }

      // Read and decode prefix index
      final indexContent = await prefixIndexFile.readAsString();
      if (indexContent.isEmpty) {
        throw Exception('Empty index file');
      }

      final ActiveIndexModel prefixIndex = ActiveIndexModel.fromJson(
          jsonDecode(indexContent)
      );

      // Check if record exists in index
      if (!prefixIndex.records.containsKey(id.toString())) {
        throw Exception('Record not found in index');
      }

      // Get block information
      final recordLocation = prefixIndex.records[id.toString()]!;
      final blockPath = "$prefixPath/${recordLocation.block}";
      final blockFile = File(blockPath);

      if (!blockFile.existsSync()) {
        throw Exception('Block file not found');
      }

      // Check block cache first
      if (_blockCache.containsKey(blockPath)) {
        final cachedRecords = _blockCache[blockPath]!;
        return cachedRecords.firstWhere(
              (r) => r.id == id.toString(),
          orElse: () => throw Exception('Record not found in cached block'),
        );
      }

      // If not in cache, read from file
      final blockContent = await blockFile.readAsString();
      if (blockContent.isEmpty) {
        throw Exception('Empty block file');
      }

      // Decode block content and cache it
      final List<dynamic> blockRecords = jsonDecode(blockContent);
      final records = blockRecords
          .map((record) => DataModel.fromJson(record))
          .toList();
      _blockCache[blockPath] = records;

      // Find and return the specific record
      return records.firstWhere(
            (r) => r.id == id.toString(),
        orElse: () => throw Exception('Record not found in block'),
      );

    } catch (e, stack) {
      log("Error in getById operation", error: e, stackTrace: stack);
      throw Exception('Failed to get record: ${e.toString()}');
    }
  }


  @override
  Future<DataModel> put(DataModel updatedData) async {
    if (!_isOpen) throw Exception('Repository must be open');

    try {
      final id = updatedData.id;
      final idPrefix = "${id[0]}${id[1]}";

      // Get paths
      final activePath = "${await mainDir}/${DBDirectory.active.path}";
      final prefixPath = "$activePath/$idPrefix";
      final prefixIndexPath = "$prefixPath/${DBFile.activeSubIndex.ext}";

      // Verify index exists
      final prefixIndexFile = File(prefixIndexPath);
      if (!prefixIndexFile.existsSync()) {
        throw Exception("Record not found: index does not exist. Use post() to create new records.");
      }

      // Read and decode prefix index
      final indexContent = await prefixIndexFile.readAsString();
      if (indexContent.isEmpty) {
        throw Exception("Empty index file. Use post() to create new records.");
      }

      final ActiveIndexModel prefixIndex = ActiveIndexModel.fromJson(
          jsonDecode(indexContent)
      );

      // Check if record exists
      if (!prefixIndex.records.containsKey(id)) {
        throw Exception("Record not found. Use post() to create new records.");
      }

      // Get block information
      final recordLocation = prefixIndex.records[id]!;
      final blockPath = "$prefixPath/${recordLocation.block}";
      final blockFile = File(blockPath);

      if (!blockFile.existsSync()) {
        throw Exception('Block file not found');
      }

      // Create temporary backup
      final tempPath = "$prefixPath/temp_${DateTime.now().millisecondsSinceEpoch}.bak";
      final tempFile = File(tempPath);

      List<DataModel> records;

      // Read current block content
      if (_blockCache.containsKey(blockPath)) {
        records = List.from(_blockCache[blockPath]!);
      } else {
        final blockContent = await blockFile.readAsString();
        final List<dynamic> blockRecords = jsonDecode(blockContent);
        records = blockRecords.map((r) => DataModel.fromJson(r)).toList();
        _blockCache[blockPath] = records;
      }

      // Find record index
      final recordIndex = records.indexWhere((r) => r.id == id);
      if (recordIndex == -1) {
        throw Exception('Record not found in block');
      }

      // Create backup of current state
      await tempFile.writeAsString(jsonEncode(records[recordIndex].toJson()));

      try {
        // Update record
        records[recordIndex] = updatedData;

        // Write updated block
        await blockFile.writeAsString(
            jsonEncode(records.map((r) => r.toJson()).toList()),
            flush: true
        );

        // Update cache
        _blockCache[blockPath] = records;

        // Update index with new timestamp
        prefixIndex.records[id] = RecordLocation(
          block: recordLocation.block,
          lastUpdate: DateTime.now().toIso8601String(),
        );

        // Write updated index
        await prefixIndexFile.writeAsString(
            jsonEncode(prefixIndex.toJson()),
            flush: true
        );

        // Verify integrity
        final verificationContent = await blockFile.readAsString();
        final verificationRecords = List<DataModel>.from(
            jsonDecode(verificationContent).map((r) => DataModel.fromJson(r))
        );

        final verifiedRecord = verificationRecords.firstWhere((r) => r.id == id);
        if (verifiedRecord.hash != updatedData.hash) {
          throw Exception('Data integrity check failed');
        }

        // If everything is OK, delete temp file
        await tempFile.delete();

        // Return the updated record
        return verifiedRecord;

      } catch (e) {
        // If anything fails, keep temp file for recovery
        log("Update failed. Backup available at: $tempPath");
        rethrow;
      }

    } catch (e, stack) {
      log("Error in put operation", error: e, stackTrace: stack);
      rethrow;
    }
  }

}