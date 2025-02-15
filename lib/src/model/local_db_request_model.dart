/// Hash is frm rust and las update is from dart fucntion internal.
class LocalDbRequestModel{
  final String id;
  final String? hash;
  final Map<String, dynamic> data;

  LocalDbRequestModel({
    required this.id,
    this.hash,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'hash': "${DateTime.now().millisecondsSinceEpoch}",
    'data': data,
  };

  factory LocalDbRequestModel.fromJson(Map<String, dynamic> json) => LocalDbRequestModel(
    id: json['id'],
    hash: json['hash'],
    data: json['data'],
  );

  @override
  String toString() {
    return 'LocalDbModel{id: $id, hash: $hash, data: $data}';
  }

  LocalDbRequestModel copyWith({String? id, String? hash, Map<String, dynamic>? data}) => LocalDbRequestModel(
    id: id ?? this.id,
    hash: hash ?? this.hash,
    data: data ?? this.data,
  );

}

