// Modelo para el índice interno de active
class ActiveIndexModel {
  final Map<String, BlockData> blocks;
  final Map<String, RecordLocation> records;

  ActiveIndexModel({
    required this.blocks,
    required this.records,
  });

  factory ActiveIndexModel.fromJson(Map<String, dynamic> json) {
    return ActiveIndexModel(
      blocks: Map<String, BlockData>.from(
        (json['blocks'] ?? {}).map((key, value) =>
            MapEntry(key, BlockData.fromJson(value))
        ),
      ),
      records: Map<String, RecordLocation>.from(
        (json['records'] ?? {}).map((key, value) =>
            MapEntry(key, RecordLocation.fromJson(value))
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'blocks': blocks.map((key, value) => MapEntry(key, value.toJson())),
    'records': records.map((key, value) => MapEntry(key, value.toJson())),
  };

  static Map<String, dynamic> toInitial() => {
    'blocks': {
      'act_001.dex': BlockData(
        totalLines: 20000,
        usedLines: 0,
        freeSpaces: [],
        fragmentation: 0.0,
      ).toJson(),
    },
    'records': {},
  };
}

class BlockData {
  final int totalLines;
  final int usedLines;
  final List<int> freeSpaces;
  final double fragmentation;

  BlockData({
    required this.totalLines,
    required this.usedLines,
    required this.freeSpaces,
    required this.fragmentation,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      totalLines: json['total_lines'] as int,
      usedLines: json['used_lines'] as int,
      freeSpaces: List<int>.from(json['free_spaces'] ?? []),
      fragmentation: (json['fragmentation'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_lines': totalLines,
    'used_lines': usedLines,
    'free_spaces': freeSpaces,
    'fragmentation': fragmentation,
  };
}

class RecordLocation {
  final String block;
  final String lastUpdate;

  RecordLocation({
    required this.block,
    required this.lastUpdate,
  });

  factory RecordLocation.fromJson(Map<String, dynamic> json) {
    return RecordLocation(
      block: json['block'] as String,
      lastUpdate: json['last_update'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'block': block,
    'last_update': lastUpdate,
  };
}