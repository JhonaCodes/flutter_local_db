import 'dart:async';
import 'dart:convert';

import '../core/log.dart';
import '../model/local_db_error_model.dart';
import '../model/local_db_request_model.dart';
import 'package:result_controller/result_controller.dart';
import 'database_interface.dart';

/// Mock database implementation for testing purposes.
///
/// This implementation stores data in memory and provides the same interface
/// as the real database implementations, but without any external dependencies.
/// Perfect for unit testing and rapid development.
///
/// Features:
/// - 100% Pure Dart - no FFI or browser dependencies
/// - In-memory storage with persistence simulation
/// - Configurable delays to simulate real database operations
/// - Error simulation for testing error handling
/// - Data validation and sanitization
/// - Thread-safe operations
class DatabaseMock implements DatabaseInterface {

  // In-memory storage
  final Map<String, LocalDbModel> _storage = {};
  String? _databaseName;
  bool _isInitialized = false;

  // Configuration for testing scenarios
  Duration _operationDelay = Duration.zero;
  bool _shouldSimulateErrors = false;
  double _errorRate = 0.0; // 0.0 to 1.0
  String? _forcedErrorMessage;

  // Statistics for testing
  int _operationCount = 0;
  int _errorCount = 0;

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'mock';

  @override
  String? get currentDatabaseName => _databaseName;

  /// Get current storage size
  int get storageSize => _storage.length;

  /// Get operation statistics
  Map<String, int> get statistics => {
    'operations': _operationCount,
    'errors': _errorCount,
    'records': _storage.length,
  };

  /// Configure mock behavior for testing
  void configureMock({
    Duration? operationDelay,
    bool? shouldSimulateErrors,
    double? errorRate,
    String? forcedErrorMessage,
  }) {
    _operationDelay = operationDelay ?? Duration.zero;
    _shouldSimulateErrors = shouldSimulateErrors ?? false;
    _errorRate = errorRate ?? 0.0;
    _forcedErrorMessage = forcedErrorMessage;
  }

  /// Reset mock to clean state
  void resetMock() {
    _storage.clear();
    _databaseName = null;
    _isInitialized = false;
    _operationCount = 0;
    _errorCount = 0;
    configureMock(); // Reset configuration
  }

  /// Simulate database corruption or failure
  void simulateFailure(String errorMessage) {
    _forcedErrorMessage = errorMessage;
    _shouldSimulateErrors = true;
    _errorRate = 1.0;
  }

  @override
  Future<void> initialize(String databaseName) async {
    Log.i('Initializing mock database: $databaseName');

    await _simulateDelay();

    if (_shouldSimulateError()) {
      throw Exception(_forcedErrorMessage ?? 'Mock initialization error');
    }

    _databaseName = databaseName;
    _isInitialized = true;

    Log.i('Mock database initialized successfully');
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> post(
    LocalDbModel model,
  ) async {
    Log.d('Mock POST operation for ID: ${model.id}');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock POST error');
    }

    // Validate ID format
    if (!_isValidId(model.id)) {
      _errorCount++;
      return _createError('Invalid ID format: ${model.id}');
    }

    // Check if ID already exists
    if (_storage.containsKey(model.id)) {
      _errorCount++;
      return _createError('Record with ID ${model.id} already exists');
    }

    // Validate data can be serialized
    if (!_isValidJson(model.data)) {
      _errorCount++;
      return _createError('Invalid JSON data');
    }

    // Generate hash for the stored model
    final hash = _generateHash(model.data);
    final storedModel = model.copyWith(hash: hash);

    _storage[model.id] = storedModel;

    Log.d('Mock POST successful for ID: ${model.id}');
    return Ok(storedModel);
  }

  @override
  Future<Result<LocalDbModel?, ErrorLocalDb>> getById(String id) async {
    Log.d('Mock GET operation for ID: $id');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock GET error');
    }

    if (!_isValidId(id)) {
      _errorCount++;
      return _createError('Invalid ID format: $id');
    }

    final model = _storage[id];

    if (model == null) {
      // Return Ok(null) when record not found, not an error
      Log.d('Mock GET: Record not found for ID: $id');
      return Ok(null);
    }

    Log.d('Mock GET successful for ID: $id');
    return Ok(model);
  }

  @override
  Future<Result<List<LocalDbModel>, ErrorLocalDb>> getAll() async {
    Log.d('Mock GET ALL operation');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock GET ALL error');
    }

    final allModels = _storage.values.toList();

    Log.d('Mock GET ALL successful: ${allModels.length} records');
    return Ok(allModels);
  }

  @override
  Future<Result<LocalDbModel, ErrorLocalDb>> put(
    LocalDbModel model,
  ) async {
    Log.d('Mock PUT operation for ID: ${model.id}');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock PUT error');
    }

    if (!_isValidId(model.id)) {
      _errorCount++;
      return _createError('Invalid ID format: ${model.id}');
    }

    // Check if record exists
    if (!_storage.containsKey(model.id)) {
      _errorCount++;
      return _createError('Record with ID ${model.id} not found');
    }

    if (!_isValidJson(model.data)) {
      _errorCount++;
      return _createError('Invalid JSON data');
    }

    // Generate new hash for updated data
    final hash = _generateHash(model.data);
    final updatedModel = model.copyWith(hash: hash);

    _storage[model.id] = updatedModel;

    Log.d('Mock PUT successful for ID: ${model.id}');
    return Ok(updatedModel);
  }

  @override
  Future<Result<bool, ErrorLocalDb>> delete(String id) async {
    Log.d('Mock DELETE operation for ID: $id');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock DELETE error');
    }

    if (!_isValidId(id)) {
      _errorCount++;
      return _createError('Invalid ID format: $id');
    }

    final existed = _storage.remove(id) != null;

    if (!existed) {
      _errorCount++;
      return _createError('Record with ID $id not found');
    }

    Log.d('Mock DELETE successful for ID: $id');
    return Ok(true);
  }

  @override
  Future<Result<bool, ErrorLocalDb>> cleanDatabase() async {
    Log.d('Mock CLEAN DATABASE operation');

    await _simulateDelay();
    _operationCount++;

    if (!_isInitialized) {
      return _createError('Database not initialized');
    }

    if (_shouldSimulateError()) {
      _errorCount++;
      return _createError(_forcedErrorMessage ?? 'Mock CLEAN error');
    }

    final recordCount = _storage.length;
    _storage.clear();

    Log.d('Mock CLEAN DATABASE successful: removed $recordCount records');
    return Ok(true);
  }

  @override
  Future<void> closeDatabase() async {
    Log.d('Mock CLOSE DATABASE operation');

    await _simulateDelay();

    _isInitialized = false;
    // Don't clear storage to simulate persistence

    Log.d('Mock database closed');
  }

  @override
  Future<bool> ensureConnectionValid() async {
    await _simulateDelay();

    if (_shouldSimulateError()) {
      return false;
    }

    return _isInitialized;
  }

  // Helper methods

  bool _isValidId(String id) {
    return RegExp(r'^[a-zA-Z0-9_-]{3,}$').hasMatch(id);
  }

  bool _isValidJson(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _generateHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    // Simple hash generation for mock purposes
    return 'mock_hash_${jsonString.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _shouldSimulateError() {
    if (!_shouldSimulateErrors) return false;
    if (_errorRate >= 1.0) return true;
    if (_errorRate <= 0.0) return false;

    // Simple random error generation based on error rate
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    return random < (_errorRate * 100);
  }

  Result<T, ErrorLocalDb> _createError<T>(String message) {
    Log.e('Mock database error: $message');

    final error = ErrorLocalDb(
      type: ErrorType.databaseError,
      detailsResult: DetailsModel('MockError', message),
    );

    return Err(error);
  }

  Future<void> _simulateDelay() async {
    if (_operationDelay > Duration.zero) {
      await Future.delayed(_operationDelay);
    }
  }

  // Additional helper methods for testing

  /// Get all stored records (for testing inspection)
  Map<String, LocalDbModel> getAllRecords() {
    return Map.unmodifiable(_storage);
  }

  /// Check if a specific ID exists
  bool hasRecord(String id) {
    return _storage.containsKey(id);
  }

  /// Get record count
  int getRecordCount() {
    return _storage.length;
  }

  /// Manually insert record (for test setup)
  void insertRecordForTesting(LocalDbModel model) {
    _storage[model.id] = model;
  }

  /// Export data as JSON (for testing persistence simulation)
  Map<String, dynamic> exportData() {
    return {
      'database_name': _databaseName,
      'is_initialized': _isInitialized,
      'records': _storage.map((key, value) => MapEntry(key, value.toJson())),
      'statistics': statistics,
    };
  }

  /// Import data from JSON (for testing persistence simulation)
  void importData(Map<String, dynamic> data) {
    _databaseName = data['database_name'];
    _isInitialized = data['is_initialized'] ?? false;

    final records = data['records'] as Map<String, dynamic>? ?? {};
    _storage.clear();

    for (final entry in records.entries) {
      final model = LocalDbModel.fromJson(entry.value);
      _storage[entry.key] = model;
    }

    final stats = data['statistics'] as Map<String, dynamic>? ?? {};
    _operationCount = stats['operations'] ?? 0;
    _errorCount = stats['errors'] ?? 0;
  }
}
