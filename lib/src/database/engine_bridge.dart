/// Transport between [LocalDatabase] and the native engine.
abstract interface class EngineBridge {
  /// Sends one wire-protocol request and returns its `ok` payload; throws a
  /// [LocalDbException] for an error response.
  Future<Map<String, Object?>> request(Map<String, Object?> request);

  /// Releases the database handle.
  Future<void> close();
}
