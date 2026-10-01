import 'dart:io';

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native.dart';

/// `LocalDB`, the one entry point, on the native engine: records as in 1.x,
/// tables whose queries run when awaited, transactions, another database
/// named explicitly, and the files of 1.x.
void main() {
  late Directory directory;
  late DbTable<User> users;

  setUp(() async {
    directory = await TestHost.temporaryDirectory('local_db');
    users = DbTable<User>(
      'users',
      key: 'id',
      fromJson: User.fromJson,
      indexes: [
        Index(['city', 'age']),
      ],
    );
  });

  tearDown(() async {
    await LocalDB.close();
    await directory.delete(recursive: true);
  });

  String at(String name) => '${directory.path}/$name';

  group('records', () {
    test('work without tables, as in 1.x', () async {
      value(await LocalDB.init(path: at('app')));

      expect(value(await LocalDB.Post('user-1', {'name': 'Ada'})).id, 'user-1');
      value(await LocalDB.Put('user-1', {'name': 'Grace'}));
      expect(value(await LocalDB.GetById('user-1'))?.data, {'name': 'Grace'});
      expect(value(await LocalDB.GetById('nope')), isNull);
      value(await LocalDB.Post('user-2', {'name': 'Linus'}));
      expect(
        value(await LocalDB.GetAll()).map((record) => record.id),
        unorderedEquals(['user-1', 'user-2']),
      );
      expect(value(await LocalDB.Delete('user-1')), isTrue);
      expect(value(await LocalDB.ClearData()), isTrue);
      expect(value(await LocalDB.GetAll()), isEmpty);
    });

    test('a key with a NUL byte is rejected, never truncated', () async {
      value(await LocalDB.init(path: at('app')));
      const key = 'a\u0000b';

      // The native lookups take the key as a C string, which ends at the
      // first NUL: `a\u0000b` would silently read and delete `a`.
      expect(
        errorType(await LocalDB.Post(key, {'n': 1})),
        LocalDbErrorType.validation,
      );
      expect(
        errorType(await LocalDB.GetById(key)),
        LocalDbErrorType.validation,
      );
      expect(
        errorType(await LocalDB.Put(key, {'n': 2})),
        LocalDbErrorType.validation,
      );
      expect(errorType(await LocalDB.Delete(key)), LocalDbErrorType.validation);
      expect(value(await LocalDB.GetAll()), isEmpty, reason: 'nothing written');
    });

    test('exported by 1.6 are imported', () async {
      value(await LocalDB.init(path: at('app')));
      final export = LocalDbExport.encode([
        LocalDbModel(id: 'a', data: {'n': 1}),
        LocalDbModel(
          id: 'b',
          data: {
            'nested': {'x': true},
          },
        ),
      ]);

      expect(value(await LocalDB.importAll(export)), 2);
      expect(value(await LocalDB.GetById('b'))?.data, {
        'nested': {'x': true},
      });
    });
  });

  group('tables', () {
    test('define themselves on the database of init, with no list', () async {
      value(await LocalDB.init(path: at('app')));

      expect(value(await users.insert(User.all)), User.all.length);
      final plan = value(
        await users.filter(users.field<String>('city').eq('Lima')).explain(),
      );
      expect(plan.index, 'by_city_age', reason: 'its index was built');

      await LocalDB.close();
      value(await LocalDB.init(path: at('app')));

      expect(value(await users.all().count()), User.all.length);
      expect(value(await LocalDB.info()).tables, 1);
    });

    test(
      'a first use inside a transaction is refused, not a deadlock',
      () async {
        value(await LocalDB.init(path: at('app')));

        final result = await LocalDB.transaction<int>(
          (tx) => users.insert(User.all),
        ).timeout(const Duration(seconds: 5));

        expect(code(result), DbErrorCode.tableNotReady);
        expect(
          value(await users.all().count()),
          0,
          reason: 'usable afterwards',
        );
      },
    );

    test('share the file with the records, and survive a reopen', () async {
      value(await LocalDB.init(path: at('app'), tables: [users]));

      value(await LocalDB.Post('settings', {'theme': 'dark'}));
      expect(value(await users.insert(User.all)), User.all.length);

      await LocalDB.close();
      value(await LocalDB.init(path: at('app'), tables: [users]));

      expect(value(await LocalDB.GetById('settings'))?.data, {'theme': 'dark'});
      expect(
        value(
          await users
              .filter(
                users
                    .field<String>('city')
                    .eq('Lima')
                    .and(users.field<int>('age').gt(30)),
              )
              .order(users.field<int>('age').desc()),
        ).map((user) => user.name),
        ['Grace', 'Ada'],
      );
      final info = value(await LocalDB.info());
      expect(info.storage, '1.0.2');
      expect(info.tables, 1);
    });

    test('run with the options given to init', () async {
      value(
        await LocalDB.init(
          path: at('app'),
          tables: [users],
          options: const DbOptions(initialSize: 8 << 20),
        ),
      );

      expect(value(await LocalDB.info()).mapSize, 8 << 20);
    });

    test('can be added by a later init', () async {
      value(await LocalDB.init(path: at('app')));
      value(await LocalDB.init(tables: [users]));

      expect(value(await users.insert(User.all)), User.all.length);
      expect(value(await users.all().count()), User.all.length);
    });

    test('follow the transaction their queries are awaited in', () async {
      value(await LocalDB.init(path: at('app'), tables: [users]));

      final undone = await LocalDB.transaction<void>((tx) async {
        value(await users.insert(User.all));
        return Err(DbError(DbErrorCode.invalidRequest, 'undo it'));
      });
      expect(code(undone), DbErrorCode.invalidRequest);
      expect(value(await users.all().count()), 0);

      value(await LocalDB.transaction<int>((tx) => users.insert(User.all)));
      expect(value(await users.all().count()), User.all.length);
    });

    test('use the declared index', () async {
      value(await LocalDB.init(path: at('app'), tables: [users]));

      final plan = value(
        await users
            .filter(
              users
                  .field<String>('city')
                  .eq('Lima')
                  .and(users.field<int>('age').gt(30)),
            )
            .order(users.field<int>('age').desc())
            .explain(),
      );

      expect(plan.access, PlanAccess.indexScan);
      expect(plan.index, 'by_city_age');
      expect(plan.exact, isTrue);
    });

    test('of another database run there only when it is named', () async {
      value(await LocalDB.init(path: at('app'), tables: [users]));
      final archive = value(await LocalDB.open(at('archive'), tables: [users]));

      value(await users.insert([User.all.first]).execute(archive));

      expect(value(await users.all()), isEmpty);
      expect(value(await users.all().load(archive)).map((user) => user.name), [
        User.all.first.name,
      ]);
      await archive.close();
    });

    test('answer notOpen before init', () async {
      expect(code(await users.all()), DbErrorCode.notOpen);
      expect(
        code(await LocalDB.transaction<void>((tx) async => Ok(null))),
        DbErrorCode.notOpen,
      );
    });
  });

  test('a 1.x database is reported and left untouched', () async {
    final source = Directory('test/fixtures/lmdb_0_9/compat.lmdb');
    final target = Directory(at('old.lmdb'))..createSync();
    for (final file in ['data.mdb', 'lock.mdb']) {
      File('${source.path}/$file').copySync('${target.path}/$file');
    }
    final before = File('${target.path}/data.mdb').readAsBytesSync();

    final opened = await LocalDB.init(path: at('old'), tables: [users]);

    expect(code(opened), DbErrorCode.legacyFormat);
    expect(
      opened.when(ok: (_) => null, err: (error) => error),
      isA<StorageError>(),
    );
    expect(LocalDB.isInitialized, isFalse);
    expect(File('${target.path}/data.mdb').readAsBytesSync(), before);

    value(await LocalDB.moveLegacyDatabaseAside(path: at('old')));
    value(await LocalDB.init(path: at('old'), tables: [users]));
    expect(value(await users.all().count()), 0);
  });
}

/// The value of an `Ok`; fails the test on an `Err`.
T value<T, E>(Result<T, E> result) =>
    result.when(ok: (data) => data, err: (error) => fail('Err: $error'));

/// The code of an `Err`; fails the test on an `Ok`.
DbErrorCode code<T>(Result<T, DbError> result) =>
    result.when(ok: (data) => fail('Ok: $data'), err: (error) => error.code);

/// The type of a key-value `Err`; fails the test on an `Ok`.
LocalDbErrorType errorType<T>(Result<T, ErrorLocalDb> result) =>
    result.when(ok: (data) => fail('Ok: $data'), err: (error) => error.type);

/// A user, as an app models it.
final class User {
  const User({
    required this.id,
    required this.name,
    required this.city,
    required this.age,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    city: json['city'] as String,
    age: json['age'] as int,
  );

  static const List<User> all = [
    User(id: 1, name: 'Ada', city: 'Lima', age: 36),
    User(id: 2, name: 'Grace', city: 'Lima', age: 45),
    User(id: 3, name: 'Linus', city: 'Lima', age: 28),
    User(id: 4, name: 'Barbara', city: 'Bogotá', age: 50),
  ];

  final int id;
  final String name;
  final String city;
  final int age;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'age': age,
  };
}
