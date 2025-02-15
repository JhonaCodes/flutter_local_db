/// Represents a response model for local database interactions.
///
/// This class is designed to store and manage local database records with
/// a unique identifier, hash for change tracking, last update timestamp,
/// and a flexible data map.
class LocalDbResponseModel {
  /// A unique identifier used for calling and saving data.
  final String id;

  /// A hash used by Rust to identify if the current data is unchanged.
  final String hash;

  /// The timestamp of the last update to this record.
  final String lastUpdate;

  /// A dynamic map containing the actual data of the record.
  ///
  /// Allows for flexible storage of various types of data.
  final Map<String, dynamic> data;

  /// Constructs a [LocalDbResponseModel] with required parameters.
  ///
  /// [id] is the unique identifier for the record.
  /// [hash] is used for change detection.
  /// [data] contains the actual record data.
  /// [lastUpdate] indicates when the record was last modified.
  LocalDbResponseModel({
    required this.id,
    required this.hash,
    required this.data,
    required this.lastUpdate,
  });

  /// Converts the model to a JSON-compatible map.
  ///
  /// Useful for serialization and storage.
  ///
  /// Returns a [Map] representation of the model.
  Map<String, dynamic> toJson() => {
        'id': id,
        'hash': hash,
        'data': data,
        'last_update': lastUpdate,
      };

  /// Creates a [LocalDbResponseModel] from a JSON map.
  ///
  /// [json] is a map containing the model's data.
  ///
  /// Returns a new [LocalDbResponseModel] instance.
  factory LocalDbResponseModel.fromJson(Map<String, dynamic> json) =>
      LocalDbResponseModel(
        id: json['id'],
        hash: json['hash'],
        data: json['data'],
        lastUpdate: json['last_update'],
      );

  /// Provides a string representation of the model.
  ///
  /// Useful for debugging and logging.
  ///
  /// Returns a [String] describing the model's contents.
  @override
  String toString() {
    return 'LocalDbModel{id: $id, hash: $hash, data: $data, last_update: $lastUpdate}';
  }

  /// Creates a copy of the model with optional parameter overrides.
  ///
  /// [id] optional new identifier
  /// [hash] optional new hash
  /// [data] optional new data map
  /// [lastUpdate] optional new last update timestamp
  ///
  /// Returns a new [LocalDbResponseModel] with specified changes.
  LocalDbResponseModel copyWith({
    String? id,
    String? hash,
    Map<String, dynamic>? data,
    String? lastUpdate,
  }) =>
      LocalDbResponseModel(
        id: id ?? this.id,
        hash: hash ?? this.hash,
        data: data ?? this.data,
        lastUpdate: lastUpdate ?? this.lastUpdate,
      );
}
