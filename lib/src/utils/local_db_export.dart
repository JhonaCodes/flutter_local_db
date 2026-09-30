import 'dart:convert';

import '../models/local_db_error.dart';
import '../models/local_db_model.dart';
import '../models/local_db_result.dart';

/// Portable export of the records stored through [LocalDB].
///
/// flutter_local_db 2.0 stores data with LMDB 1.0, which cannot read the
/// LMDB 0.9 files written by 1.x. To keep the data of an app across the
/// upgrade, a 1.x version of the app calls `LocalDB.exportAll()` and saves the
/// resulting JSON (for example to a file); after the upgrade, 2.0 imports it
/// with `LocalDB.importAll(json)`.
///
/// ```json
/// {"format": "flutter_local_db.export", "version": 1,
///  "records": [{"id": "user-1", "hash": "…", "data": {"name": "Ada"}}]}
/// ```
abstract final class LocalDbExport {
  /// Identifies an export document.
  static const String format = 'flutter_local_db.export';

  /// Version of the export document.
  static const int version = 1;

  /// Encodes [records] as an export document.
  static String encode(List<LocalDbModel> records) {
    return jsonEncode({
      'format': format,
      'version': version,
      'records': [
        for (final record in records)
          {'id': record.id, 'hash': record.contentHash, 'data': record.data},
      ],
    });
  }

  /// Decodes an export document written by [encode].
  static LocalDbResult<List<LocalDbModel>, ErrorLocalDb> decode(String json) {
    try {
      final document = jsonDecode(json);
      if (document is! Map<String, dynamic> ||
          document['format'] != format ||
          document['version'] != version ||
          document['records'] is! List) {
        return Err(
          ErrorLocalDb.validationError(
            'Not a $format document of version $version',
          ),
        );
      }
      final records = <LocalDbModel>[];
      for (final entry in document['records'] as List) {
        if (entry is! Map<String, dynamic> ||
            entry['id'] is! String ||
            entry['data'] is! Map<String, dynamic>) {
          return Err(ErrorLocalDb.validationError('Invalid record: $entry'));
        }
        records.add(
          LocalDbModel(
            id: entry['id'] as String,
            data: entry['data'] as Map<String, dynamic>,
            contentHash: entry['hash'] as String?,
          ),
        );
      }
      return Ok(records);
    } on FormatException catch (e) {
      return Err(
        ErrorLocalDb.serializationError('Export is not JSON', cause: e),
      );
    }
  }
}
