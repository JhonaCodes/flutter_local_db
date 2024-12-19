/// Model that represents the API response format for database queries and requests.
/// Encapsulates both the data and its metadata for consistent response handling.
class DataLocalDBModel {
  /// Unique identifier for the record
  /// Used to track and reference specific data entries
  final String id;

  /// Size of the data payload in kilobytes
  /// Helps monitor storage usage and optimize data transfer
  final double sizeKb;

  /// Hash value of the data
  /// Used for data integrity verification and caching purposes
  final int hash;

  /// Actual payload data stored in key-value format
  /// Flexible structure allows storing various data types
  final Map<dynamic, dynamic> data;

  /// Creates a new instance with all required fields
  DataLocalDBModel({
    required this.id,
    required this.sizeKb,
    required this.hash,
    required this.data
  });

  /// Converts the model instance to a JSON map
  /// Used when sending responses to API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': sizeKb,
      'hash': hash,
      'data': data,
    };
  }

  /// Creates an instance from a JSON map
  /// Used when deserializing API responses
  factory DataLocalDBModel.fromJson(Map<String, dynamic> json) {
    return DataLocalDBModel(
      id: json['id'] as String,
      sizeKb: (json['size'] as num).toDouble(),
      hash: json['hash'] as int,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  /// Creates a copy of this instance with optionally updated fields
  /// Useful for modifying response data while maintaining immutability
  DataLocalDBModel copyWith({
    String? id,
    double? size,
    int? hash,
    Map<String, dynamic>? data,
  }) {
    return DataLocalDBModel(
      id: id ?? this.id,
      sizeKb: size ?? sizeKb,
      hash: hash ?? this.hash,
      data: data ?? this.data,
    );
  }
}