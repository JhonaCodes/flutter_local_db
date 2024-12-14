class DataLocalDBModel {
  final String id;
  final double sizeKb;
  final int hash;
  final Map<dynamic, dynamic> data;

  DataLocalDBModel({required this.id, required this.sizeKb, required this.hash, required this.data});


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': sizeKb,
      'hash': hash,
      'data': data,
    };
  }


  factory DataLocalDBModel.fromJson(Map<String, dynamic> json) {
    return DataLocalDBModel(
      id: json['id'] as String,
      sizeKb: (json['size'] as num).toDouble(),
      hash: json['hash'] as int,
      data: json['data'] as Map<String, dynamic>,
    );
  }


  DataLocalDBModel copyWith({
    String? id,
    double? size,
    int? hash,
    Map<String, dynamic>? data,
  }) {
    return DataLocalDBModel(
      id: id ?? this.id,
      sizeKb: size ?? this.sizeKb,
      hash: hash ?? this.hash,
      data: data ?? this.data,
    );
  }

}
