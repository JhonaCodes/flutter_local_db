// Main folder mapping class
class MainIndexModel {
  final int totalIndex;
  final Map<String, ContainerPaths> containers;

  MainIndexModel({
    required this.totalIndex,
    required this.containers,
  });

  factory MainIndexModel.fromJson(Map<String, dynamic> json) {
    // Create a map of containers, excluding the 'total_index' field
    final containersMap = Map<String, ContainerPaths>.fromEntries(
      json.entries.where((e) => e.key != 'total_index').map((e) => MapEntry(e.key, ContainerPaths.fromJson(e.value as Map<String, dynamic>),),
      ),
    );

    return MainIndexModel(
      totalIndex: json['total_index'] ?? 0,
      containers: containersMap,
    );
  }

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

  static Map<String, dynamic> toInitial() {
    return {
      'total_index': 0,
    };
  }
}


// Container paths model
class ContainerPaths {
  final String? active;
  final String? deleted;
  final String? sealed;
  final String? backup;
  final String? historical;
  final String? sync;

  ContainerPaths({
    this.active,
    this.deleted,
    this.sealed,
    this.backup,
    this.historical,
    this.sync,
  });

  factory ContainerPaths.fromJson(Map json) {
    return ContainerPaths(
      active: json['active'] as String?,
      deleted: json['deleted'] as String?,
      sealed: json['sealed'] as String?,
      backup: json['backup'] as String?,
      historical: json['historical'] as String?,
      sync: json['sync'] as String?,
    );
  }

  Map toJson() => {
    'active': active,
    'deleted': deleted,
    'sealed': sealed,
    'backup': backup,
    'historical': historical,
    'sync': sync,
  };
}

