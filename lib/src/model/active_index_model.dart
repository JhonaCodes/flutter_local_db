
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
        (json['blocks'] ?? {})
            .map((key, value) => MapEntry(key, BlockData.fromJson(value))),
      ),
      records: Map<String, RecordLocation>.from(
        (json['records'] ?? {})
            .map((key, value) => MapEntry(key, RecordLocation.fromJson(value))),
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
            totalLines: 2000,
            usedLines: 0,
            freeSpaces: 0,
          ).toJson(),
        },
        'records': {},
      };
}

class BlockData {
  final int totalLines;
  final int usedLines;
  final int freeSpaces;

  BlockData({
    required this.totalLines,
    required this.usedLines,
    required this.freeSpaces,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      totalLines: json['total_lines'] as int,
      usedLines: json['used_lines'] as int,
      freeSpaces: json['free_spaces'],
    );
  }

  Map<String, dynamic> toJson() => {
        'total_lines': totalLines,
        'used_lines': usedLines,
        'free_spaces': freeSpaces,
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
