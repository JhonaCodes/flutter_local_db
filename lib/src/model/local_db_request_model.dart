/// Hash is frm rust and las update is from dart fucntion internal.
class LocalDbRequestModel{
  final String id;
  final String? lastUpdate; /// Optional en el constructor por si el suuario decide poner por defecto uan fecha, de lo contrario la fucnion pone la actual o por si viene del servidor
  final Map<String, dynamic> data; /// en general los datos son un  map asi sea solo un registro de un dato, este sera un map y asi evito la pelea de tiposd e datos.

  LocalDbRequestModel({required this.id, this.lastUpdate, required this.data});


  Map<String, dynamic> toJson() => {
    'id': id,
    'last_update': lastUpdate,
    'data': data
  };

  factory LocalDbRequestModel.fromJson(Map<String, dynamic> json) => LocalDbRequestModel(
    id: json['id'],
    lastUpdate: json['last_update'],
    data: json['data']
  );


  @override
  String toString() {
    return 'LocalDbModel{id: $id, last_update: $lastUpdate, data: $data}';
  }


  LocalDbRequestModel copyWith({String? id, String? lastUpdate, Map<String, dynamic>? data}){
    return LocalDbRequestModel(
      id: id ?? this.id,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      data: data ?? this.data
    );
  }

}

