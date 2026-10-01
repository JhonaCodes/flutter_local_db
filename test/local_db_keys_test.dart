import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_local_db/src/core/local_db_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one key rule of the native and the web stores. Pure Dart, so it also
/// runs in a browser: `flutter test --platform chrome test/local_db_keys_test.dart`.
void main() {
  LocalDbErrorType? rejection(String key) => LocalDbKeys.validate(
    key,
  ).when(ok: (_) => null, err: (error) => error.type);

  test('a key of 1 to 511 bytes of UTF-8 is accepted', () {
    expect(rejection('a'), isNull);
    expect(rejection('x' * 511), isNull);
    expect(rejection('€' * 170), isNull, reason: '510 bytes');
  });

  test('an empty key is rejected', () {
    expect(rejection(''), LocalDbErrorType.validation);
  });

  test('the limit counts bytes of UTF-8, not characters', () {
    expect(rejection('x' * 512), LocalDbErrorType.validation);
    // 171 characters, 513 bytes: the web counted 171 and accepted it.
    expect(rejection('€' * 171), LocalDbErrorType.validation);
  });

  test('a NUL character is rejected', () {
    expect(rejection('a\u0000b'), LocalDbErrorType.validation);
    expect(rejection('\u0000'), LocalDbErrorType.validation);
  });
}
