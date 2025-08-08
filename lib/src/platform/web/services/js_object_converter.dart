import 'dart:convert';
import '../../../core/models.dart';
import '../../../core/log.dart';

/// Service responsible for converting between JavaScript objects and Dart objects
/// 
/// Handles the serialization and deserialization of data when interacting
/// with IndexedDB, ensuring type safety and proper error handling.
class JSObjectConverter {
  JSObjectConverter._();

  /// Converts a DbEntry to a JavaScript object for IndexedDB storage
  /// 
  /// The object structure matches what IndexedDB expects:
  /// - id: Primary key for the record
  /// - data: JSON-encoded user data
  /// - hash: Timestamp-based hash for versioning
  static Object entryToJSObject(DbEntry entry) {
    try {
      return {
        'id': entry.id,
        'data': jsonEncode(entry.data),
        'hash': entry.hash,
      };
    } catch (e) {
      Log.e('Failed to convert DbEntry to JS object: $e');
      rethrow;
    }
  }

  /// Converts a JavaScript object from IndexedDB to a Dart Map
  /// 
  /// Handles various JS object types and provides fallbacks for edge cases.
  /// Returns a Map that can be safely used by Dart code.
  static Map<String, dynamic> jsObjectToMap(Object jsObject) {
    final map = <String, dynamic>{};
    
    try {
      // Handle direct Map conversion (most common case)
      if (jsObject is Map) {
        return Map<String, dynamic>.from(jsObject);
      }
      
      // Handle JS object with dynamic property access
      map['id'] = _getPropertySafe(jsObject, 'id', '');
      map['data'] = _getPropertySafe(jsObject, 'data', '{}');
      map['hash'] = _getPropertySafe(jsObject, 'hash', '');
      
      return map;
    } catch (e) {
      Log.e('Failed to convert JS object to map: $e');
      
      // Return minimal valid structure as fallback
      return {
        'id': '',
        'data': '{}',
        'hash': '',
      };
    }
  }

  /// Parses a Map from IndexedDB to a DbEntry
  /// 
  /// Handles JSON deserialization and creates a properly typed DbEntry object.
  static DbEntry mapToDbEntry(Map<String, dynamic> record) {
    try {
      final id = record['id'] as String;
      final dataJson = record['data'] as String;
      final hash = record['hash'] as String;
      
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      
      return DbEntry(id: id, data: data, hash: hash);
    } catch (e) {
      Log.e('Failed to parse map to DbEntry: $e');
      rethrow;
    }
  }

  /// Safely extracts a property from a JavaScript object
  /// 
  /// Provides a fallback value if the property doesn't exist or is null.
  static String _getPropertySafe(Object jsObject, String propertyName, String fallback) {
    try {
      final value = (jsObject as dynamic)[propertyName];
      return value?.toString() ?? fallback;
    } catch (e) {
      Log.d('Property $propertyName not found, using fallback: $fallback');
      return fallback;
    }
  }

  /// Validates that a JavaScript object has the expected structure
  /// 
  /// Checks for the presence of required properties before conversion.
  static bool isValidJSObject(Object jsObject) {
    try {
      final hasId = _getPropertySafe(jsObject, 'id', '').isNotEmpty;
      final hasData = _getPropertySafe(jsObject, 'data', '').isNotEmpty;
      final hasHash = _getPropertySafe(jsObject, 'hash', '').isNotEmpty;
      
      return hasId && hasData && hasHash;
    } catch (e) {
      Log.e('Invalid JS object structure: $e');
      return false;
    }
  }
}