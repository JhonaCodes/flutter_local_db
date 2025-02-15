import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';
import 'package:flutter_local_db/src/service/local_db_result.dart';

@protected
abstract class LocalSbRequestImpl {
  /// Is future because i will update rust to async
  Future<LocalDbResult<LocalDbRequestModel, String>> post(
      LocalDbRequestModel model);
  Future<LocalDbResult<LocalDbRequestModel, String>> put(
      LocalDbRequestModel model);
  Future<LocalDbResult<List<LocalDbRequestModel>, String>> getAll();
  Future<LocalDbResult<LocalDbRequestModel?, String>> getById(String id);
  Future<LocalDbResult<bool, String>> delete(String id);
  // Future<bool> cleanDatabase(LocalDbRequestModel model);
}
