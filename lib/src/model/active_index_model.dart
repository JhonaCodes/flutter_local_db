/// Model that manages data within the 'active' folder structure, which contains
/// the index and stored information blocks. This is the core model where all
/// data is maintained and organized.
class ActiveIndexModel {
  /// Stores block information where each key is a block file name (e.g., 'act_001.dex')
  /// and value contains metadata about the block's capacity and usage
  final Map<String, BlockData> blocks;

  /// Maps record identifiers to their physical location within blocks
  /// Enables quick lookup of where specific records are stored
  final Map<String, RecordLocation> records;

  /// Creates a new instance with required block and record mappings
  ActiveIndexModel({
    required this.blocks,
    required this.records,
  });

  /// Creates an instance from a JSON map, typically used when loading
  /// from stored index files
  ///
  /// The JSON structure should contain 'blocks' and 'records' objects
  factory ActiveIndexModel.fromJson(Map<String, dynamic> json) {
    return ActiveIndexModel(
      blocks: Map<String, BlockData>.from(
        (json['blocks'] ?? {})
            .map((key, value) => MapEntry(key, BlockData.fromJson(value))),
      ),
      records: Map<String, RecordLocation>.from(
        (json['records'] ?? {})
            .map((key, value) => MapEntry(key, RecordLocation.fromJson(value))),
      ),
    );
  }

  /// Converts the current state to a JSON map for persistence
  /// This includes all block information and record locations
  Map<String, dynamic> toJson() => {
    'blocks': blocks.map((key, value) => MapEntry(key, value.toJson())),
    'records': records.map((key, value) => MapEntry(key, value.toJson())),
  };

  /// Creates an initial empty index structure with a single block
  /// Used when initializing a new database instance
  ///
  /// Returns a JSON map with:
  /// - One initial block ('act_001.dex') with 2000 lines capacity
  /// - Empty records map
  static Map<String, dynamic> toInitial() => {
    'blocks': {
      'act_001.dex': BlockData(
        totalLines: 2000,
        usedLines: 0,
        freeSpaces: 0,
      ).toJson(),
    },
    'records': {},
  };
}

/// Contains metadata and statistics for each data block file within the 'active' folder.
/// This class tracks the capacity and usage of individual block files to manage
/// storage efficiency and data distribution.
class BlockData {
  /// Total number of lines available in the block file
  /// Represents the maximum capacity of records this block can store
  final int totalLines;

  /// Number of lines currently in use within the block
  /// Helps track block utilization and determines when new blocks are needed
  final int usedLines;

  /// Count of available spaces from deleted records
  /// These spaces can be reused for new records before creating new lines
  final int freeSpaces;

  /// Creates a new BlockData instance with specified capacity and usage metrics
  BlockData({
    required this.totalLines,
    required this.usedLines,
    required this.freeSpaces,
  });

  /// Creates a BlockData instance from a JSON map
  /// Used when loading block information from stored index files
  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      totalLines: json['total_lines'] as int,
      usedLines: json['used_lines'] as int,
      freeSpaces: json['free_spaces'],
    );
  }

  /// Converts the block statistics to a JSON map for storage
  /// Keys follow snake_case convention for consistency
  Map<String, dynamic> toJson() => {
    'total_lines': totalLines,
    'used_lines': usedLines,
    'free_spaces': freeSpaces,
  };
}

/// Stores the location information for each record within the database system.
/// This class acts as a pointer to find where specific records are stored
/// in the block files and tracks their modification history.
class RecordLocation {
  /// Name of the block file where the record is stored
  /// Example: 'act_001.dex'
  final String block;

  /// Timestamp of the last modification to this record
  /// Format typically follows a standardized datetime string
  final String lastUpdate;

  /// Creates a new RecordLocation with specified block and timestamp
  RecordLocation({
    required this.block,
    required this.lastUpdate,
  });

  /// Creates a RecordLocation instance from a JSON map
  /// Used when loading record locations from the index
  factory RecordLocation.fromJson(Map<String, dynamic> json) {
    return RecordLocation(
      block: json['block'] as String,
      lastUpdate: json['last_update'] as String,
    );
  }

  /// Converts the location information to a JSON map
  /// Keys follow snake_case convention for consistency with other models
  Map<String, dynamic> toJson() => {
    'block': block,
    'last_update': lastUpdate,
  };
}
