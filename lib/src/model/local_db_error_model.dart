import 'dart:convert';

/// A model class that represents errors that can occur during database operations.
/// This class provides a structured way to handle and serialize error information.
/// Representa los diferentes tipos de errores que pueden ocurrir en la aplicación.
/// Basado en la enumeración AppResponse de Rust.
enum ErrorType {
  databaseError,
  serializationError,
  notFound,
  validationError,
  badRequest,
  unknown,
}

/// Modelo para representar errores de la aplicación.
/// Adaptado desde la enumeración AppResponse de Rust.
class ErrorLocalDb {
  /// El tipo de error que ocurrió
  final ErrorType type;

  /// Mensaje detallado del error
  final DetailsModel detailsResult;

  /// Opcional: objeto de error original si está disponible
  final Object? originalError;

  /// Opcional: traza de la pila si está disponible
  final StackTrace? stackTrace;

  /// Crea una nueva instancia de [ErrorLocalDb].
  ///
  /// [type] y [detailsResult] son parámetros requeridos.
  /// [originalError] y [stackTrace] son opcionales.
  ErrorLocalDb({
    required this.type,
    required this.detailsResult,
    this.originalError,
    this.stackTrace,
  });

  /// Crea un error de tipo DatabaseError
  factory ErrorLocalDb.databaseError(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.databaseError,
      detailsResult: DetailsModel.fromJson(message, 'DatabaseError'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un error de tipo SerializationError
  factory ErrorLocalDb.serializationError(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.serializationError,
      detailsResult: DetailsModel.fromJson(message, 'SerializationError'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un error de tipo NotFound
  factory ErrorLocalDb.notFound(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.notFound,
      detailsResult: DetailsModel.fromJson(message, 'NotFound'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un error de tipo ValidationError
  factory ErrorLocalDb.validationError(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.validationError,
      detailsResult: DetailsModel.fromJson(message, 'ValidationError'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un error de tipo BadRequest
  factory ErrorLocalDb.badRequest(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.badRequest,
      detailsResult: DetailsModel.fromJson(message, 'BadRequest'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un error de tipo desconocido
  factory ErrorLocalDb.unknown(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: ErrorType.unknown,
      detailsResult: DetailsModel.fromJson(message, 'Unknown'),
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// Crea un modelo de error desde una cadena con formato de error Rust
  /// Por ejemplo: "NotFound: No model found with id: current-fasting-plan"
  factory ErrorLocalDb.fromRustError(
    String rustErrorString, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    // Intentar parsear el mensaje de error
    final colonIndex = rustErrorString.indexOf(':');
    if (colonIndex == -1) {
      return ErrorLocalDb.unknown(
        rustErrorString,
        originalError: originalError,
        stackTrace: stackTrace,
      );
    }

    final errorType = rustErrorString.substring(0, colonIndex).trim();
    final errorMessage = rustErrorString.substring(colonIndex + 1).trim();

    switch (errorType) {
      case 'DatabaseError':
        return ErrorLocalDb.databaseError(
          errorMessage,
          originalError: originalError,
          stackTrace: stackTrace,
        );
      case 'SerializationError':
        return ErrorLocalDb.serializationError(
          errorMessage,
          originalError: originalError,
          stackTrace: stackTrace,
        );
      case 'NotFound':
        return ErrorLocalDb.notFound(
          errorMessage,
          originalError: originalError,
          stackTrace: stackTrace,
        );
      case 'ValidationError':
        return ErrorLocalDb.validationError(
          errorMessage,
          originalError: originalError,
          stackTrace: stackTrace,
        );
      case 'BadRequest':
        return ErrorLocalDb.badRequest(
          errorMessage,
          originalError: originalError,
          stackTrace: stackTrace,
        );
      default:
        return ErrorLocalDb.unknown(
          rustErrorString,
          originalError: originalError,
          stackTrace: stackTrace,
        );
    }
  }

  /// Convierte el modelo de error a un mapa JSON.
  Map<String, dynamic> toJson() => {
    'type': type.toString().split('.').last,
    'message': detailsResult,
    'originalError': originalError?.toString(),
    'stackTrace': stackTrace?.toString(),
  };

  /// Proporciona una representación en cadena del modelo de error.
  @override
  String toString() {
    final typeString = type.toString().split('.').last;
    return '$typeString: $detailsResult';
  }

  /// Crea una copia de este modelo de error con actualizaciones opcionales de campos.
  ErrorLocalDb copyWith({
    ErrorType? type,
    DetailsModel? message,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return ErrorLocalDb(
      type: type ?? this.type,
      detailsResult: message ?? this.detailsResult,
      originalError: originalError ?? this.originalError,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}

class DetailsModel {
  final String type;
  final String message;

  DetailsModel(this.type, this.message);

  factory DetailsModel.fromJson(String jsonString, [String? type]) {
    // Si ya tenemos un tipo, simplemente usar el string como mensaje
    if (type != null) {
      return DetailsModel(type, jsonString);
    }

    // Intentar parsear como JSON
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return DetailsModel(
          decoded['type']?.toString() ?? 'Unknown',
          decoded['message']?.toString() ?? jsonString,
        );
      }
    } catch (e) {
      // Si no es JSON válido, usar como mensaje directo
    }

    // Fallback: usar el string completo como mensaje
    return DetailsModel(type ?? 'Unknown', jsonString);
  }
}
