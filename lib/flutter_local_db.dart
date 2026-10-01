/// flutter_local_db: the db_dsl query language on the offline_first_core
/// engine (Rust + LMDB 1.0) for Android, iOS, macOS, Linux and Windows, plus
/// the key-value [LocalDB] API (also on the web, over IndexedDB).
///
/// Everything of db_dsl is exported: tables, columns, expressions, queries,
/// transactions, `Result` with `Ok` and `Err`, and [DbError].
library;

export 'package:db_dsl/db_dsl.dart';

export 'src/local_db.dart';
export 'src/models/local_db_error.dart';
export 'src/models/local_db_model.dart';
export 'src/utils/local_db_export.dart';
export 'src/utils/path_helper.dart';
