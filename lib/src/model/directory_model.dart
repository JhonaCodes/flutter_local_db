class DirectoryModel {
  final String id;
  final Map data;

  DirectoryModel({required this.id, required this.data});

  toJson() {
    return {'id': this.id, 'data': this.data};
  }

  factory DirectoryModel.fromJson(Map json) {
    return DirectoryModel(
      id: json['id'],
      data: json['data'],
    );
  }
}
