import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Maneja la escritura eficiente de datos en bloques de archivo,
/// implementando un sistema de buffer y control de escrituras.
class BlockDataWriter {
  final String blockPath;
  final int maxRecordsPerBlock;
  final int bufferSize;

  final List<Map<String, dynamic>> _writeBuffer = [];
  int _currentRecordCount = 0;
  bool _isDirty = false;
  bool _isInitialized = false;  // Añadimos control de inicialización

  BlockDataWriter({
    required this.blockPath,
    required this.maxRecordsPerBlock,
    this.bufferSize = 50,
  });

  /// Inicializa el writer y cuenta los registros existentes
  Future<void> initialize() async {
    if (_isInitialized) return;

    final file = File(blockPath);
    if (await file.exists()) {
      _currentRecordCount = await _countLines();
    }
    _isInitialized = true;
  }

  Future<int> _countLines() async {
    final file = File(blockPath);
    int lines = 0;
    final stream = file.openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (var line in stream) {
      lines++;
    }
    return lines;
  }

  Future<void> addRecord(DataLocalDBModel record) async {
    if (!_isInitialized) {
      throw BlockWriterException('BlockDataWriter no está inicializado');
    }

    if (_currentRecordCount >= maxRecordsPerBlock) {
      throw BlockFullException('Bloque lleno');
    }

    _writeBuffer.add(record.toJson());
    _isDirty = true;
    _currentRecordCount++;

    if (_writeBuffer.length >= bufferSize) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (!_isDirty) return;

    final file = File(blockPath);
    final sink = file.openWrite(mode: FileMode.append);

    for (final record in _writeBuffer) {
      sink.writeln(json.encode(record));
    }

    await sink.flush();
    await sink.close();

    _writeBuffer.clear();
    _isDirty = false;
  }

  /// Cierra el writer y asegura que todos los datos pendientes sean escritos
  Future<void> close() async {
    if (_isDirty) {
      await flush();
    }
    _isInitialized = false;
  }

  /// Obtiene el número actual de registros en el bloque
  int get currentRecordCount => _currentRecordCount;

  /// Verifica si el bloque está lleno
  bool get isFull => _currentRecordCount >= maxRecordsPerBlock;
}

/// Excepciones personalizadas para el manejo de errores
class BlockWriterException implements Exception {
  final String message;
  BlockWriterException(this.message);

  @override
  String toString() => 'BlockWriterException: $message';
}

class BlockFullException implements Exception {
  final String message;
  BlockFullException(this.message);

  @override
  String toString() => 'BlockFullException: $message';
}