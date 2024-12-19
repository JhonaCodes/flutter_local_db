/// Model that represents a directory entry in the database system.
/// Used to organize and structure data hierarchically within the storage.
class DirectoryModel {
  /// Unique identifier for the directory
  /// Used to reference and locate specific directory nodes
  final String id;

  /// Contains the directory's metadata and structure information
  /// Flexible map structure allows for various directory configurations
  final Map data;

  /// Creates a new directory instance with required identifier and data
  DirectoryModel({required this.id, required this.data});

  /// Converts the directory entry to a JSON format
  /// Used when persisting directory structure
  toJson() {
    return {'id': id, 'data': data};
  }

  /// Creates a directory instance from a JSON map
  /// Used when loading directory structure from storage
  factory DirectoryModel.fromJson(Map json) {
    return DirectoryModel(
      id: json['id'],
      data: json['data'],
    );
  }
}
