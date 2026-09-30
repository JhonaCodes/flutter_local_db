import 'dart:io';

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native.dart';

void main() {
  late Directory directory;

  setUp(() async => directory = await TestHost.temporaryDirectory('legacy'));
  tearDown(() => directory.delete(recursive: true));

  Future<LocalDbService> open(String name) async {
    final service = await LocalDbService.initializeWithPath(
      '${directory.path}/$name',
    );
    return service.okOrNull!;
  }

  test('the key-value API works on the new engine', () async {
    final db = await open('kv');

    expect(
      (await db.store('user-1', LocalMethod.post, {'name': 'Ada'})).isOk,
      isTrue,
    );
    expect(
      (await db.store('user-1', LocalMethod.put, {'name': 'Grace'})).isOk,
      isTrue,
    );
    final stored = await db.retrieve('user-1');
    expect(stored.okOrNull!.data, {'name': 'Grace'});
    final missing = await db.retrieve('nope');
    expect(missing.errOrNull!.type, LocalDbErrorType.notFound);
    await db.store('user-2', LocalMethod.post, {'name': 'Linus'});
    expect(
      (await db.listAll()).okOrNull!.keys,
      unorderedEquals(['user-1', 'user-2']),
    );
    expect((await db.remove('user-1')).isOk, isTrue);
    expect((await db.clearAll()).isOk, isTrue);
    expect((await db.listAll()).okOrNull, isEmpty);
    db.close();
  });

  test('records exported by 1.6 are imported by 2.0', () async {
    final db = await open('import');
    final export = LocalDbExport.encode([
      LocalDbModel(id: 'a', data: {'n': 1}),
      LocalDbModel(
        id: 'b',
        data: {
          'nested': {'x': true},
        },
      ),
    ]);
    final records = LocalDbExport.decode(export).okOrNull!;
    for (final record in records) {
      await db.store(record.id, LocalMethod.put, record.data);
    }
    expect((await db.retrieve('b')).okOrNull!.data, {
      'nested': {'x': true},
    });
    db.close();
  });

  test(
    'a 1.x database is reported as legacyFormat and left untouched',
    () async {
      final source = Directory('test/fixtures/lmdb_0_9/compat.lmdb');
      final target = Directory('${directory.path}/old.lmdb')..createSync();
      for (final file in ['data.mdb', 'lock.mdb']) {
        File('${source.path}/$file').copySync('${target.path}/$file');
      }
      final before = File('${target.path}/data.mdb').readAsBytesSync();

      final legacy = await LocalDbService.initializeWithPath(
        '${directory.path}/old',
      );
      expect(legacy.errOrNull!.type, LocalDbErrorType.legacyFormat);

      await expectLater(
        LocalDatabase.open(path: '${directory.path}/old'),
        throwsA(
          isA<LocalDbException>().having(
            (e) => e.code,
            'code',
            LocalDbErrorCode.legacyFormat,
          ),
        ),
      );
      expect(File('${target.path}/data.mdb').readAsBytesSync(), before);
    },
  );
}
