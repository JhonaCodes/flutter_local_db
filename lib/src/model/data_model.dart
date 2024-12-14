class DataModel {
  final String id;
  final double sizeKb;
  final int hash;
  final Map<dynamic, dynamic> data;

  DataModel({required this.id, required this.sizeKb, required this.hash, required this.data});

  // Convert an instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': sizeKb,
      'hash': hash,
      'data': data,
    };
  }

  // Create an instance from a JSON map
  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      id: json['id'] as String,
      sizeKb: (json['size'] as num).toDouble(),
      hash: json['hash'] as int,
      data: json['data'] as Map<String, dynamic>,
    );
  }

  // Create a copy of an instance with optional new values
  DataModel copyWith({
    String? id,
    double? size,
    int? hash,
    Map<String, dynamic>? data,
  }) {
    return DataModel(
      id: id ?? this.id,
      sizeKb: size ?? this.sizeKb,
      hash: hash ?? this.hash,
      data: data ?? this.data,
    );
  }
}
