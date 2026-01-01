// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              DATA MODEL                                      ║
// ║                       Local Database Data Model                             ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: local_db_model.dart                                                 ║
// ║  Purpose: Core data model for database records                              ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Defines the core data model used for all database records. Provides      ║
// ║    a flexible structure that can store arbitrary JSON data while            ║
// ║    maintaining metadata like timestamps and content hashes.                 ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Flexible JSON data storage                                              ║
// ║    • Automatic timestamp management                                          ║
// ║    • Content hash for data integrity                                         ║
// ║    • Immutable design pattern                                                ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:convert';

/// Core data model for database records
///
/// This is the primary data structure used to store and retrieve information
/// from the local database. It provides a flexible container for arbitrary
/// JSON data while maintaining important metadata.
///
/// Example:
/// ```dart
/// final model = LocalDbModel(
///   id: 'user_123',
///   data: {
///     'name': 'John Doe',
///     'email': 'john@example.com',
///     'age': 30,
///   },
/// );
///
/// print('User: ${model.data['name']}');
/// print('Created: ${model.createdAt}');
/// ```
class LocalDbModel {
  /// Unique identifier for this record
  ///
  /// This is the primary key used to store and retrieve the record.
  /// Must be unique within the database.
  final String id;

  /// The actual data stored in this record
  ///
  /// Can contain any JSON-serializable data including nested objects,
  /// arrays, strings, numbers, and booleans.
  final Map<String, dynamic> data;

  /// Timestamp when this record was created
  ///
  /// Automatically set when the model is created. Used for tracking
  /// when records were first inserted into the database.
  final DateTime createdAt;

  /// Timestamp when this record was last updated
  ///
  /// Updated whenever the record is modified. Useful for tracking
  /// data freshness and implementing synchronization logic.
  final DateTime updatedAt;

  /// Content hash for data integrity verification
  ///
  /// A hash of the data content used to verify data integrity and
  /// detect changes. Automatically calculated from the data.
  final String contentHash;

  /// Creates a new LocalDbModel instance
  ///
  /// [id] - Unique identifier for the record
  /// [data] - The JSON data to store
  /// [createdAt] - Creation timestamp (defaults to now)
  /// [updatedAt] - Last update timestamp (defaults to now)
  /// [contentHash] - Content hash (auto-calculated if not provided)
  LocalDbModel({
    required this.id,
    required this.data,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contentHash,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       contentHash = contentHash ?? _calculateHash(data);

  /// Creates a model from a JSON string
  ///
  /// Used for deserializing models from database storage.
  ///
  /// Example:
  /// ```dart
  /// final jsonString = '{"id":"user_123","data":{"name":"John"},"createdAt":"2024-01-01T00:00:00.000Z"}';
  /// final model = LocalDbModel.fromJson(jsonString);
  /// ```
  factory LocalDbModel.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return LocalDbModel.fromMap(map);
  }

  /// Creates a model from a Map
  ///
  /// Used for deserializing models from parsed JSON data.
  /// Supports both Dart format (contentHash) and Rust format (hash).
  ///
  /// Example:
  /// ```dart
  /// final map = {
  ///   'id': 'user_123',
  ///   'data': {'name': 'John'},
  ///   'hash': 'abc123',
  /// };
  /// final model = LocalDbModel.fromMap(map);
  /// ```
  factory LocalDbModel.fromMap(Map<String, dynamic> map) {
    final dataMap = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : <String, dynamic>{};

    return LocalDbModel(
      id: map['id'] as String,
      data: dataMap,
      // Support optional timestamps (Rust doesn't send them)
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      // Support both 'hash' (Rust) and 'contentHash' (Dart)
      contentHash: (map['hash'] as String?) ??
          (map['contentHash'] as String?) ??
          _calculateHash(dataMap),
    );
  }

  /// Converts the model to a JSON string
  ///
  /// Used for serializing models for database storage.
  ///
  /// Example:
  /// ```dart
  /// final jsonString = model.toJson();
  /// // {"id":"user_123","data":{"name":"John"},"createdAt":"2024-01-01T00:00:00.000Z",...}
  /// ```
  String toJson() => jsonEncode(toMap());

  /// Converts the model to a Map
  ///
  /// Used for serializing models to JSON-compatible format.
  /// Uses 'hash' as field name for Rust compatibility.
  ///
  /// Example:
  /// ```dart
  /// final map = model.toMap();
  /// print(map['id']); // user_123
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hash': contentHash, // Rust expects 'hash' not 'contentHash'
      'data': data,
    };
  }

  /// Creates a copy of this model with updated data
  ///
  /// This method creates a new immutable instance with the provided
  /// changes. The updatedAt timestamp and contentHash are automatically
  /// recalculated when data is modified.
  ///
  /// Example:
  /// ```dart
  /// final updatedModel = model.copyWith(
  ///   data: {'name': 'Jane Doe', 'age': 25},
  /// );
  /// ```
  LocalDbModel copyWith({
    String? id,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contentHash,
  }) {
    final newData = data ?? this.data;
    return LocalDbModel(
      id: id ?? this.id,
      data: newData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? (data != null ? DateTime.now() : this.updatedAt),
      contentHash:
          contentHash ??
          (data != null ? _calculateHash(newData) : this.contentHash),
    );
  }

  /// Creates a copy with updated data only
  ///
  /// Convenience method for updating just the data field.
  /// Automatically updates the timestamp and content hash.
  ///
  /// Example:
  /// ```dart
  /// final updated = model.updateData({'name': 'New Name'});
  /// ```
  LocalDbModel updateData(Map<String, dynamic> newData) {
    return copyWith(data: newData);
  }

  /// Merges new data with existing data
  ///
  /// Performs a shallow merge of the new data with existing data.
  /// Useful for partial updates that don't replace the entire data object.
  ///
  /// Example:
  /// ```dart
  /// // Original data: {'name': 'John', 'age': 30}
  /// final updated = model.mergeData({'age': 31, 'city': 'NYC'});
  /// // Result data: {'name': 'John', 'age': 31, 'city': 'NYC'}
  /// ```
  LocalDbModel mergeData(Map<String, dynamic> additionalData) {
    final mergedData = Map<String, dynamic>.from(data);
    mergedData.addAll(additionalData);
    return updateData(mergedData);
  }

  /// Checks if the data has been modified since creation
  ///
  /// Returns true if the updatedAt timestamp is different from createdAt.
  ///
  /// Example:
  /// ```dart
  /// if (model.isModified) {
  ///   print('Record has been updated since creation');
  /// }
  /// ```
  bool get isModified {
    return updatedAt.isAfter(createdAt);
  }

  /// Gets the age of this record
  ///
  /// Returns the duration since the record was created.
  ///
  /// Example:
  /// ```dart
  /// print('Record age: ${model.age.inHours} hours');
  /// ```
  Duration get age {
    return DateTime.now().difference(createdAt);
  }

  /// Gets the time since last update
  ///
  /// Returns the duration since the record was last modified.
  ///
  /// Example:
  /// ```dart
  /// print('Last updated: ${model.timeSinceUpdate.inMinutes} minutes ago');
  /// ```
  Duration get timeSinceUpdate {
    return DateTime.now().difference(updatedAt);
  }

  /// Validates the content hash
  ///
  /// Verifies that the stored content hash matches the calculated hash
  /// of the current data. Useful for detecting data corruption.
  ///
  /// Example:
  /// ```dart
  /// if (!model.isContentHashValid) {
  ///   print('Warning: Data may be corrupted!');
  /// }
  /// ```
  bool get isContentHashValid {
    return contentHash == _calculateHash(data);
  }

  /// Gets a specific field from the data
  ///
  /// Convenience method for accessing nested data fields safely.
  /// Returns null if the field doesn't exist.
  ///
  /// Example:
  /// ```dart
  /// final name = model.getField('name') as String?;
  /// final nested = model.getField('profile.avatar.url') as String?;
  /// ```
  T? getField<T>(String path) {
    final parts = path.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current is T ? current : null;
  }

  /// Calculates a hash of the data content
  ///
  /// Used internally for data integrity verification.
  /// Creates a simple hash based on the JSON representation of the data.
  static String _calculateHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    return jsonString.hashCode.toString();
  }

  @override
  String toString() {
    return 'LocalDbModel(id: $id, dataKeys: ${data.keys.toList()}, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Returns a detailed string representation for debugging
  String toDetailedString() {
    return '''LocalDbModel Details:
  ID: $id
  Created: $createdAt
  Updated: $updatedAt
  Modified: $isModified
  Age: ${age.inHours}h ${age.inMinutes.remainder(60)}m
  Content Hash: $contentHash
  Valid Hash: $isContentHashValid
  Data Keys: ${data.keys.toList()}
  Data: ${jsonEncode(data)}''';
  }

  @override
  bool operator ==(Object other) {
    return other is LocalDbModel &&
        other.id == id &&
        other.contentHash == contentHash &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, contentHash, createdAt, updatedAt);
  }
}
