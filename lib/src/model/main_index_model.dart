// Main folder mapping class
/// Main index model that manages the directory structure of the database.
/// It maintains a hierarchical index of all folders and their respective sub-indices,
/// distributing and organizing indices across primary and secondary levels.
class MainIndexModel {
  /// Total number of indices across all containers
  /// Used for tracking overall database organization
  final int totalIndex;

  /// Map of container names to their respective path structures
  /// Each container represents a major data partition in the system
  final Map<String, ContainerPaths> containers;

  /// Creates a new instance with specified total index count and container mappings
  MainIndexModel({
    required this.totalIndex,
    required this.containers,
  });

  /// Creates an instance from a JSON map, typically used when loading
  /// the main index from storage
  ///
  /// Processes all entries except 'total_index' as container definitions
  factory MainIndexModel.fromJson(Map<String, dynamic> json) {
    // Create a map of containers, excluding the 'total_index' field
    final containersMap = Map<String, ContainerPaths>.fromEntries(
      json.entries.where((e) => e.key != 'total_index').map(
            (e) => MapEntry(
              e.key,
              ContainerPaths.fromJson(e.value as Map<String, dynamic>),
            ),
          ),
    );

    return MainIndexModel(
      totalIndex: json['total_index'] ?? 0,
      containers: containersMap,
    );
  }

  /// Converts the current state to a JSON map for persistence
  /// Includes total index count and all container configurations
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'total_index': totalIndex,
    };

    // Add all container entries to the map
    containers.forEach((key, value) {
      data[key] = value.toJson();
    });

    return data;
  }

  /// Creates an initial empty index structure
  /// Used when initializing a new database instance
  Map<String, dynamic> toInitial() {
    return {
      'total_index': 0,
    };
  }


  factory MainIndexModel.initial(){
    return MainIndexModel.fromJson({
      'total_index': 0,
    });
  }
}

/// Model representing the path structure for different types of data containers
/// Each container can have multiple specialized directories for different purposes
class ContainerPaths {
  /// Path to active data storage
  /// Contains currently accessible and modifiable data
  final String? active;

  /// Path to backup storage location
  /// Used for data redundancy and recovery purposes
  final String? backup;

  // Commented paths for future implementation:
  //final String? deleted;    // For soft-deleted data
  //final String? sealed;     // For immutable/archived data
  //final String? historical; // For long-term data retention
  //final String? sync;       // For synchronization purposes

  /// Creates a new container paths instance with specified directory locations
  ContainerPaths({
    this.active,
    this.backup,
  });

  /// Creates an instance from a JSON map
  /// Used when loading container configurations
  factory ContainerPaths.fromJson(Map json) {
    return ContainerPaths(
      active: json['active'] as String?,
      backup: json['backup'] as String?,
    );
  }

  /// Converts the path configuration to a JSON map
  /// Includes all defined paths, even if null
  Map toJson() => {
        'active': active,
        'backup': backup,
      };
}
