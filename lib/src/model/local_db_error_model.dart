/// A model class that represents errors that can occur during database operations.
/// This class provides a structured way to handle and serialize error information.
class LocalDbErrorModel {
  /// The main title or category of the error
  final String title;

  /// Optional detailed message about the error
  /// Can be null if no additional details are available
  final String? message;

  /// The actual Error object that was caught
  /// Contains the error type and basic error information
  final Error err;

  /// Optional stack trace of where the error occurred
  /// Can be null if stack trace capture was disabled or unavailable
  final StackTrace? stackTrace;

  /// Creates a new [LocalDbErrorModel] instance.
  ///
  /// [title] and [err] are required parameters.
  /// [message] and [stackTrace] are optional and can be null.
  LocalDbErrorModel({
    required this.title,
    this.message,
    required this.err,
    this.stackTrace,
  });

  /// Converts the error model to a JSON map.
  ///
  /// Useful for serialization and logging purposes.
  /// All fields, including nullables, are included in the resulting map.
  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'err': err,
        'stackTrace': stackTrace
      };

  /// Creates a [LocalDbErrorModel] instance from a JSON map.
  ///
  /// Used for deserializing error data, typically from logs or stored error records.
  factory LocalDbErrorModel.fromJson(Map<String, dynamic> json) =>
      LocalDbErrorModel(
          title: json['title'],
          message: json['message'],
          err: json['err'],
          stackTrace: json['stackTrace']);

  /// Provides a string representation of the error model.
  ///
  /// Useful for debugging and logging purposes.
  @override
  String toString() {
    return 'LocalDbErrorModel{title: $title, message: $message, err: $err, stackTrace: $stackTrace}';
  }

  /// Creates a copy of this error model with optional field updates.
  ///
  /// Fields that are not specified will retain their original values.
  /// Useful for modifying error information while maintaining immutability.
  LocalDbErrorModel copyWith({
    String? title,
    String? message,
    Error? err,
    StackTrace? stackTrace,
  }) {
    return LocalDbErrorModel(
      title: title ?? this.title,
      message: message ?? this.message,
      err: err ?? this.err,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}
