class UserModel {
  final String id;
  final String name;
  final int age;

  UserModel({
    required this.id,
    required this.name,
    required this.age,
  });

  /// Converts the model to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
    };
  }

  /// Creates a model instance from a JSON-compatible map.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      age: json['age'],
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    int? age,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
    );
  }


}