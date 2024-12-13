class DataModel {
  final String id;
  final double size;
  final int hash;
  final Map<String, dynamic> data;

  DataModel(this.id, this.size, this.hash, this.data);

  // Convert an instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': size,
      'hash': hash,
      'data': data,
    };
  }

  // Create an instance from a JSON map
  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      json['id'] as String,
      (json['size'] as num).toDouble(),
      json['hash'] as int,
      json['data'] as Map<String, dynamic>,
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
      id ?? this.id,
      size ?? this.size,
      hash ?? this.hash,
      data ?? this.data,
    );
  }
}