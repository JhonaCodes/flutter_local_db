class LocalDbErrorModel {
  final String title;
  final String? message;
  final Error err;
  final StackTrace? stackTrace;

  LocalDbErrorModel({required this.title, this.message, required this.err, this.stackTrace});

  Map<String, dynamic> toJson() => {'title': title, 'message': message, 'err': err, 'stackTrace': stackTrace};

  factory LocalDbErrorModel.fromJson(Map<String, dynamic> json) =>
      LocalDbErrorModel(title: json['title'], message: json['message'], err: json['err'], stackTrace: json['stackTrace']);

  @override
  String toString() {
    return 'LocalDbErrorModel{title: $title, message: $message, err: $err, stackTrace: $stackTrace}';
  }

  LocalDbErrorModel copyWith({String? title, String? message, Error? err, StackTrace? stackTrace}) {
    return LocalDbErrorModel(
      title: title ?? this.title,
      message: message ?? this.message,
      err: err ?? this.err,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }



}
