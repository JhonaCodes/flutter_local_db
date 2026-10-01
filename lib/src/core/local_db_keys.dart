/// The rule every record key follows, on every platform.
library;

import 'dart:convert';

import 'package:result_controller/result_controller.dart';

import '../models/local_db_error.dart';

/// What makes a record key valid: 1 to [maxBytes] bytes of UTF-8, without a
/// NUL character.
///
/// Why one place: the native and the web stores must accept exactly the
/// same keys, so a record written on one platform can be written on the
/// other. [maxBytes] is the key limit of the native engine on every device.
/// A NUL is refused because the native lookups take the key as a C string,
/// which ends at the first NUL: `GetById('a\u0000b')` would read the record
/// `a`, and `Delete` would delete it.
abstract final class LocalDbKeys {
  /// The longest key, in bytes of UTF-8.
  static const int maxBytes = 511;

  /// `Ok` when [key] is a valid record key, otherwise a
  /// [LocalDbErrorType.validation] error saying why.
  static Result<void, ErrorLocalDb> validate(String key) => switch ((
    key.isEmpty,
    utf8.encode(key).length > maxBytes,
    key.contains('\u0000'),
  )) {
    (true, _, _) => Err(
      ErrorLocalDb.validationError('A key cannot be empty', context: key),
    ),
    (_, true, _) => Err(
      ErrorLocalDb.validationError(
        'A key is at most $maxBytes bytes of UTF-8',
        context: key,
      ),
    ),
    (_, _, true) => Err(
      ErrorLocalDb.validationError(
        'A key cannot contain a NUL character',
        context: key,
      ),
    ),
    _ => Ok(null),
  };
}
