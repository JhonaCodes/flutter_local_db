// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                           JSON SERIALIZER                                   ║
// ║                  Advanced JSON Serialization Utilities                      ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: json_serializer.dart                                                ║
// ║  Purpose: Enhanced JSON serialization with validation and type safety       ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides advanced JSON serialization capabilities beyond the standard    ║
// ║    dart:convert library. Includes type validation, custom serializers,     ║
// ║    and robust error handling for complex data structures.                  ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Type-safe JSON operations                                               ║
// ║    • Custom serialization rules                                              ║
// ║    • Deep validation and sanitization                                       ║
// ║    • Performance optimizations                                               ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:convert';
import '../models/local_db_result.dart';
import '../models/local_db_error.dart';
import 'package:logger_rs/logger_rs.dart';

/// Advanced JSON serialization utilities for database operations
///
/// Provides enhanced JSON serialization capabilities with validation,
/// custom type handling, and robust error reporting. Goes beyond the
/// standard dart:convert to provide database-specific optimizations.
class JsonSerializer {
  /// Maximum JSON string length (16MB)
  static const int maxJsonLength = 16 * 1024 * 1024;

  /// Maximum nesting depth to prevent stack overflow
  static const int maxNestingDepth = 100;

  /// Serializes data to a JSON string with validation
  ///
  /// Converts Dart objects to JSON with comprehensive validation and
  /// error handling. Supports all standard JSON types and provides
  /// helpful error messages for unsupported types.
  ///
  /// Parameters:
  /// - [data] - The data to serialize
  /// - [validate] - Whether to perform deep validation (default: true)
  /// - [pretty] - Whether to format with indentation (default: false)
  ///
  /// Returns:
  /// - [Ok] with JSON string on successful serialization
  /// - [Err] with detailed error information on failure
  ///
  /// Supported types:
  /// - `Map<String, dynamic>` - Objects
  /// - `List<dynamic>` - Arrays
  /// - `String` - Strings
  /// - `num`, `int`, `double` - Numbers
  /// - `bool` - Booleans
  /// - `null` - Null values
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.serialize({
  ///   'name': 'John Doe',
  ///   'age': 30,
  ///   'active': true,
  ///   'tags': ['user', 'premium'],
  ///   'metadata': {'lastLogin': '2024-01-01T00:00:00Z'},
  /// });
  ///
  /// result.when(
  ///   ok: (json) => print('Serialized: $json'),
  ///   err: (error) => print('Serialization failed: $error'),
  /// );
  /// ```
  static LocalDbResult<String, ErrorLocalDb> serialize(
    dynamic data, {
    bool validate = true,
    bool pretty = false,
  }) {
    Log.d('📝 Serializing data to JSON (validate: $validate, pretty: $pretty)');

    try {
      // Validate data before serialization if requested
      if (validate) {
        final validationResult = _validateForSerialization(data);
        if (validationResult.isErr) {
          return Err(validationResult.errOrNull!);
        }
      }

      // Perform serialization
      late String jsonString;
      if (pretty) {
        const encoder = JsonEncoder.withIndent('  ');
        jsonString = encoder.convert(data);
      } else {
        jsonString = jsonEncode(data);
      }

      // Check result length
      if (jsonString.length > maxJsonLength) {
        return Err(
          ErrorLocalDb.validationError(
            'Serialized JSON exceeds maximum length ($maxJsonLength bytes)',
            context: 'length: ${jsonString.length}',
          ),
        );
      }

      Log.d('✅ JSON serialization successful (${jsonString.length} bytes)');
      return Ok(jsonString);
    } catch (e, stackTrace) {
      Log.e('💥 JSON serialization failed: $e');
      return Err(
        ErrorLocalDb.serializationError(
          'Failed to serialize data to JSON',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Deserializes a JSON string to Dart objects with validation
  ///
  /// Converts JSON strings to Dart objects with comprehensive validation
  /// and error handling. Provides type checking and structure validation.
  ///
  /// Parameters:
  /// - [jsonString] - The JSON string to deserialize
  /// - [validate] - Whether to perform deep validation (default: true)
  ///
  /// Returns:
  /// - [Ok] with deserialized data on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.deserialize('{"name":"John","age":30}');
  /// result.when(
  ///   ok: (data) => print('Name: ${data['name']}'),
  ///   err: (error) => print('Deserialization failed: $error'),
  /// );
  /// ```
  static LocalDbResult<dynamic, ErrorLocalDb> deserialize(
    String jsonString, {
    bool validate = true,
  }) {
    Log.d('📖 Deserializing JSON string (${jsonString.length} bytes)');

    if (jsonString.isEmpty) {
      return Err(
        ErrorLocalDb.validationError(
          'JSON string cannot be empty',
          context: 'deserialization_input',
        ),
      );
    }

    if (jsonString.length > maxJsonLength) {
      return Err(
        ErrorLocalDb.validationError(
          'JSON string exceeds maximum length ($maxJsonLength bytes)',
          context: 'length: ${jsonString.length}',
        ),
      );
    }

    try {
      final data = jsonDecode(jsonString);

      // Validate structure if requested
      if (validate) {
        final validationResult = _validateStructure(data);
        if (validationResult.isErr) {
          return Err(validationResult.errOrNull!);
        }
      }

      Log.d('✅ JSON deserialization successful');
      return Ok(data);
    } catch (e, stackTrace) {
      Log.e('💥 JSON deserialization failed: $e');
      return Err(
        ErrorLocalDb.serializationError(
          'Failed to deserialize JSON string',
          context: 'JSON preview: ${_getJsonPreview(jsonString)}',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Safely converts data to ``` Map<String, dynamic>``` with validation
  ///
  /// Ensures the data is a valid Map with String keys and provides
  /// helpful error messages for invalid structures.
  ///
  /// Parameters:
  /// - [data] - The data to convert
  ///
  /// Returns:
  /// - [Ok] with validated Map on success
  /// - [Err] with validation error on failure
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.toMap(someData);
  /// result.when(
  ///   ok: (map) => print('Keys: ${map.keys}'),
  ///   err: (error) => print('Not a valid map: $error'),
  /// );
  /// ```
  static LocalDbResult<Map<String, dynamic>, ErrorLocalDb> toMap(dynamic data) {
    Log.d('🗺️ Converting data to Map<String, dynamic>');

    if (data == null) {
      return Err(
        ErrorLocalDb.validationError(
          'Cannot convert null to Map',
          context: 'type_conversion',
        ),
      );
    }

    if (data is! Map) {
      return Err(
        ErrorLocalDb.validationError(
          'Data is not a Map (${data.runtimeType})',
          context: 'expected: Map, actual: ${data.runtimeType}',
        ),
      );
    }

    try {
      final result = <String, dynamic>{};

      for (final entry in data.entries) {
        if (entry.key is! String) {
          return Err(
            ErrorLocalDb.validationError(
              'Map key is not a String (${entry.key.runtimeType})',
              context: 'key: ${entry.key}, type: ${entry.key.runtimeType}',
            ),
          );
        }

        result[entry.key as String] = entry.value;
      }

      Log.d('✅ Map conversion successful (${result.length} entries)');
      return Ok(result);
    } catch (e, stackTrace) {
      Log.e('💥 Map conversion failed: $e');
      return Err(
        ErrorLocalDb.validationError(
          'Failed to convert data to Map<String, dynamic>',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Safely converts data to ``` List<dynamic> ``` with validation
  ///
  /// Ensures the data is a valid List and provides helpful error
  /// messages for invalid types.
  ///
  /// Parameters:
  /// - [data] - The data to convert
  ///
  /// Returns:
  /// - [Ok] with validated List on success
  /// - [Err] with validation error on failure
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.toList(someData);
  /// result.when(
  ///   ok: (list) => print('Length: ${list.length}'),
  ///   err: (error) => print('Not a valid list: $error'),
  /// );
  /// ```
  static LocalDbResult<List<dynamic>, ErrorLocalDb> toList(dynamic data) {
    Log.d('📋 Converting data to List<dynamic>');

    if (data == null) {
      return Err(
        ErrorLocalDb.validationError(
          'Cannot convert null to List',
          context: 'type_conversion',
        ),
      );
    }

    if (data is! List) {
      return Err(
        ErrorLocalDb.validationError(
          'Data is not a List (${data.runtimeType})',
          context: 'expected: List, actual: ${data.runtimeType}',
        ),
      );
    }

    try {
      final result = List<dynamic>.from(data);
      Log.d('✅ List conversion successful (${result.length} items)');
      return Ok(result);
    } catch (e, stackTrace) {
      Log.e('💥 List conversion failed: $e');
      return Err(
        ErrorLocalDb.validationError(
          'Failed to convert data to List<dynamic>',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Validates if data can be serialized to JSON
  ///
  /// Performs deep validation of data structure to ensure it contains
  /// only JSON-serializable types and doesn't exceed nesting limits.
  ///
  /// Parameters:
  /// - [data] - The data to validate
  ///
  /// Returns:
  /// - [Ok] if data is valid for serialization
  /// - [Err] with specific validation error
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.validateSerializable(complexData);
  /// result.when(
  ///   ok: (_) => print('Data is serializable'),
  ///   err: (error) => print('Validation failed: $error'),
  /// );
  /// ```
  static LocalDbResult<void, ErrorLocalDb> validateSerializable(dynamic data) {
    Log.d('🔍 Validating data for JSON serialization');
    return _validateForSerialization(data);
  }

  /// Deep clones JSON-serializable data
  ///
  /// Creates a deep copy of data by serializing and deserializing it.
  /// This ensures complete isolation between the original and copy.
  ///
  /// Parameters:
  /// - [data] - The data to clone
  ///
  /// Returns:
  /// - [Ok] with cloned data on success
  /// - [Err] with error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = JsonSerializer.deepClone(originalData);
  /// result.when(
  ///   ok: (cloned) => print('Data cloned successfully'),
  ///   err: (error) => print('Clone failed: $error'),
  /// );
  /// ```
  static LocalDbResult<dynamic, ErrorLocalDb> deepClone(dynamic data) {
    Log.d('🔄 Performing deep clone of data');

    final serializeResult = serialize(data, validate: false);
    if (serializeResult.isErr) {
      return Err(serializeResult.errOrNull!);
    }

    final deserializeResult = deserialize(
      serializeResult.okOrNull!,
      validate: false,
    );
    if (deserializeResult.isErr) {
      return Err(deserializeResult.errOrNull!);
    }

    Log.d('✅ Deep clone completed successfully');
    return Ok(deserializeResult.okOrNull!);
  }

  /// Validates data for JSON serialization
  static LocalDbResult<void, ErrorLocalDb> _validateForSerialization(
    dynamic data, {
    int depth = 0,
    Set<Object>? visited,
  }) {
    visited ??= <Object>{};

    // Check nesting depth
    if (depth > maxNestingDepth) {
      return Err(
        ErrorLocalDb.validationError(
          'Data nesting exceeds maximum depth ($maxNestingDepth)',
          context: 'depth: $depth',
        ),
      );
    }

    // Handle null
    if (data == null) {
      return const Ok(null);
    }

    // Handle primitive types
    if (data is String || data is num || data is bool) {
      return const Ok(null);
    }

    // Check for circular references in objects
    if (data is Object && visited.contains(data)) {
      return Err(
        ErrorLocalDb.validationError(
          'Circular reference detected in data structure',
          context: 'type: ${data.runtimeType}',
        ),
      );
    }

    // Handle Maps
    if (data is Map) {
      visited.add(data);

      for (final entry in data.entries) {
        // Validate key
        if (entry.key is! String) {
          return Err(
            ErrorLocalDb.validationError(
              'Map key must be String, found ${entry.key.runtimeType}',
              context: 'key: ${entry.key}',
            ),
          );
        }

        // Validate value recursively
        final valueValidation = _validateForSerialization(
          entry.value,
          depth: depth + 1,
          visited: visited,
        );
        if (valueValidation.isErr) {
          return valueValidation;
        }
      }

      visited.remove(data);
      return const Ok(null);
    }

    // Handle Lists
    if (data is List) {
      visited.add(data);

      for (int i = 0; i < data.length; i++) {
        final itemValidation = _validateForSerialization(
          data[i],
          depth: depth + 1,
          visited: visited,
        );
        if (itemValidation.isErr) {
          return itemValidation;
        }
      }

      visited.remove(data);
      return const Ok(null);
    }

    // Unsupported type
    return Err(
      ErrorLocalDb.validationError(
        'Unsupported type for JSON serialization: ${data.runtimeType}',
        context: 'value: $data',
      ),
    );
  }

  /// Validates deserialized JSON structure
  static LocalDbResult<void, ErrorLocalDb> _validateStructure(
    dynamic data, {
    int depth = 0,
  }) {
    // Check nesting depth
    if (depth > maxNestingDepth) {
      return Err(
        ErrorLocalDb.validationError(
          'Deserialized data nesting exceeds maximum depth ($maxNestingDepth)',
          context: 'depth: $depth',
        ),
      );
    }

    // Handle null and primitives
    if (data == null || data is String || data is num || data is bool) {
      return const Ok(null);
    }

    // Handle Maps
    if (data is Map) {
      for (final entry in data.entries) {
        if (entry.key is! String) {
          return Err(
            ErrorLocalDb.validationError(
              'Invalid map key type in deserialized data: ${entry.key.runtimeType}',
              context: 'key: ${entry.key}',
            ),
          );
        }

        final valueValidation = _validateStructure(
          entry.value,
          depth: depth + 1,
        );
        if (valueValidation.isErr) {
          return valueValidation;
        }
      }
      return const Ok(null);
    }

    // Handle Lists
    if (data is List) {
      for (final item in data) {
        final itemValidation = _validateStructure(item, depth: depth + 1);
        if (itemValidation.isErr) {
          return itemValidation;
        }
      }
      return const Ok(null);
    }

    // Unexpected type in JSON data
    return Err(
      ErrorLocalDb.validationError(
        'Unexpected type in deserialized JSON: ${data.runtimeType}',
        context: 'value: $data',
      ),
    );
  }

  /// Gets a preview of JSON string for error messages
  static String _getJsonPreview(String jsonString) {
    if (jsonString.length <= 100) {
      return jsonString;
    }
    return '${jsonString.substring(0, 100)}...';
  }
}
