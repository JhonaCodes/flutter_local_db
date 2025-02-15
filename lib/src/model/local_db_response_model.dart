class LocalDbResponseModel {
  final String id; // usado apra llamar y guardar datos
  final String hash; // usado por rust para identificar si los datos actuales son los mismos
  final String lastUpdate;
  final Map<String, dynamic> data;

  LocalDbResponseModel({
    required this.id,
    required this.hash,
    required this.data,
    required this.lastUpdate
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'hash': hash,
    'data': data,
    'last_update': lastUpdate
  };

  factory LocalDbResponseModel.fromJson(Map<String, dynamic> json) => LocalDbResponseModel(
    id: json['id'],
    hash: json['hash'],
    data: json['data'],
    lastUpdate: json['last_update']
  );

  @override
  String toString() {
    return 'LocalDbModel{id: $id, hash: $hash, data: $data, last_update: $lastUpdate}';
  }

  LocalDbResponseModel copyWith({String? id, String? hash, Map<String, dynamic>? data, String? lastUpdate}) => LocalDbResponseModel(
    id: id ?? this.id,
    hash: hash ?? this.hash,
    data: data ?? this.data,
    lastUpdate: lastUpdate ?? this.lastUpdate
  );
}