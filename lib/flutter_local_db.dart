// lib/flutter_local_db.dart

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Definir las firmas de las funciones FFI basadas en el código Rust real
typedef CreateDbNative = Pointer<Void> Function(Pointer<Utf8> name);
typedef CreateDb = Pointer<Void> Function(Pointer<Utf8> name);

typedef PushDataNative = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> json);
typedef PushData = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> json);

typedef GetByIdNative = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> id);
typedef GetByIdFunc = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> id);

typedef GetAllNative = Pointer<Utf8> Function(Pointer<Void> state);
typedef GetAllFunc = Pointer<Utf8> Function(Pointer<Void> state);

typedef UpdateDataNative = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> json);
typedef UpdateData = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> json);

typedef DeleteByIdNative = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> id);
typedef DeleteByIdFunc = Pointer<Utf8> Function(Pointer<Void> state, Pointer<Utf8> id);

typedef ClearAllRecordsNative = Pointer<Utf8> Function(Pointer<Void> state);
typedef ClearAllRecords = Pointer<Utf8> Function(Pointer<Void> state);

typedef CloseDbNative = Pointer<Utf8> Function(Pointer<Void> state);
typedef CloseDb = Pointer<Utf8> Function(Pointer<Void> state);

/// Result type para manejo de errores
sealed class LocalDbResult<T, E> {
  const LocalDbResult();
  
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  });
}

class Ok<T, E> extends LocalDbResult<T, E> {
  final T value;
  const Ok(this.value);
  
  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => ok(value);
}

class Err<T, E> extends LocalDbResult<T, E> {
  final E error;
  const Err(this.error);
  
  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => err(error);
}

/// Modelo de datos compatible con el API anterior
class LocalDbModel {
  final String id;
  final Map<String, dynamic> data;
  final String? hash;
  
  const LocalDbModel({
    required this.id, 
    required this.data, 
    this.hash
  });
  
  @override
  String toString() => 'LocalDbModel(id: $id, data: $data)';
}

/// Tipos de errores
enum LocalDbErrorType {
  notFound,
  alreadyExists,
  validation,
  serialization,
  database,
  connection,
  unknown
}

/// Error de base de datos compatible con API anterior
class ErrorLocalDb {
  final LocalDbErrorType type;
  final String message;
  
  const ErrorLocalDb({required this.type, required this.message});
  
  factory ErrorLocalDb.notFound(String message) => 
    ErrorLocalDb(type: LocalDbErrorType.notFound, message: message);
    
  factory ErrorLocalDb.validationError(String message) => 
    ErrorLocalDb(type: LocalDbErrorType.validation, message: message);
    
  factory ErrorLocalDb.serializationError(String message) => 
    ErrorLocalDb(type: LocalDbErrorType.serialization, message: message);
    
  factory ErrorLocalDb.databaseError(String message) => 
    ErrorLocalDb(type: LocalDbErrorType.database, message: message);
    
  @override
  String toString() => 'ErrorLocalDb($type: $message)';
}

/// Base de datos local con API compatible siguiendo el patrón de offline_first_core
class LocalDB {
  static LocalDB? _instance;
  static DynamicLibrary? _lib;
  static Pointer<Void>? _dbState; // Puntero al estado de la base de datos de Rust
  
  late final CreateDb _createDb;
  late final PushData _pushData;
  late final GetByIdFunc _getById;
  late final GetAllFunc _getAll;
  late final UpdateData _updateData;
  late final DeleteByIdFunc _deleteById;
  late final ClearAllRecords _clearAllRecords;
  late final CloseDb _closeDb;
  
  bool _isInitialized = false;
  
  LocalDB._();
  
  /// Obtener instancia singleton
  static LocalDB get instance {
    return _instance ??= LocalDB._();
  }
  
  /// Inicializar base de datos
  static Future<void> init([String? dbName]) async {
    try {
      final db = instance;
      if (db._isInitialized) {
        return;
      }
      
      // Cargar librería nativa
      final libResult = _loadLibrary();
      if (libResult is Err) {
        throw Exception((libResult as Err<DynamicLibrary, ErrorLocalDb>).error.message);
      }
      
      _lib = (libResult as Ok<DynamicLibrary, ErrorLocalDb>).value;
      
      // Obtener funciones FFI
      try {
        db._loadFunctions(_lib!);
        Log.i('✅ FFI functions loaded successfully');
      } catch (e) {
        throw Exception('Failed to load FFI functions: $e');
      }
      
      // Crear base de datos en Rust con ruta apropiada para la plataforma
      final dbNameToUse = dbName ?? 'flutter_local_db';
      
      // Obtener directorio apropiado según la plataforma
      String dbPath;
      if (Platform.isAndroid || Platform.isIOS) {
        // En móviles, usar directorio de documentos de la aplicación
        final appDocDir = await getApplicationDocumentsDirectory();
        dbPath = path.join(appDocDir.path, dbNameToUse);
      } else {
        // En desktop, usar directorio actual o específico
        dbPath = dbNameToUse;
      }
      
      Log.i('Creating database with path: $dbPath');
      
      final dbPathPtr = dbPath.toNativeUtf8();
      try {
        _dbState = db._createDb(dbPathPtr);
        Log.i('create_db called, returned: ${_dbState?.address ?? 'nullptr'}');
        
        // Si es null, intentar obtener más información del estado actual
        if (_dbState == nullptr) {
          Log.e('create_db returned null pointer immediately');
          Log.w('Database path might not be writable or accessible');
          Log.i('Platform: ${Platform.operatingSystem}');
          Log.i('Database path attempted: $dbPath');
        }
      } catch (e) {
        malloc.free(dbPathPtr);
        throw Exception('Failed to call create_db: $e');
      }
      malloc.free(dbPathPtr);
      
      if (_dbState == nullptr) {
        final errorMsg = '''
Failed to initialize database - create_db returned null pointer.

Possible causes:
1. LMDB initialization failed in Rust
2. Database file permissions issue
3. Invalid database path: $dbPath
4. FFI function mismatch

Platform: ${Platform.operatingSystem}

Check Rust logs for more details.
        ''';
        throw Exception(errorMsg.trim());
      }
      
      db._isInitialized = true;
      Log.i('LocalDB initialized successfully');
      
    } catch (e, stackTrace) {
      Log.e('LocalDB initialization failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Crear nuevo registro (API compatible con Post original)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> Post(
    String key, 
    Map<String, dynamic> data, {
    String? lastUpdate
  }) async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    // Validar key
    final keyValidation = _validateKey(key);
    if (keyValidation is Err) {
      return Err((keyValidation as Err).error);
    }
    
    try {
      // Crear JSON en el formato que espera Rust: {"id": "key", "hash": "...", "data": {...}}
      final jsonData = {
        'id': key,
        'hash': lastUpdate ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'data': data
      };
      
      final jsonStr = _serializeJson(jsonData);
      final jsonPtr = jsonStr.toNativeUtf8();
      
      final resultPtr = db._pushData(_dbState!, jsonPtr);
      final resultStr = resultPtr.toDartString();
      
      // Liberar memoria
      malloc.free(jsonPtr);
      // Note: resultPtr es manejado por Rust, no lo liberamos aquí
      
      // Parsear respuesta de Rust
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) {
          try {
            final model = _parseLocalDbModel(jsonResponse);
            return Ok(model);
          } catch (e) {
            return Err(ErrorLocalDb.serializationError('Failed to parse response: $e'));
          }
        },
        err: (error) => Err(error)
      );
      
    } catch (e) {
      Log.w('Insert failed for key: $key - $e');
      return Err(ErrorLocalDb.databaseError('Insert failed: $e'));
    }
  }
  
  /// Obtener registro por ID (API compatible)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel?, ErrorLocalDb>> GetById(String key) async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    // Validar key
    final keyValidation = _validateKey(key);
    if (keyValidation is Err) {
      return Err((keyValidation as Err).error);
    }
    
    try {
      final keyPtr = key.toNativeUtf8();
      final resultPtr = db._getById(_dbState!, keyPtr);
      final resultStr = resultPtr.toDartString();
      
      malloc.free(keyPtr);
      
      // Parsear respuesta de Rust
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) {
          try {
            final model = _parseLocalDbModel(jsonResponse);
            return Ok(model);
          } catch (e) {
            return Err(ErrorLocalDb.serializationError('Failed to parse response: $e'));
          }
        },
        err: (error) {
          // Si es NotFound, retornar null
          if (error.type == LocalDbErrorType.notFound) {
            return const Ok(null);
          }
          return Err(error);
        }
      );
      
    } catch (e) {
      Log.w('Get failed for key: $key - $e');
      return Err(ErrorLocalDb.databaseError('Get failed: $e'));
    }
  }
  
  /// Actualizar registro existente (API compatible)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<LocalDbModel, ErrorLocalDb>> Put(
    String key, 
    Map<String, dynamic> data
  ) async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    try {
      // Crear JSON para update
      final jsonData = {
        'id': key,
        'hash': DateTime.now().millisecondsSinceEpoch.toString(),
        'data': data
      };
      
      final jsonStr = _serializeJson(jsonData);
      final jsonPtr = jsonStr.toNativeUtf8();
      
      final resultPtr = db._updateData(_dbState!, jsonPtr);
      final resultStr = resultPtr.toDartString();
      
      malloc.free(jsonPtr);
      
      // Parsear respuesta de Rust
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) {
          try {
            final model = _parseLocalDbModel(jsonResponse);
            return Ok(model);
          } catch (e) {
            return Err(ErrorLocalDb.serializationError('Failed to parse response: $e'));
          }
        },
        err: (error) => Err(error)
      );
      
    } catch (e) {
      return Err(ErrorLocalDb.databaseError('Update failed: $e'));
    }
  }
  
  /// Eliminar registro (API compatible)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, ErrorLocalDb>> Delete(String key) async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    try {
      final keyPtr = key.toNativeUtf8();
      final resultPtr = db._deleteById(_dbState!, keyPtr);
      final resultStr = resultPtr.toDartString();
      
      malloc.free(keyPtr);
      
      // Parsear respuesta de Rust
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) => const Ok(true),
        err: (error) => Err(error)
      );
      
    } catch (e) {
      Log.w('Delete failed for key: $key - $e');
      return Err(ErrorLocalDb.databaseError('Delete failed: $e'));
    }
  }
  
  /// Obtener todos los registros (API compatible)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<List<LocalDbModel>, ErrorLocalDb>> GetAll() async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    try {
      final resultPtr = db._getAll(_dbState!);
      final resultStr = resultPtr.toDartString();
      
      // Parsear respuesta de Rust
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) {
          try {
            final models = _parseLocalDbModelList(jsonResponse);
            return Ok(models);
          } catch (e) {
            return Err(ErrorLocalDb.serializationError('Failed to parse response: $e'));
          }
        },
        err: (error) => Err(error)
      );
      
    } catch (e) {
      Log.w('GetAll failed - $e');
      return Err(ErrorLocalDb.databaseError('GetAll failed: $e'));
    }
  }
  
  /// Limpiar todos los datos (API compatible)
  // ignore: non_constant_identifier_names
  static Future<LocalDbResult<bool, ErrorLocalDb>> ClearData() async {
    final db = instance;
    if (!db._isInitialized || _dbState == nullptr) {
      return Err(ErrorLocalDb.databaseError('Database not initialized'));
    }
    
    try {
      final resultPtr = db._clearAllRecords(_dbState!);
      final resultStr = resultPtr.toDartString();
      
      final response = _parseRustResponse(resultStr);
      return response.when(
        ok: (jsonResponse) => const Ok(true),
        err: (error) => Err(error)
      );
      
    } catch (e) {
      return Err(ErrorLocalDb.databaseError('Clear failed: $e'));
    }
  }
  
  /// Verificar si está inicializado
  static bool get isInitialized {
    return instance._isInitialized && _dbState != nullptr;
  }
  
  /// Cerrar base de datos
  static Future<void> close() async {
    final db = instance;
    
    if (_dbState != nullptr && _lib != null) {
      try {
        db._closeDb(_dbState!);
      } catch (e) {
        Log.w('Error closing database - $e');
      }
    }
    
    db._isInitialized = false;
    _dbState = nullptr;
    _instance = null;
    _lib = null;
  }
  
  // Métodos privados
  
  static LocalDbResult<DynamicLibrary, ErrorLocalDb> _loadLibrary() {
    final possiblePaths = _getPossibleLibraryPaths();
    final List<String> attemptedPaths = [];
    
    // Intentar cada ruta hasta encontrar una que funcione
    for (final libPath in possiblePaths) {
      attemptedPaths.add(libPath);
      
      try {
        // Caso especial para iOS
        if (libPath == '__Internal__') {
          final lib = DynamicLibrary.process();
          Log.i('✅ Library loaded from iOS process');
          return Ok(lib);
        }
        
        // Android solo necesita el nombre
        if (Platform.isAndroid && libPath == 'liboffline_first_core.so') {
          final lib = DynamicLibrary.open(libPath);
          Log.i('✅ Library loaded from Android jniLibs');
          return Ok(lib);
        }
        
        // macOS - usar DynamicLibrary.process() para librerías del bundle
        if (Platform.isMacOS) {
          try {
            final lib = DynamicLibrary.process();
            Log.i('✅ Library loaded from macOS process bundle: $libPath');
            return Ok(lib);
          } catch (e) {
            Log.t('Failed to load from macOS process: $e');
            // Intentar carga directa como fallback
            try {
              final lib = DynamicLibrary.open(libPath);
              Log.i('✅ Library loaded directly from: $libPath');
              return Ok(lib);
            } catch (e2) {
              Log.t('Failed direct load: $e2');
            }
          }
        } else {
          // Desktop platforms (Linux, Windows) - verificar que el archivo existe
          if (File(libPath).existsSync()) {
            final lib = DynamicLibrary.open(libPath);
            Log.i('✅ Library loaded from: $libPath');
            return Ok(lib);
          }
        }
      } catch (e) {
        // Continuar con la siguiente ruta
        Log.t('Failed to load from $libPath: $e');
        continue;
      }
    }
    
    // Si llegamos aquí, no se pudo cargar ninguna librería
    final errorMessage = '''
Library not found. Attempted paths:
${attemptedPaths.map((path) => '  - $path').join('\n')}

To fix this issue, ensure that flutter_local_db binaries are available in one of the above locations.
For Android: Copy src/android/[arch]/liboffline_first_core.so to android/app/src/main/jniLibs/[arch]/
For Desktop: Ensure binaries are in the project root or src/ folder.
    ''';
    
    return Err(ErrorLocalDb.databaseError(errorMessage.trim()));
  }
  
  static List<String> _getPossibleLibraryPaths() {
    if (Platform.isAndroid) {
      // Android: El plugin FFI copia automáticamente los .so desde jniLibs/
      return ['liboffline_first_core.so'];
    } else if (Platform.isIOS) {
      // iOS: La librería está linkada estáticamente via podspec
      return ['__Internal__'];
    } else if (Platform.isMacOS) {
      // macOS: Detectar arquitectura y usar el binario apropiado
      // Intentar ARM64 primero (Apple Silicon), luego x86_64 (Intel)
      return [
        'liboffline_first_core_arm64.dylib',
        'liboffline_first_core_x86_64.dylib',
        'liboffline_first_core.dylib' // fallback para compatibilidad
      ];
    } else if (Platform.isLinux) {
      // Linux: CMake copia la librería al bundle
      return ['liboffline_first_core.so'];
    } else if (Platform.isWindows) {
      // Windows: La DLL debe estar en el directorio del ejecutable
      return ['offline_first_core.dll'];
    } else {
      throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
    }
  }
  
  void _loadFunctions(DynamicLibrary lib) {
    _createDb = lib.lookup<NativeFunction<CreateDbNative>>('create_db').asFunction<CreateDb>();
    _pushData = lib.lookup<NativeFunction<PushDataNative>>('push_data').asFunction<PushData>();
    _getById = lib.lookup<NativeFunction<GetByIdNative>>('get_by_id').asFunction<GetByIdFunc>();
    _getAll = lib.lookup<NativeFunction<GetAllNative>>('get_all').asFunction<GetAllFunc>();
    _updateData = lib.lookup<NativeFunction<UpdateDataNative>>('update_data').asFunction<UpdateData>();
    _deleteById = lib.lookup<NativeFunction<DeleteByIdNative>>('delete_by_id').asFunction<DeleteByIdFunc>();
    _clearAllRecords = lib.lookup<NativeFunction<ClearAllRecordsNative>>('clear_all_records').asFunction<ClearAllRecords>();
    _closeDb = lib.lookup<NativeFunction<CloseDbNative>>('close_database').asFunction<CloseDb>();
  }
  
  static LocalDbResult<String, ErrorLocalDb> _validateKey(String key) {
    if (key.length < 3) {
      return Err(ErrorLocalDb.validationError('Key must be at least 3 characters'));
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key)) {
      return Err(ErrorLocalDb.validationError('Key can only contain letters, numbers, hyphens, and underscores'));
    }
    
    return Ok(key);
  }
  
  /// Serializar datos a JSON string
  static String _serializeJson(Map<String, dynamic> data) {
    final buffer = StringBuffer('{');
    var first = true;
    
    data.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      
      buffer.write('"$key":');
      
      if (value is String) {
        buffer.write('"${value.replaceAll('"', '\\"').replaceAll('\\', '\\\\')}"');
      } else if (value is num || value is bool) {
        buffer.write(value.toString());
      } else if (value is Map) {
        buffer.write(_serializeJson(value.cast<String, dynamic>()));
      } else if (value is List) {
        buffer.write('[');
        for (var i = 0; i < value.length; i++) {
          if (i > 0) buffer.write(',');
          if (value[i] is String) {
            buffer.write('"${value[i].toString().replaceAll('"', '\\"')}"');
          } else {
            buffer.write(value[i].toString());
          }
        }
        buffer.write(']');
      } else if (value == null) {
        buffer.write('null');
      } else {
        buffer.write('"${value.toString().replaceAll('"', '\\"')}"');
      }
    });
    
    buffer.write('}');
    return buffer.toString();
  }
  
  /// Parsear respuesta de Rust (AppResponse format)
  static LocalDbResult<String, ErrorLocalDb> _parseRustResponse(String jsonStr) {
    try {
      // La respuesta de Rust viene en formato AppResponse
      final response = _parseJson(jsonStr);
      
      if (response.containsKey('Ok')) {
        return Ok(response['Ok'] as String);
      } else if (response.containsKey('NotFound')) {
        return Err(ErrorLocalDb.notFound(response['NotFound'] as String));
      } else if (response.containsKey('BadRequest')) {
        return Err(ErrorLocalDb.validationError(response['BadRequest'] as String));
      } else if (response.containsKey('SerializationError')) {
        return Err(ErrorLocalDb.serializationError(response['SerializationError'] as String));
      } else if (response.containsKey('DatabaseError')) {
        return Err(ErrorLocalDb.databaseError(response['DatabaseError'] as String));
      } else {
        return Err(ErrorLocalDb.databaseError('Unknown response format: $jsonStr'));
      }
    } catch (e) {
      return Err(ErrorLocalDb.serializationError('Failed to parse response: $e'));
    }
  }
  
  /// Parsear JSON simple
  static Map<String, dynamic> _parseJson(String jsonStr) {
    // Parser JSON simple para evitar dependencias
    final data = <String, dynamic>{};
    
    if (!jsonStr.startsWith('{') || !jsonStr.endsWith('}')) {
      throw FormatException('Invalid JSON format');
    }
    
    final content = jsonStr.substring(1, jsonStr.length - 1).trim();
    if (content.isEmpty) return data;
    
    // Para simplificar, usar split por comas (asumiendo JSON simple)
    final pairs = _splitJsonPairs(content);
    
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim().replaceAll('"', '');
        final value = pair.substring(colonIndex + 1).trim();
        
        if (value.startsWith('"') && value.endsWith('"')) {
          data[key] = value.substring(1, value.length - 1).replaceAll('\\"', '"').replaceAll('\\\\', '\\');
        } else if (value == 'true') {
          data[key] = true;
        } else if (value == 'false') {
          data[key] = false;
        } else if (value == 'null') {
          data[key] = null;
        } else if (RegExp(r'^\d+$').hasMatch(value)) {
          data[key] = int.parse(value);
        } else if (RegExp(r'^\d+\.\d+$').hasMatch(value)) {
          data[key] = double.parse(value);
        } else if (value.startsWith('{') && value.endsWith('}')) {
          data[key] = _parseJson(value);
        } else {
          data[key] = value;
        }
      }
    }
    
    return data;
  }
  
  /// Split JSON pairs considerando objetos anidados
  static List<String> _splitJsonPairs(String content) {
    final pairs = <String>[];
    var current = StringBuffer();
    var braceCount = 0;
    var inQuotes = false;
    var escaped = false;
    
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (escaped) {
        current.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        current.write(char);
        continue;
      }
      
      if (char == '"') {
        inQuotes = !inQuotes;
        current.write(char);
        continue;
      }
      
      if (!inQuotes) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;
        } else if (char == ',' && braceCount == 0) {
          pairs.add(current.toString().trim());
          current.clear();
          continue;
        }
      }
      
      current.write(char);
    }
    
    if (current.isNotEmpty) {
      pairs.add(current.toString().trim());
    }
    
    return pairs;
  }
  
  /// Parsear LocalDbModel desde JSON
  static LocalDbModel _parseLocalDbModel(String jsonStr) {
    final data = _parseJson(jsonStr);
    
    return LocalDbModel(
      id: data['id'] as String,
      data: (data['data'] as Map<String, dynamic>?) ?? {},
      hash: data['hash'] as String?
    );
  }
  
  /// Parsear lista de LocalDbModel desde JSON
  static List<LocalDbModel> _parseLocalDbModelList(String jsonStr) {
    if (jsonStr.trim() == '[]') return [];
    
    // Asumir que es un array JSON
    if (!jsonStr.startsWith('[') || !jsonStr.endsWith(']')) {
      throw FormatException('Expected JSON array');
    }
    
    final content = jsonStr.substring(1, jsonStr.length - 1).trim();
    if (content.isEmpty) return [];
    
    final models = <LocalDbModel>[];
    final objects = _splitJsonObjects(content);
    
    for (final objStr in objects) {
      try {
        final model = _parseLocalDbModel(objStr);
        models.add(model);
      } catch (e) {
        Log.w('Failed to parse model: $objStr - $e');
      }
    }
    
    return models;
  }
  
  /// Split objetos JSON en un array
  static List<String> _splitJsonObjects(String content) {
    final objects = <String>[];
    var current = StringBuffer();
    var braceCount = 0;
    var inQuotes = false;
    var escaped = false;
    
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (escaped) {
        current.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        current.write(char);
        continue;
      }
      
      if (char == '"') {
        inQuotes = !inQuotes;
        current.write(char);
        continue;
      }
      
      if (!inQuotes) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;
        } else if (char == ',' && braceCount == 0) {
          objects.add(current.toString().trim());
          current.clear();
          continue;
        }
      }
      
      current.write(char);
    }
    
    if (current.isNotEmpty) {
      objects.add(current.toString().trim());
    }
    
    return objects;
  }
}