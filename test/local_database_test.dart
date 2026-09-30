import 'dart:async';
import 'dart:io';

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native.dart';
import 'support/skills.dart';

void main() {
  late Directory directory;
  late LocalDatabase db;
  final skills = SkillsTable();

  setUp(() async {
    directory = await TestHost.temporaryDirectory('api');
    db = await LocalDatabase.open(
      path: '${directory.path}/app',
      tables: [skills],
    );
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> seed(int count) => skills
      .insert([
        for (var i = 0; i < count; i++)
          Skills.make(
            i,
            ['rust', 'dart', 'go'][i % 3],
            i % 7,
            enabled: i.isEven,
          ),
      ])
      .execute(db);

  LocalDbErrorCode? codeOf(Object? error) =>
      error is LocalDbException ? error.code : null;

  group('queries', () {
    test('insert, find and load with filter, order and limit', () async {
      await seed(30);

      expect(
        await skills.find('s004').first(db),
        Skills.make(4, 'dart', 4, enabled: true),
      );
      expect(await skills.find('nope').first(db), isNull);

      final top = await skills
          .filter(skills.language.eq('rust') & skills.enabled.eq(true))
          .order(skills.priority.desc())
          .thenOrderBy(skills.id.asc())
          .limit(3)
          .load(db);
      // Enabled rust rows: s000 (0), s006 (6), s012 (5), s018 (4), s024 (3).
      expect(top.map((s) => s.id), ['s006', 's012', 's018']);
      expect(top.every((s) => s.language == 'rust' && s.enabled), isTrue);
    });

    test('Diesel operators and aggregates', () async {
      await seed(21);
      Future<int> count(Expression e) => skills.filter(e).count(db);

      expect(await count(skills.priority.gt(5)), 3);
      expect(await count(skills.priority.between(2, 3)), 6);
      expect(await count(skills.language.eqAny(['go', 'dart'])), 14);
      expect(await count(skills.language.neAll(['go', 'dart'])), 7);
      expect(await count(skills.slug.like('slug-1%')), 11);
      expect(await count(skills.slug.ilike('SLUG-2_')), 1);
      expect(await count(~skills.enabled.eq(true)), 10);
      expect(await count(skills.priority.lt(1) | skills.priority.ge(6)), 6);
      expect(await skills.all().sum(skills.priority, db), 63);
      expect(await skills.all().max(skills.priority, db), 6);
      expect(await skills.all().avg(skills.priority, db), 3.0);
    });

    test('the planner uses the declared indexes', () async {
      await seed(10);
      final plan = await skills
          .filter(skills.language.eq('go') & skills.priority.ge(2))
          .order(skills.priority.desc())
          .explain(db);
      expect(plan['index'], 'by_language_priority');
      expect(plan['presorted'], isTrue);
      expect(plan['exact'], isTrue, reason: 'the index answers the filter');
      final residual = await skills
          .filter(skills.language.eq('go') & skills.enabled.eq(true))
          .explain(db);
      expect(residual['exact'], isFalse, reason: '`enabled` is not indexed');
    });
  });

  group('writes', () {
    test('update, delete and affected-row expectations', () async {
      await seed(9);
      final updated = await skills
          .update()
          .filter(skills.language.eq('rust'))
          .set(skills.priority, 100)
          .execute(db);
      expect(updated, 3);
      expect(await skills.filter(skills.priority.eq(100)).count(db), 3);

      await expectLater(
        skills
            .delete()
            .filter(skills.language.eq('go'))
            .expectAffectedRows(1)
            .execute(db),
        throwsA(
          predicate((e) => codeOf(e) == LocalDbErrorCode.affectedRowsMismatch),
        ),
      );
      expect(await skills.filter(skills.language.eq('go')).count(db), 3);
      expect(
        await skills.delete().filter(skills.language.eq('go')).execute(db),
        3,
      );
    });

    test('constraints fail with typed codes', () async {
      await seed(1);
      await expectLater(
        skills.insert([Skills.make(0, 'zig', 1)]).execute(db),
        throwsA(predicate((e) => codeOf(e) == LocalDbErrorCode.duplicateKey)),
      );
      const sameSlug = Skill(
        id: 'other',
        slug: 'slug-0',
        language: 'go',
        priority: 1,
      );
      await expectLater(
        skills.insert([sameSlug]).execute(db),
        throwsA(
          predicate((e) => codeOf(e) == LocalDbErrorCode.uniqueViolation),
        ),
      );
      expect(
        await skills
            .insert([Skills.make(0, 'zig', 9)])
            .onConflictDoNothing()
            .execute(db),
        0,
      );
      await skills
          .insert([Skills.make(0, 'zig', 9)])
          .onConflictReplace()
          .execute(db);
      expect((await skills.find('s000').first(db))!.language, 'zig');
    });
  });

  group('transactions', () {
    test('commit on success, roll back on error', () async {
      final value = await db.transaction((tx) async {
        await skills.insert([Skills.make(1, 'rust', 1)]).execute(tx);
        expect(await skills.all().count(tx), 1, reason: 'read-your-writes');
        return 'done';
      });
      expect(value, 'done');

      await expectLater(
        db.transaction((tx) async {
          await skills.insert([Skills.make(2, 'go', 1)]).execute(tx);
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect(await skills.all().count(db), 1);
    });

    test('a caught failed write makes the transaction rollback-only', () async {
      await seed(1);
      await expectLater(
        db.transaction((tx) async {
          await skills.insert([Skills.make(5, 'go', 1)]).execute(tx);
          try {
            await skills.insert([Skills.make(0, 'dup', 1)]).execute(tx);
          } on LocalDbException {
            // Ignored on purpose: the commit must still fail.
          }
        }),
        throwsA(
          predicate((e) => codeOf(e) == LocalDbErrorCode.transactionAborted),
        ),
      );
      expect(await skills.all().count(db), 1);
    });

    test('savepoints roll back only their own writes', () async {
      await db.transaction((tx) async {
        await skills.insert([Skills.make(1, 'rust', 1)]).execute(tx);
        await expectLater(
          tx.savepoint((sp) async {
            await skills.insert([Skills.make(2, 'go', 1)]).execute(sp);
            await skills.insert([Skills.make(1, 'dup', 1)]).execute(sp);
          }),
          throwsA(predicate((e) => codeOf(e) == LocalDbErrorCode.duplicateKey)),
        );
        await tx.savepoint(
          (sp) => skills.insert([Skills.make(3, 'zig', 1)]).execute(sp),
        );
      });
      final ids = (await skills.all().order(skills.id.asc()).load(db)).map(
        (s) => s.id,
      );
      expect(ids, ['s001', 's003']);
    });

    test('using the database inside its own transaction is rejected', () async {
      await expectLater(
        db.transaction((tx) => skills.all().count(db)),
        throwsA(
          predicate((e) => codeOf(e) == LocalDbErrorCode.transactionReentrancy),
        ),
      );
    });

    test('outside writes wait for the running transaction', () async {
      final events = <String>[];
      final release = Completer<void>();
      final transaction = db.transaction((tx) async {
        await skills.insert([Skills.make(1, 'rust', 1)]).execute(tx);
        events.add('tx wrote');
        await release.future;
        events.add('tx ends');
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final outside = skills.insert([Skills.make(2, 'go', 1)]).execute(db).then(
        (_) {
          events.add('outside wrote');
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      release.complete();
      await Future.wait([transaction, outside]);
      expect(events, ['tx wrote', 'tx ends', 'outside wrote']);
      expect(await skills.all().count(db), 2);
    });

    test('atomic batches commit all statements or none', () async {
      await expectLater(
        db.atomicBatch([
          skills.insert([Skills.make(1, 'rust', 1)]),
          skills.update().filter(skills.id.eq('s001')).set(skills.priority, 9),
          skills.insert([Skills.make(1, 'dup', 1)]),
        ]),
        throwsA(predicate((e) => codeOf(e) == LocalDbErrorCode.duplicateKey)),
      );
      expect(await skills.all().count(db), 0);
      final affected = await db.atomicBatch([
        skills.insert([Skills.make(1, 'rust', 1)]),
        skills.update().filter(skills.id.eq('s001')).set(skills.priority, 9),
      ]);
      expect(affected, [1, 1]);
      expect((await skills.find('s001').first(db))!.priority, 9);
    });

    test('a read transaction is a consistent snapshot', () async {
      await seed(2);
      await db.readTransaction((snapshot) async {
        await skills.insert([Skills.make(10, 'go', 1)]).execute(db);
        expect(await skills.all().count(snapshot), 2);
      });
      expect(await skills.all().count(db), 3);
    });
  });

  test('watch emits the rows again after each committed write', () async {
    final updates = <List<String>>[];
    final subscription = skills
        .filter(skills.language.eq('rust'))
        .order(skills.id.asc())
        .watch(db)
        .listen((rows) => updates.add([for (final s in rows) s.id]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await skills.insert([Skills.make(1, 'rust', 1)]).execute(db);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await db.transaction(
      (tx) => skills.insert([Skills.make(2, 'rust', 1)]).execute(tx),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await subscription.cancel();
    expect(updates, [
      <String>[],
      ['s001'],
      ['s001', 's002'],
    ]);
  });

  test('data persists across reopen and info reports LMDB 1.0.2', () async {
    await seed(3);
    await db.close();
    db = await LocalDatabase.open(
      path: '${directory.path}/app',
      tables: [skills],
    );
    expect(await skills.all().count(db), 3);
    final info = await db.info();
    expect(info['lmdb'], '1.0.2');
  });
}
